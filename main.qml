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
  }
}
