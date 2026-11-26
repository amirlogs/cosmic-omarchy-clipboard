#!/bin/bash

# Captures the current clipboard as a JSON entry on stdout. In watch mode,
# wl-paste invokes this with the payload on stdin and the mime as $1. Without
# arguments, it snapshots the current selection itself.
#
# Entries now carry a content hash, an ISO timestamp, and a source. A write
# marker lets the app (editor, OCR, explicit copy) tell the watcher that the
# next clipboard event is its own, so it is not recorded twice:
#
#   suppress -> drop the event
#   tag      -> record it once with the marker's source

set -o pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/vendor/perl5/usr/share/perl5/vendor_perl" ]]; then
  export PERL5LIB="$SCRIPT_DIR/vendor/perl5/usr/share/perl5/vendor_perl:${PERL5LIB:-}"
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
IMAGE_DIR="$STATE_DIR/clipboard-images"
mkdir -p "$IMAGE_DIR"
chmod 700 "$STATE_DIR" "$IMAGE_DIR" 2>/dev/null || true

MARKER_FILE="$STATE_DIR/clipboard-self-write.json"

types=$(timeout 2s wl-paste --list-types 2>/dev/null || true)

if [[ ${CLIPBOARD_STATE:-} == "sensitive" ]] || grep -qx 'x-kde-passwordManagerHint' <<<"$types"; then
  exit 0
fi

tmp=
trap 'rm -f -- "$tmp"' EXIT

# The clipboard owner streams the copy and can stall without closing its end, so
# every read is bounded, and a copy cut off at the deadline is dropped, not kept.
read_copy() {
  timeout 2s "$@" >"$tmp" 2>/dev/null && [[ -s $tmp ]]
}

# Answers "suppress", "tag:<source>" or "" for a captured content hash. The
# marker is single use and expires so a failed clipboard write cannot silence
# the watcher indefinitely.
self_write_action() {
  local hash="$1" mode source expires now mhash
  [[ -r $MARKER_FILE ]] || return 0

  mode=$(jq -r '.mode // empty' "$MARKER_FILE" 2>/dev/null)
  source=$(jq -r '.source // "clipboard"' "$MARKER_FILE" 2>/dev/null)
  expires=$(jq -r '.expiresAt // 0' "$MARKER_FILE" 2>/dev/null)
  mhash=$(jq -r '.hash // empty' "$MARKER_FILE" 2>/dev/null)

  now=$(date +%s)
  if [[ ! $expires =~ ^[0-9]+$ ]] || (( now > expires )); then
    rm -f "$MARKER_FILE"
    return 0
  fi
  [[ $mhash == "$hash" ]] || return 0

  if [[ $mode == "suppress" ]]; then
    echo "suppress"
  elif [[ $mode == "tag" ]]; then
    rm -f "$MARKER_FILE"
    echo "tag:${source:-clipboard}"
  else
    rm -f "$MARKER_FILE"
  fi
}

