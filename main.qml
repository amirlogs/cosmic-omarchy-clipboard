import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: app

  Clipboard {
    id: clipboard
  }

  IpcHandler {
    target: "clipboard"

    function toggle(): string {
      clipboard.toggle()
      return clipboard.opened ? "opened" : "closed"
    }

    function open(): string {
      clipboard.open("{}")
      return "opened"
    }

    function close(): string {
      clipboard.close()
      return "closed"
    }

    function status(): string {
      return clipboard.opened ? "opened" : "closed"
    }

    function togglePin(): string {
      clipboard.togglePinIndex(clipboard.selectedIndex)
      return "ok"
    }

    function togglePanel(): string {
      clipboard.togglePanelFocus()
      return clipboard.activePanel
    }

    function activePanel(): string {
      return clipboard.activePanel
    }

    function startOcr(): string {
      clipboard.startOcr(false)
      return "ocr"
    }

    function openAndOcr(): string {
      clipboard.startOcr(true)
      return "open-ocr"
    }

    function openSettings(): string {
      clipboard.openAdvancedSettings()
      return "settings"
    }

    function openQuickSettings(): string {
      clipboard.open("{}")
      clipboard.quickSettingsOpen = true
      return "quickSettings"
    }

    function openSettingsCategory(cat: string): string {
      clipboard.openAdvancedSettings()
      clipboard.settingsWindowItem.activeCategory = cat
      return cat
    }
  }
}
