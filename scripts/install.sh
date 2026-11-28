#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="amirlogs/cosmic-omarchy-clipboard"
RELEASE_INSTALL_DIR="$HOME/.local/share/cosmic-omarchy-clipboard"
FROM_RELEASE=false
WITH_SHORTCUT=false
NO_START=false
VERSION="latest"

while (( $# > 0 )); do
  case "$1" in
    --from-release) FROM_RELEASE=true; shift ;;
    --with-shortcut) WITH_SHORTCUT=true; shift ;;
    --no-start) NO_START=true; shift ;;
    --version) VERSION="${2:-latest}"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Usage: install.sh [OPTIONS]

Options:
  --from-release    Download and install the latest GitHub release archive
  --version <tag>   Install a specific release tag (default: latest)
  --with-shortcut   Optionally configure Super + V in COSMIC custom shortcuts
  --no-start        Do not start/restart the background daemon after install
  -h, --help        Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

echo "==> Installing Omarchy Clipboard for COSMIC Desktop..."

# Detect whether we are running from an existing local checkout
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
LOCAL_REPO_DIR=""
if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
  CANDIDATE_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")/.." && pwd)"
  if [[ -f "$CANDIDATE_DIR/main.qml" && -x "$CANDIDATE_DIR/bin/omarchy-clipboard" ]]; then
    LOCAL_REPO_DIR="$CANDIDATE_DIR"
  fi
fi

if [[ "$FROM_RELEASE" == "true" || -z "$LOCAL_REPO_DIR" ]]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required to download the release archive." >&2
    exit 1
  fi
  if ! command -v tar >/dev/null 2>&1; then
    echo "Error: tar is required to extract the release archive." >&2
    exit 1
  fi

  if [[ "$VERSION" == "latest" ]]; then
    TARBALL_URL="https://github.com/$REPO_SLUG/releases/latest/download/cosmic-omarchy-clipboard.tar.gz"
  else
    TARBALL_URL="https://github.com/$REPO_SLUG/releases/download/$VERSION/cosmic-omarchy-clipboard.tar.gz"
  fi

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  echo "==> Downloading release ($VERSION) from GitHub..."
  curl -fsSL "$TARBALL_URL" -o "$TMP_DIR/release.tar.gz"

  rm -rf "$RELEASE_INSTALL_DIR"
  mkdir -p "$RELEASE_INSTALL_DIR"
  tar -xzf "$TMP_DIR/release.tar.gz" -C "$RELEASE_INSTALL_DIR"

  # Support archives with a single top-level directory or flat layout
  if [[ ! -f "$RELEASE_INSTALL_DIR/main.qml" ]]; then
    SUBDIR="$(find "$RELEASE_INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [[ -n "$SUBDIR" && -f "$SUBDIR/main.qml" ]]; then
      cp -a "$SUBDIR"/. "$RELEASE_INSTALL_DIR"/
      rm -rf "$SUBDIR"
    fi
  fi

  INSTALL_DIR="$RELEASE_INSTALL_DIR"
else
  INSTALL_DIR="$LOCAL_REPO_DIR"
fi

# 1. Install / Link launcher binary
mkdir -p "$HOME/.local/bin"
chmod +x "$INSTALL_DIR/bin/omarchy-clipboard" "$INSTALL_DIR/bin/omarchy-clipboard-"* "$INSTALL_DIR/capture.sh"
ln -sf "$INSTALL_DIR/bin/omarchy-clipboard" "$HOME/.local/bin/omarchy-clipboard"

# 2. Install desktop application launcher
mkdir -p "$HOME/.local/share/applications"
cp "$INSTALL_DIR/assets/omarchy-clipboard.desktop" "$HOME/.local/share/applications/omarchy-clipboard.desktop"

# 3. Install autostart entry
mkdir -p "$HOME/.config/autostart"
cp "$INSTALL_DIR/assets/omarchy-clipboard-autostart.desktop" "$HOME/.config/autostart/omarchy-clipboard.desktop"

# 4. Optional COSMIC global shortcut (never forced)
configure_cosmic_shortcut() {
  local cosmic_dir="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
  local cosmic_file="$cosmic_dir/custom"
  [[ -d "$cosmic_dir" && -f "$cosmic_file" ]] || return 0

  echo "==> Configuring optional COSMIC shortcut (Super + V)..."
  cp "$cosmic_file" "$cosmic_file.bak"
  if grep -q 'key: "v"' "$cosmic_file" && grep -q 'Super' "$cosmic_file"; then
    sed -i 's|Spawn(".*clippy.*")|Spawn("'"$HOME"'/.local/bin/omarchy-clipboard toggle")|g' "$cosmic_file"
    sed -i 's|Spawn(".*clipboard.*")|Spawn("'"$HOME"'/.local/bin/omarchy-clipboard toggle")|g' "$cosmic_file"
  else
    python3 - "$cosmic_file" "$HOME/.local/bin/omarchy-clipboard toggle" <<'PY'
import sys
path, cmd = sys.argv[1:3]
with open(path, "r") as f:
    content = f.read().rstrip()
if content.endswith("}"):
    entry = f'''    (
        modifiers: [
            Super,
        ],
        key: "v",
        description: Some("COSMIC Clipboard"),
    ): Spawn("{cmd}"),
}}'''
    content = content[:-1].rstrip() + "\n" + entry
    with open(path, "w") as f:
        f.write(content + "\n")
PY
  fi
}

if [[ "$WITH_SHORTCUT" == "true" ]]; then
  configure_cosmic_shortcut
elif [[ -t 0 && -d "$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1" ]]; then
  read -r -p "==> Configure optional Super + V shortcut in COSMIC now? [y/N] " reply || true
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    configure_cosmic_shortcut
  else
    echo "==> Skipping global shortcut configuration. You can set any shortcut in Clipboard Settings -> Keyboard & Shortcuts or COSMIC Settings."
  fi
else
  echo "==> Skipping global shortcut configuration (pass --with-shortcut to set Super + V, or configure it in Settings)."
fi

# 5. Start / Restart background daemon (without opening the overlay)
if [[ "$NO_START" != "true" ]]; then
  echo "==> Starting Omarchy Clipboard daemon..."
  "$INSTALL_DIR/bin/omarchy-clipboard" kill >/dev/null 2>&1 || true
  setsid "$INSTALL_DIR/bin/omarchy-clipboard" --daemon >/dev/null 2>&1 </dev/null &
  for _ in {1..20}; do
    "$INSTALL_DIR/bin/omarchy-clipboard" status >/dev/null 2>&1 && break
    sleep 0.1
  done
fi

echo "==> Installation complete!"
if ! command -v tesseract >/dev/null 2>&1 || ! command -v grim >/dev/null 2>&1; then
  echo "Tip: For Screen OCR support, install tesseract (+ language pack), grim, and slurp:"
  echo "     Fedora: sudo dnf install -y tesseract tesseract-langpack-eng grim slurp"
fi
echo "Run 'omarchy-clipboard toggle' (or bind it to your preferred shortcut) to open."
