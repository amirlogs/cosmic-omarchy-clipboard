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

- **Workspace Tabs & Unified Search**: `All`, `History`, and `Pinned` tabs with `All types` / `Text` / `Images` filters, live search, and HTML-safe match highlighting.
- **Two-Panel Interactive Navigation**: `Tab` / `Shift+Tab` switches focus between the left entry list and the right editor/preview pane.
- **Lightweight Text Editor & Optional Vim Mode**: Edit text entries directly in the right panel with coalesced `Ctrl+Z` / `Ctrl+Shift+Z` undo/redo, `Ctrl+F` in-entry search, partial selection copy (`Ctrl+C`), debounced auto-save, and feedback-suppressed Wayland clipboard sync. Toggleable Vim mode (`Normal`, `Insert` with optional `jk` exit, `Visual`, `Visual Line`, `Visual Block`, and `/` search).
- **Screen-Region OCR**: Interactive mouse + keyboard region overlay (`Ctrl+O` or `Super+Shift+S`) backed by `grim` + local `tesseract`, with installed language pack detection (`eng`, `amh`).
- **Image Preview & Actions**: Displays image dimensions, file size, MIME type, and quick actions (`Copy`, `Save`, `Pin/Unpin`, `Delete`).
- **Retention, Cleanup & Settings**: Configurable limits (`100`–`1000` or `Unlimited`), age-based/manual pruning protecting pinned entries, orphaned image cleanup, Quick Settings popover, and a full `SettingsWindow` (`Ctrl+,`) with visual keybinding recorder and conflict detection.

## Testing

```bash
node --test tests/*.test.js
```

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
| `tesseract` & `tesseract-langpack-eng` | Local offline OCR engine & English language data (optional, for Screen OCR) |
| `grim` & `slurp` | Wayland screen capture & region selector (optional, for Screen OCR) |

---

## Installation

> **Download Page:** [https://amirlogs.github.io/cosmic-omarchy-clipboard/](https://amirlogs.github.io/cosmic-omarchy-clipboard/) · **Latest Release:** [GitHub Releases](https://github.com/amirlogs/cosmic-omarchy-clipboard/releases/latest)

### 1. Install System Dependencies & OCR (`tesseract`)

#### Fedora 44 (COSMIC)
```bash
# Core dependencies + Screen OCR (tesseract, grim, slurp)
sudo dnf install -y quickshell wl-clipboard wtype jq perl-JSON-PP tesseract tesseract-langpack-eng grim slurp
```

#### Arch Linux
```bash
sudo pacman -S --needed quickshell wl-clipboard wtype jq perl tesseract tesseract-data-eng grim slurp
```

#### Ubuntu / Debian
```bash
sudo apt install -y wl-clipboard wtype jq libjson-pp-perl tesseract-ocr tesseract-ocr-eng grim slurp
```

> **Additional OCR Languages:** To recognize other languages with Tesseract, install the corresponding language pack (e.g. `sudo dnf install tesseract-langpack-deu tesseract-langpack-fra`), then verify with `tesseract --list-langs`.

### 2. Install Omarchy Clipboard

#### Option A: Quick Install via `curl` (Recommended — downloads latest GitHub Release)
```bash
curl -fsSL https://github.com/amirlogs/cosmic-omarchy-clipboard/releases/latest/download/install.sh | bash
```

#### Option B: Manual Release Download
Download `cosmic-omarchy-clipboard.tar.gz` from the [Latest Release](https://github.com/amirlogs/cosmic-omarchy-clipboard/releases/latest), extract it, and run:
```bash
mkdir -p ~/.local/share/cosmic-omarchy-clipboard
tar -xzf cosmic-omarchy-clipboard.tar.gz -C ~/.local/share/cosmic-omarchy-clipboard
~/.local/share/cosmic-omarchy-clipboard/scripts/install.sh
```

#### Option C: Clone from Source
```bash
git clone https://github.com/amirlogs/cosmic-omarchy-clipboard.git
cd cosmic-omarchy-clipboard
./scripts/install.sh
```

The installer will:
1. Link `bin/omarchy-clipboard` to `~/.local/bin/omarchy-clipboard`.
2. Register the application menu launcher in `~/.local/share/applications/`.
3. Enable autostart on login in `~/.config/autostart/`.
4. Start the background watcher daemon.

> **Note:** The installer **does not force `Super + V`** or overwrite your existing COSMIC shortcuts. If you want it to set `Super + V` automatically, pass `--with-shortcut` (e.g. `... | bash -s -- --with-shortcut`).

---

## Keyboard Shortcut Configuration

You can bind any shortcut you prefer either inside **Clipboard Settings → Keyboard & Shortcuts** (`Ctrl + ,`) or in the COSMIC Settings UI:
1. Open **Settings** → **Keyboard** → **Customize Shortcuts**.
2. Click **Add Custom Shortcut**.
3. Name: `Clipboard`
4. Command: `omarchy-clipboard toggle`
5. Shortcut: your preferred key combination (e.g. `Super + V`)

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
