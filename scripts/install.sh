#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Installing Omarchy Clipboard for COSMIC Desktop..."

# 1. Install / Link launcher binary
mkdir -p "$HOME/.local/bin"
ln -sf "$REPO_DIR/bin/omarchy-clipboard" "$HOME/.local/bin/omarchy-clipboard"
chmod +x "$REPO_DIR/bin/omarchy-clipboard" "$REPO_DIR/bin/omarchy-clipboard-"* "$REPO_DIR/capture.sh"

# 2. Install desktop application launcher
mkdir -p "$HOME/.local/share/applications"
cp "$REPO_DIR/assets/omarchy-clipboard.desktop" "$HOME/.local/share/applications/omarchy-clipboard.desktop"

# 3. Install autostart entry
mkdir -p "$HOME/.config/autostart"
cp "$REPO_DIR/assets/omarchy-clipboard-autostart.desktop" "$HOME/.config/autostart/omarchy-clipboard.desktop"

# 4. Configure COSMIC global shortcut (Super + V)
COSMIC_SHORTCUTS_DIR="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
COSMIC_SHORTCUTS_FILE="$COSMIC_SHORTCUTS_DIR/custom"

if [[ -d "$COSMIC_SHORTCUTS_DIR" ]]; then
  echo "==> Configuring COSMIC shortcut (Super + V)..."
  if [[ -f "$COSMIC_SHORTCUTS_FILE" ]]; then
    cp "$COSMIC_SHORTCUTS_FILE" "$COSMIC_SHORTCUTS_FILE.bak"
    # If a Super+V shortcut already exists, update it; otherwise append before trailing bracket
    if grep -q 'key: "v"' "$COSMIC_SHORTCUTS_FILE" && grep -q 'Super' "$COSMIC_SHORTCUTS_FILE"; then
      sed -i 's|Spawn(".*clippy.*")|Spawn("'"$HOME"'/.local/bin/omarchy-clipboard toggle")|g' "$COSMIC_SHORTCUTS_FILE"
      sed -i 's|Spawn(".*clipboard.*")|Spawn("'"$HOME"'/.local/bin/omarchy-clipboard toggle")|g' "$COSMIC_SHORTCUTS_FILE"
    else
      # Insert shortcut entry before the closing brace
      python3 -c '
import sys
path = sys.argv[1]
with open(path, "r") as f:
    content = f.read().rstrip()
if content.endswith("}"):
    entry = """    (
        modifiers: [
            Super,
        ],
        key: "v",
        description: Some("Omarchy Clipboard"),
    ): Spawn("'"$HOME"'/.local/bin/omarchy-clipboard toggle"),
}"""
    content = content[:-1].rstrip() + "\n" + entry
    with open(path, "w") as f:
        f.write(content + "\n")
' "$COSMIC_SHORTCUTS_FILE"
    fi
  fi
fi

# 5. Start / Restart background daemon
echo "==> Starting Omarchy Clipboard daemon..."
"$REPO_DIR/bin/omarchy-clipboard" kill >/dev/null 2>&1 || true
"$REPO_DIR/bin/omarchy-clipboard" status >/dev/null 2>&1 || true

echo "==> Installation complete!"
echo "Press Super + V or run 'omarchy-clipboard toggle' to open."
