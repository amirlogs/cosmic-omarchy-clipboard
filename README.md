# Omarchy Clipboard for COSMIC Desktop

A native Wayland clipboard manager for **Fedora 44** running **COSMIC Desktop**, ported directly from the upstream [Omarchy Quattro](https://github.com/omacom/omarchy/tree/quattro/shell/plugins/clipboard) shell.

This project delivers the exact visual design, semi-transparent frosted card, fluid two-pane layout, real-time search, image previews, and keyboard navigation from Omarchy, running standalone on COSMIC Wayland compositors (`cosmic-comp`) without Hyprland or Omarchy shell dependencies.

---

## Screenshots

<!-- Visual preview placeholder -->
```
┌────────────────────────────────────────────────────────────────────────┐
│  Search...                                                             │
├──────────────────────────────────┬─────────────────────────────────────┤
│  󰅌 Testing COSMIC clipboard...   │  Testing COSMIC clipboard port      │
│  󰅌 COSMIC Desktop Tiling Tuto... │  at 1728x1152 display resolution   │
│   Screenshot from Saturday      │  with 2x scaling...                 │
│  󰅌 git commit -m "..."           │                                     │
│  󰅌 https://github.com/...        │                                     │
│                                  │                                     │
└──────────────────────────────────┴─────────────────────────────────────┘
```

> *Tip: Place high-resolution screenshots in `assets/screenshots/` and update this section.*

---

## Why This Project Exists

The [Omarchy Quattro](https://github.com/omacom/omarchy) clipboard is widely recognized for its minimalist aesthetics, responsive keyboard interaction, and seamless image & file previews. However, the upstream implementation was strictly bundled inside `omarchy-shell` and tightly coupled with Hyprland compositor IPC APIs.

**Omarchy Clipboard for COSMIC** bridges this gap:
- **Zero Redesign**: Preserves the original QML components, typography, layout, animations, and color tokens.
- **Pure Wayland Standard**: Replaces compositor-specific hooks with standard `zwlr_layer_shell_v1` and `zwp_virtual_keyboard_manager_v1` protocols.
- **COSMIC Integration**: Features global shortcut support (`Super + V`), desktop application registration, and background autostart.

---

## Key Features

- **Split Two-Pane Overlay**: Left pane displays chronological history with icons; right pane provides instant full-text or full-image previews.
- **Text & Image Capture**: Automatic background capture of text, URLs, file paths, and PNG screenshots via `wl-paste --watch`.
- **Deduplication & Image Hashing**: Content-addressed SHA-256 storage for copied images in `~/.local/state/omarchy/clipboard-images/`.
- **Keyboard-First Workflow**:
  - `↑` / `↓` or `PageUp` / `PageDown`: Navigate entries.
  - `Enter`: Copy and paste into the active window.
  - `Shift + Enter`: Copy to clipboard without pasting.
  - `Alt + Enter`: Open URLs in browser, files in editor, or images in default viewer.
  - `Delete`: Remove selected item from history.
  - `Shift + Delete`: Clear all clipboard history (with confirmation dialog).
  - `Escape`: Clear search filter, or dismiss the overlay.
  - Immediate typing filters history in real-time.
- **Zero-Latency Summoning**: Daemon stays loaded in memory and responds to IPC toggles instantly.
- **HiDPI Scaling Aware**: Dynamically adapts to fractional and integer display scaling (e.g. 1728 × 1152 at 2x scaling).

---

## Requirements

- **Operating System**: Fedora 44 (or compatible modern Linux distribution)
- **Desktop Environment**: COSMIC Desktop (`cosmic-comp`) or any wlroots-compatible Wayland compositor
- **Display Protocol**: Wayland

### Dependencies

| Package | Purpose |
|---|---|
| `quickshell` | QtQuick-based Wayland desktop shell runtime |
| `wl-clipboard` | Native Wayland clipboard utilities (`wl-paste`, `wl-copy`) |
| `wtype` | Wayland virtual keyboard simulation for paste automation |
| `jq` | JSON parsing and serialization |
| `perl` & `perl-JSON-PP` | UTF-8/UTF-16 encoding detection and sanitization |

---

## Installation

### 1. Install System Dependencies

On Fedora 44, install the required packages:

```bash
sudo dnf install -y quickshell wl-clipboard wtype jq perl-JSON-PP
```

### 2. Clone and Install

```bash
git clone https://github.com/amirlogs/cosmic-omarchy-clipboard.git
cd cosmic-omarchy-clipboard
./scripts/install.sh
```

The installer will:
1. Symlink `bin/omarchy-clipboard` to `~/.local/bin/omarchy-clipboard`.
2. Register the application menu launcher in `~/.local/share/applications/`.
3. Enable autostart on login in `~/.config/autostart/`.
4. Configure the `Super + V` shortcut in COSMIC settings.
5. Launch the background watcher service.

---

## Keyboard Shortcut Configuration

The installer automatically configures `Super + V` in COSMIC's custom shortcuts file (`~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom`).

If you prefer to configure or adjust the shortcut manually in the COSMIC Settings UI:
1. Open **Settings** → **Keyboard** → **Customize Shortcuts**.
2. Click **Add Custom Shortcut**.
3. Name: `Clipboard`
4. Command: `omarchy-clipboard toggle`
5. Shortcut: `Super + V`

---

## Usage

### CLI Commands

```bash
# Toggle the overlay window (open if closed, close if open)
omarchy-clipboard toggle

# Open or close explicitly
omarchy-clipboard open
omarchy-clipboard close

# Check daemon and overlay status ("opened" or "closed")
omarchy-clipboard status

# Run daemon in foreground (for testing or logging)
omarchy-clipboard --daemon

# Stop daemon and cleanup background watchers
omarchy-clipboard kill
```

---

## Technical Architecture

```
omarchy-clipboard-cosmic/
├── main.qml                     # Quickshell root Scope & IpcHandler
├── Clipboard.qml                # Main UI overlay & lifecycle coordinator
├── ClipboardHistory.js          # History management, sorting, filtering logic
├── capture.sh                   # wl-paste watcher script (text & images)
├── bin/
│   ├── omarchy-clipboard        # Main CLI entry point & IPC bridge
│   ├── omarchy-clipboard-paste-text # Text paste automation via wtype
│   ├── omarchy-clipboard-paste-file # Image paste automation via wl-copy
│   └── omarchy-clipboard-open   # External opening handler (xdg-open)
├── Commons/                     # Reusable styling singletons (Color, Style, Util, I18n)
├── Ui/                          # QML overlay primitives (OverlayWindow, BorderSurface, etc.)
├── scripts/
│   ├── install.sh               # Automated Fedora COSMIC installer
│   └── uninstall.sh             # Uninstallation script
└── assets/                      # Desktop entries and icon metadata
```

---

## Troubleshooting & FAQ

### Overlay does not open when pressing Super + V
1. Verify the daemon is running:
   ```bash
   omarchy-clipboard status
   ```
2. If it is stopped, start it:
   ```bash
   omarchy-clipboard toggle
   ```
3. Test manual IPC invocation:
   ```bash
   quickshell ipc -p /path/to/main.qml call clipboard toggle
   ```

### Pasting does not automatically insert text in certain apps
- Some terminal emulators or sandboxed flatpaks restrict virtual keyboard injection (`wtype`). In such applications, selecting an item with `Shift + Enter` copies it to your clipboard so you can paste it manually with `Ctrl + V` or `Ctrl + Shift + V`.

### Sensitive passwords appear in clipboard
- `capture.sh` respects the `x-kde-passwordManagerHint` MIME type and the `CLIPBOARD_STATE=sensitive` environment variable used by password managers (1Password, Bitwarden, KeepassXC). Passwords marked with these hints are never recorded.

---

## License & Attribution

- **Original Implementation**: Copyright © [David Heinemeier Hansson](https://github.com/dhh) and the [Omarchy Contributors](https://github.com/omacom/omarchy).
- **Fedora COSMIC Port**: Copyright © 2026 Amir Ali.
- Licensed under the [MIT License](LICENSE).
