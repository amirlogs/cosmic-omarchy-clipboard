#!/usr/bin/env bash
set -e

echo "==> Uninstalling Omarchy Clipboard..."

# Stop daemon
omarchy-clipboard kill >/dev/null 2>&1 || true

# Remove binaries and symlinks
rm -f "$HOME/.local/bin/omarchy-clipboard"
rm -f "$HOME/.local/share/applications/omarchy-clipboard.desktop"
rm -f "$HOME/.config/autostart/omarchy-clipboard.desktop"

echo "==> Removed binary, desktop launcher, and autostart entries."
echo "Note: Your clipboard history in ~/.local/state/omarchy/ was preserved."
