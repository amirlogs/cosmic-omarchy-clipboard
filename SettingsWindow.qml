import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SettingsStore.js" as SettingsStore
import "Keybindings.js" as Keybindings

FloatingWindow {
  id: win

  property bool opened: false
  property var settings: SettingsStore.defaultSettings()
  property var keybindings: Keybindings.defaultConfig()
  property var installedOcrLangs: []
  property string activeCategory: "general"
  property string searchQuery: ""
  property string recordingScope: ""
  property string recordingAction: ""
  property var keyConflicts: []

  signal updateSettings(var nextSettings)
  signal updateKeybindings(var nextKeybindings)
  signal resetDefaults()
  signal manualCleanup(int hours)
  signal cleanupOrphanImages()
  signal closed()

  visible: opened
  title: "Omarchy Clipboard Settings"
  implicitWidth: Math.min(820, Screen.width - 40)
  implicitHeight: Math.min(560, Screen.height - 40)
  color: "transparent"

  onVisibleChanged: {
    if (!visible && opened) {
      opened = false
      recordingScope = ""
      recordingAction = ""
      closed()
    }
  }

  function mutateSetting(mutator) {
    var next = SettingsStore.parseSettings(win.settings)
    mutator(next)
    win.updateSettings(next)
  }

  function recordBinding(scope, action, combo) {
    var res = Keybindings.setBinding(win.keybindings, scope, action, combo)
    win.keyConflicts = res.conflicts
    win.recordingScope = ""
    win.recordingAction = ""
    win.updateKeybindings(res.config)
  }

  function hasLang(code) {
    return win.installedOcrLangs.indexOf(code) >= 0
  }

  readonly property var categories: [
    { key: "general", label: "General" },
    { key: "keys", label: "Keyboard & Shortcuts" },
    { key: "editor", label: "Editor" },
    { key: "navigation", label: "Navigation" },
    { key: "clipboard", label: "Clipboard" },
    { key: "ocr", label: "OCR" },
    { key: "appearance", label: "Appearance" }
  ]

  BorderSurface {
    id: frame
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Commons.Color.menu.background
    borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(2)))
    padding: Style.space(16)

    Item {
      id: settingsKeys
      anchors.fill: parent
      focus: win.visible

      Keys.onPressed: function(event) {
        if (win.recordingScope && win.recordingAction) {
          if (event.key === Qt.Key_Escape) {
            win.recordingScope = ""
            win.recordingAction = ""
            event.accepted = true
            return
          }
          var qtCodes = {
            Key_Tab: Qt.Key_Tab, Key_Backtab: Qt.Key_Backtab, Key_Delete: Qt.Key_Delete,
            Key_Backspace: Qt.Key_Backspace, Key_Escape: Qt.Key_Escape, Key_Return: Qt.Key_Return,
            Key_Enter: Qt.Key_Enter, Key_F3: Qt.Key_F3, Key_Comma: Qt.Key_Comma
          }
          var combo = Keybindings.qtEventToCombo(event.key, event.modifiers, event.text, qtCodes)
          if (combo) {
            win.recordBinding(win.recordingScope, win.recordingAction, combo)
          }
          event.accepted = true
          return
        }

        if (event.key === Qt.Key_Escape) {
          if (win.searchQuery) win.searchQuery = ""
          else win.opened = false
          event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
          win.searchQuery = win.searchQuery.slice(0, -1)
          event.accepted = true
        } else if (!event.modifiers && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
          win.searchQuery += event.text
          event.accepted = true
        }
      }
    }

    Row {
      anchors.fill: parent
      anchors.topMargin: frame.contentTopInset
      anchors.bottomMargin: frame.contentBottomInset
      anchors.leftMargin: frame.contentLeftInset
      anchors.rightMargin: frame.contentRightInset
      spacing: Style.space(16)

      // Sidebar
      Column {
        width: Style.space(195)
        height: parent.height
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: "Settings"
          color: Commons.Color.menu.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.heading
          font.weight: Font.DemiBold
        }

        Rectangle {
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: Util.alpha(Commons.Color.menu.text, 0.08)

          Text {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: win.searchQuery || "Search settings…"
            color: Commons.Color.menu.text
            opacity: win.searchQuery ? 1.0 : 0.55
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }

        Repeater {
          model: win.categories

          Rectangle {
            required property var modelData
            readonly property bool active: !win.searchQuery && win.activeCategory === modelData.key
            width: parent.width
            height: Style.space(32)
            radius: Style.cornerRadius
            color: active ? Commons.Color.menu.selectedBackground : "transparent"

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              textFormat: Text.PlainText
              text: modelData.label
              color: active ? Commons.Color.menu.selectedText : Commons.Color.menu.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                win.searchQuery = ""
                win.activeCategory = modelData.key
              }
            }
          }
        }

        Item { width: 1; height: Style.space(12) }

        Rectangle {
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: resetMouse.containsMouse ? Util.alpha(Commons.Color.urgent, 0.25) : Util.alpha(Commons.Color.menu.text, 0.08)

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "Reset to Defaults"
            color: Commons.Color.menu.text
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }

          MouseArea {
            id: resetMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.resetDefaults()
          }
        }
      }

      Rectangle {
        width: Style.normalBorderWidth
        height: parent.height
        color: Util.alpha(Commons.Color.menu.border, 0.28)
      }

      // Content pane
      Flickable {
        width: parent.width - Style.space(220)
        height: parent.height
        clip: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: contentCol
          width: parent.width
          spacing: Style.space(14)

          // GENERAL
          Column {
            visible: win.searchQuery ? SettingsStore.matchesSettingSearch("Default Tab Close on Copy", "General startup", win.searchQuery) : win.activeCategory === "general"
            width: parent.width
            spacing: Style.space(10)

            Text { text: "General"; color: Commons.Color.menu.selectedText; font.family: Style.font.menuFamily; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }

            Row {
              spacing: Style.space(8)
              Text { anchors.verticalCenter: parent.verticalCenter; text: "Default Tab:"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body }
              Repeater {
                model: ["history", "pinned", "all"]
                Rectangle {
                  required property string modelData
                  readonly property bool on: win.settings.general.defaultTab === modelData
                  width: dtLbl.implicitWidth + Style.space(14); height: Style.space(26); radius: Style.cornerRadius
                  color: on ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
                  Text { id: dtLbl; anchors.centerIn: parent; text: modelData; color: on ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.general.defaultTab = modelData }) }
                }
              }
            }
          }

          // KEYBOARD & SHORTCUTS
          Column {
            visible: win.searchQuery ? SettingsStore.matchesSettingSearch("Keyboard Shortcuts Keybindings Vim Global", "Shortcuts", win.searchQuery) : win.activeCategory === "keys"
            width: parent.width
            spacing: Style.space(10)

            Text { text: "Keyboard & Shortcuts"; color: Commons.Color.menu.selectedText; font.family: Style.font.menuFamily; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }

            Text {
              visible: win.keyConflicts.length > 0
              text: "Conflict detected: " + (win.keyConflicts.length > 0 ? (win.keyConflicts[0].combo + " (" + win.keyConflicts[0].actionA + " vs " + win.keyConflicts[0].actionB + ")") : "")
              color: Commons.Color.urgent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              width: parent.width
            }

            Repeater {
              model: [
                { scope: "global", action: "openClipboard", label: "Global: Open Clipboard" },
                { scope: "global", action: "ocrExtract", label: "Global: Screen OCR" },
                { scope: "global", action: "clipboardAndOcr", label: "Global: Clipboard + OCR" },
                { scope: "app", action: "switchPanel", label: "App: Switch Panel" },
                { scope: "app", action: "togglePin", label: "App: Pin / Unpin" },
                { scope: "app", action: "startOcr", label: "App: Start OCR" },
                { scope: "app", action: "openSettings", label: "App: Open Settings" },
                { scope: "normal", action: "undo", label: "Editor (Normal): Undo" },
                { scope: "normal", action: "redo", label: "Editor (Normal): Redo" },
                { scope: "normal", action: "find", label: "Editor (Normal): Find" },
                { scope: "vim", action: "undo", label: "Editor (Vim): Undo" },
                { scope: "vim", action: "redo", label: "Editor (Vim): Redo" }
              ]

              Row {
                required property var modelData
                width: parent.width
                height: Style.space(28)
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(150)
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: Commons.Color.menu.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }

                Rectangle {
                  readonly property bool recording: win.recordingScope === modelData.scope && win.recordingAction === modelData.action
                  width: Style.space(135)
                  height: Style.space(24)
                  radius: Style.cornerRadius
                  color: recording ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: parent.recording
                      ? "Press keys…"
                      : ((win.keybindings[modelData.scope] && win.keybindings[modelData.scope][modelData.action]) || "Unbound")
                    color: parent.recording ? Commons.Color.menu.selectedText : Commons.Color.menu.text
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      win.recordingScope = modelData.scope
                      win.recordingAction = modelData.action
                      settingsKeys.forceActiveFocus()
                    }
                  }
                }
              }
            }
          }

          // EDITOR
          Column {
            visible: win.searchQuery ? SettingsStore.matchesSettingSearch("Editor Vim Mode jk Exit", "Vim", win.searchQuery) : win.activeCategory === "editor"
            width: parent.width
            spacing: Style.space(10)

            Text { text: "Editor"; color: Commons.Color.menu.selectedText; font.family: Style.font.menuFamily; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }

            Rectangle {
              width: vimLbl.implicitWidth + Style.space(20); height: Style.space(28); radius: Style.cornerRadius
              color: win.settings.editor.vimMode ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
              Text { id: vimLbl; anchors.centerIn: parent; text: "Vim Mode: " + (win.settings.editor.vimMode ? "Enabled" : "Disabled"); color: win.settings.editor.vimMode ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.editor.vimMode = !s.editor.vimMode }) }
            }

            Rectangle {
              width: jkLbl.implicitWidth + Style.space(20); height: Style.space(28); radius: Style.cornerRadius
              color: win.settings.editor.jkExit ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
              Text { id: jkLbl; anchors.centerIn: parent; text: "Vim 'jk' Insert Exit: " + (win.settings.editor.jkExit ? "Enabled" : "Disabled"); color: win.settings.editor.jkExit ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.editor.jkExit = !s.editor.jkExit }) }
            }
          }

          // NAVIGATION
          Column {
            visible: win.searchQuery ? SettingsStore.matchesSettingSearch("Navigation Wrap Selection", "Panels", win.searchQuery) : win.activeCategory === "navigation"
            width: parent.width
            spacing: Style.space(10)

            Text { text: "Navigation"; color: Commons.Color.menu.selectedText; font.family: Style.font.menuFamily; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }

            Rectangle {
              width: wrapLbl.implicitWidth + Style.space(20); height: Style.space(28); radius: Style.cornerRadius
              color: win.settings.navigation.wrapSelection ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
              Text { id: wrapLbl; anchors.centerIn: parent; text: "Wrap List Selection: " + (win.settings.navigation.wrapSelection ? "On" : "Off"); color: win.settings.navigation.wrapSelection ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.navigation.wrapSelection = !s.navigation.wrapSelection }) }
            }
          }

          // CLIPBOARD RETENTION
          Column {
            visible: win.searchQuery ? SettingsStore.matchesSettingSearch("Clipboard History Limit Retention Cleanup", "Retention", win.searchQuery) : win.activeCategory === "clipboard"
            width: parent.width
            spacing: Style.space(10)

            Text { text: "Clipboard & Retention"; color: Commons.Color.menu.selectedText; font.family: Style.font.menuFamily; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }

            Text { text: "Maximum History Size (pinned entries excluded):"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
            Row {
              spacing: Style.space(6)
              Repeater {
                model: [
                  { val: 100, label: "100" },
                  { val: 250, label: "250" },
                  { val: 500, label: "500" },
                  { val: 1000, label: "1000" },
                  { val: -1, label: "Unlimited" }
                ]
                Rectangle {
                  required property var modelData
                  readonly property bool on: win.settings.clipboard.historyLimit === modelData.val
                  width: limLbl.implicitWidth + Style.space(14); height: Style.space(26); radius: Style.cornerRadius
                  color: on ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
                  Text { id: limLbl; anchors.centerIn: parent; text: modelData.label; color: on ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.clipboard.historyLimit = modelData.val }) }
                }
              }
            }

            Text { text: "Automatic Age Cleanup (pinned entries protected):"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
            Row {
              spacing: Style.space(6)
              Repeater {
                model: [
                  { val: 0, label: "Never" },
                  { val: 24, label: "24h" },
                  { val: 168, label: "7d" },
                  { val: 720, label: "30d" },
                  { val: 2160, label: "90d" }
                ]
                Rectangle {
                  required property var modelData
                  readonly property bool on: win.settings.clipboard.autoCleanupHours === modelData.val
                  width: ageLbl.implicitWidth + Style.space(14); height: Style.space(26); radius: Style.cornerRadius
                  color: on ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
                  Text { id: ageLbl; anchors.centerIn: parent; text: modelData.label; color: on ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.clipboard.autoCleanupHours = modelData.val }) }
                }
              }
            }

            Text { text: "Manual Cleanup:"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
            Row {
              spacing: Style.space(6)
              Repeater {
                model: [
                  { hrs: 24, label: "Older than 24h" },
                  { hrs: 168, label: "Older than 7d" },
                  { hrs: 720, label: "Older than 30d" }
                ]
                Rectangle {
                  required property var modelData
                  width: mcLbl.implicitWidth + Style.space(14); height: Style.space(26); radius: Style.cornerRadius
                  color: Util.alpha(Commons.Color.menu.text, 0.08)
                  Text { id: mcLbl; anchors.centerIn: parent; text: modelData.label; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.manualCleanup(modelData.hrs) }
                }
              }
              Rectangle {
                width: gcLbl.implicitWidth + Style.space(14); height: Style.space(26); radius: Style.cornerRadius
                color: Util.alpha(Commons.Color.menu.text, 0.08)
                Text { id: gcLbl; anchors.centerIn: parent; text: "Clean Orphan Images"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.cleanupOrphanImages() }
              }
            }
          }

          // OCR
          Column {
            visible: win.searchQuery ? SettingsStore.matchesSettingSearch("OCR Language English Amharic Tesseract", "OCR", win.searchQuery) : win.activeCategory === "ocr"
            width: parent.width
            spacing: Style.space(10)

            Text { text: "OCR (Screen Text Extraction)"; color: Commons.Color.menu.selectedText; font.family: Style.font.menuFamily; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }

            Rectangle {
              width: ocrEnLbl.implicitWidth + Style.space(20); height: Style.space(28); radius: Style.cornerRadius
              color: win.settings.ocr.enabled ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
              Text { id: ocrEnLbl; anchors.centerIn: parent; text: "OCR: " + (win.settings.ocr.enabled ? "Enabled" : "Disabled"); color: win.settings.ocr.enabled ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.ocr.enabled = !s.ocr.enabled }) }
            }

            Row {
              spacing: Style.space(6)
              Repeater {
                model: [
                  { val: "eng", label: "English (eng)" },
                  { val: "amh", label: "Amharic (amh)" },
                  { val: "eng+amh", label: "English + Amharic" }
                ]
                Rectangle {
                  required property var modelData
                  readonly property bool on: win.settings.ocr.languages === modelData.val
                  width: olLbl.implicitWidth + Style.space(14); height: Style.space(26); radius: Style.cornerRadius
                  color: on ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
                  Text { id: olLbl; anchors.centerIn: parent; text: modelData.label; color: on ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.ocr.languages = modelData.val }) }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "Installed Tesseract languages: " + (win.installedOcrLangs.length > 0 ? win.installedOcrLangs.join(", ") : "none detected")
                + (!win.hasLang("amh") ? "\nMissing Amharic pack: install 'tesseract-langpack-amh' on Fedora." : "")
              color: !win.hasLang("amh") && win.settings.ocr.languages.indexOf("amh") >= 0 ? Commons.Color.warning : Commons.Color.menu.text
              opacity: 0.78
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              width: parent.width
            }
          }

          // APPEARANCE
          Column {
            visible: win.searchQuery ? SettingsStore.matchesSettingSearch("Appearance Opacity Transparency", "Theme", win.searchQuery) : win.activeCategory === "appearance"
            width: parent.width
            spacing: Style.space(10)

            Text { text: "Appearance"; color: Commons.Color.menu.selectedText; font.family: Style.font.menuFamily; font.pixelSize: Style.font.title; font.weight: Font.DemiBold }

            Text { text: "Overlay Background Opacity:"; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall }
            Row {
              spacing: Style.space(6)
              Repeater {
                model: [0.75, 0.85, 0.94, 1.0]
                Rectangle {
                  required property real modelData
                  readonly property bool on: Math.abs(win.settings.appearance.backgroundOpacity - modelData) < 0.01
                  width: opLbl.implicitWidth + Style.space(14); height: Style.space(26); radius: Style.cornerRadius
                  color: on ? Commons.Color.menu.selectedBackground : Util.alpha(Commons.Color.menu.text, 0.08)
                  Text { id: opLbl; anchors.centerIn: parent; text: Math.round(modelData * 100) + "%"; color: on ? Commons.Color.menu.selectedText : Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.caption }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.mutateSetting(function(s) { s.appearance.backgroundOpacity = modelData }) }
                }
              }
            }
          }
        }
      }
    }
  }
}