emit_image() {
  local mime="$1"
  local ext hash file bytes created source action
  shift

  ext=${mime#image/}
  [[ $ext == jpeg ]] && ext=jpg

  tmp=$(mktemp --tmpdir="$IMAGE_DIR" clipboard.XXXXXX) || return 0
  read_copy "$@" || return

  hash=$(sha256sum "$tmp" | awk '{print $1}')
  action=$(self_write_action "$hash")
  [[ $action == "suppress" ]] && return 0
  source="clipboard"
  [[ $action == tag:* ]] && source=${action#tag:}

  file="$IMAGE_DIR/$hash.$ext"
  if [[ -e $file ]]; then
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi
  bytes=$(stat -c %s "$file" 2>/dev/null || echo 0)
  created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

  jq -cn \
    --arg mime "$mime" \
    --arg path "$file" \
    --arg hash "$hash" \
    --arg source "$source" \
    --arg created "$created" \
    --arg captured_at "$(LC_TIME="$(omarchy-language locale 2>/dev/null)" date +'%A %H:%M')" \
    --argjson bytes "$bytes" \
    '{type:"image", mime:$mime, path:$path, hash:$hash, bytes:$bytes, source:$source, createdAt:$created, capturedAt:$captured_at}'
}

emit_text() {
  local hash created source action
  tmp=$(mktemp --tmpdir="$STATE_DIR" clipboard.XXXXXX) || return 0
  read_copy "$@" || return

  hash=$(sha256sum "$tmp" | awk '{print $1}')
  action=$(self_write_action "$hash")
  [[ $action == "suppress" ]] && return 0
  source="clipboard"
  [[ $action == tag:* ]] && source=${action#tag:}
  created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

  CAPTURE_HASH="$hash" CAPTURE_SOURCE="$source" CAPTURE_CREATED="$created" \
  perl -MEncode=decode,FB_CROAK,LEAVE_SRC -MJSON::PP=encode_json -0777 -e '
    my $raw = <STDIN>;
    exit unless length $raw;

    my $encoding;
    my $heuristic_encoding = 0;
    if ($raw =~ /^(?:\xFF\xFE|\xFE\xFF)/) {
      $encoding = "UTF-16";
    } elsif (length($raw) % 2 == 0 && index($raw, "\0") >= 0) {
      my $units = length($raw) / 2;
      my $nuls = $raw =~ tr/\0/\0/;

      # Neither byte lane can reach the padding threshold when the entire
      # payload contains fewer NULs than that, so avoid two full string passes.
      if ($nuls * 4 >= $units * 3) {
        my $even_bytes = $raw;
        $even_bytes =~ s/(.)./$1/sg;
        my $even_nuls = $even_bytes =~ tr/\0/\0/;
        undef $even_bytes;

        my $odd_bytes = $raw;
        $odd_bytes =~ s/.(.)/$1/sg;
        my $odd_nuls = $odd_bytes =~ tr/\0/\0/;

        # BOM-less UTF-16 is indistinguishable from NUL-separated bytes. Decode
        # only when at least three quarters of the code units have consistent
        # padding and fewer than one quarter have NULs in the opposite byte.
        if ($odd_nuls * 4 >= $units * 3 && $even_nuls * 4 < $units) {
          $encoding = "UTF-16LE";
          $heuristic_encoding = 1;
        } elsif ($even_nuls * 4 >= $units * 3 && $odd_nuls * 4 < $units) {
          $encoding = "UTF-16BE";
          $heuristic_encoding = 1;
        }
      }
    }

    my $text = $encoding ? eval { decode($encoding, $raw, FB_CROAK | LEAVE_SRC) } : undef;
    if ($heuristic_encoding && defined($text) && $text =~ /[\x00-\x08\x0E-\x1A\x1C-\x1F]/) {
      $text = undef;
    }
    $text = decode("UTF-8", $raw) unless defined $text;

    my %entry = (
      type      => "text",
      text      => $text,
      hash      => ($ENV{CAPTURE_HASH} // ""),
      source    => ($ENV{CAPTURE_SOURCE} // "clipboard"),
      createdAt => ($ENV{CAPTURE_CREATED} // ""),
    );
    print encode_json(\%entry), "\n";
  ' <"$tmp"
}

case "${1:-}" in
text) emit_text cat; exit 0 ;;
image/*) emit_image "$1" cat; exit 0 ;;
esac

for mime in image/png image/jpeg image/webp image/gif image/bmp image/tiff; do
  if grep -qx "$mime" <<<"$types"; then
    emit_image "$mime" wl-paste --type "$mime"
    exit 0
  fi
done

if grep -q '^text/' <<<"$types" || grep -qx 'UTF8_STRING' <<<"$types" || grep -qx 'STRING' <<<"$types"; then
  emit_text wl-paste --type text --no-newline
fi
