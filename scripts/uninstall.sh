#!/usr/bin/env bash
set -euo pipefail

echo "==> Uninstalling Omarchy Clipboard..."

# Stop daemon
omarchy-clipboard kill >/dev/null 2>&1 || true

# Remove binaries, release directory, and desktop entries
rm -f "$HOME/.local/bin/omarchy-clipboard"
rm -f "$HOME/.local/share/applications/omarchy-clipboard.desktop"
rm -f "$HOME/.config/autostart/omarchy-clipboard.desktop"
rm -rf "$HOME/.local/share/cosmic-omarchy-clipboard"

echo "==> Removed binary, release files, desktop launcher, and autostart entries."
echo "Note: Your clipboard history in ~/.local/state/omarchy/ and config in ~/.config/omarchy-clipboard/ were preserved."
