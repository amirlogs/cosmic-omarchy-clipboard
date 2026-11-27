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
  property var externalShortcuts: []
  property string activeCategory: "general"
  property string searchQuery: ""
  property string recordingScope: ""
  property string recordingAction: ""
  property var keyConflicts: []
  property var pendingOverride: null

  signal updateSettings(var nextSettings)
  signal updateKeybindings(var nextKeybindings, var overrideCombos)
  signal resetDefaults()
  signal manualCleanup(int hours)
  signal cleanupOrphanImages()
  signal windowClosed()

  visible: opened
  title: "Clipboard Settings"
  implicitWidth: Math.min(900, Screen.width - 40)
  implicitHeight: Math.min(640, Screen.height - 40)
  color: Commons.Color.menu.background

  onVisibleChanged: {
    if (visible) {
      Qt.callLater(function() { settingsKeys.forceActiveFocus() })
    } else if (opened) {
      opened = false
      recordingScope = ""
      recordingAction = ""
      pendingOverride = null
      windowClosed()
    }
  }

  function mutateSetting(mutator) {
    var next = SettingsStore.parseSettings(win.settings)
    mutator(next)
    win.settings = next
    win.updateSettings(next)
  }

  function actionLabelFor(scope, action) {
    var labels = {
      "global:openClipboard": "Open clipboard (Global)",
      "global:ocrExtract": "Screen OCR (Global)",
      "global:clipboardAndOcr": "Clipboard + OCR (Global)",
      "app:switchPanel": "Switch panel (Application)",
      "app:switchTab": "Next tab (Application)",
      "app:tabHistory": "History tab (Application)",
      "app:tabPinned": "Pinned tab (Application)",
      "app:togglePin": "Pin / Unpin (Application)",
      "app:deleteEntry": "Delete entry (Application)",
      "app:clearHistory": "Clear history (Application)",
      "app:undoDelete": "Undo delete (Application)",
      "app:startOcr": "Start OCR (Application)",
      "app:openSettings": "Open settings (Application)",
      "normal:undo": "Undo (Normal editor)",
      "normal:redo": "Redo (Normal editor)",
      "normal:copySelection": "Copy selection (Normal editor)",
      "normal:cutSelection": "Cut selection (Normal editor)",
      "normal:paste": "Paste (Normal editor)",
      "normal:selectAll": "Select all (Normal editor)",
      "normal:find": "Find in text (Normal editor)",
      "vim:undo": "Undo (Vim editor)",
      "vim:redo": "Redo (Vim editor)"
    }
    return labels[scope + ":" + action] || (scope + "." + action)
  }

  function findBindingConflicts(scope, action, combo) {
    var norm = (scope === "vim" && String(combo).indexOf("+") < 0)
      ? String(combo || "")
      : Keybindings.normalizeCombo(combo)
    if (!norm) return []

    var conflicts = []
    var checkScopes = [scope]
    if (scope === "global") checkScopes.push("app")
    else if (scope === "app") checkScopes.push("global")

    for (var s = 0; s < checkScopes.length; s++) {
      var sc = checkScopes[s]
      var map = win.keybindings[sc] || {}
      for (var act in map) {
        if (sc === scope && act === action) continue
        var existing = (sc === "vim" && String(map[act]).indexOf("+") < 0)
          ? String(map[act] || "")
          : Keybindings.normalizeCombo(map[act])
        if (existing && existing === norm) {
          conflicts.push({
            type: "internal",
            scope: sc,
            action: act,
            combo: norm,
            label: win.actionLabelFor(sc, act)
          })
        }
      }
    }

    if (scope === "global" && Array.isArray(win.externalShortcuts)) {
      for (var e = 0; e < win.externalShortcuts.length; e++) {
        var ext = win.externalShortcuts[e]
        if (!ext || !ext.combo) continue
        if (Keybindings.normalizeCombo(ext.combo) === norm) {
          conflicts.push({
            type: "external",
            combo: norm,
            label: ext.label + " (COSMIC System Shortcut)"
          })
        }
      }
    }

    return conflicts
  }

  function recordBinding(scope, action, combo) {
    win.recordingScope = ""
    win.recordingAction = ""
    if (combo) {
      var conflicts = win.findBindingConflicts(scope, action, combo)
      if (conflicts.length > 0) {
        win.pendingOverride = {
          scope: scope,
          action: action,
          combo: combo,
          conflicts: conflicts
        }
        return
      }
    }
    var res = Keybindings.setBinding(win.keybindings, scope, action, combo)
    win.keyConflicts = res.conflicts
    win.updateKeybindings(res.config, [])
  }

  function confirmOverride() {
    if (!win.pendingOverride) return
    var p = win.pendingOverride
    win.pendingOverride = null

    var next = Keybindings.cloneConfig(win.keybindings)
    var extOverrides = []
    for (var i = 0; i < p.conflicts.length; i++) {
      var c = p.conflicts[i]
      if (c.type === "internal" && next[c.scope] && next[c.scope][c.action] !== undefined) {
        next[c.scope][c.action] = ""
      } else if (c.type === "external" && c.combo) {
        extOverrides.push(c.combo)
      }
    }
    var res = Keybindings.setBinding(next, p.scope, p.action, p.combo)
    win.keyConflicts = res.conflicts
    win.updateKeybindings(res.config, extOverrides)
  }

  function hasLang(code) {
    return win.installedOcrLangs.indexOf(code) >= 0
  }

  function comboFor(scope, action) {
    return (win.keybindings[scope] && win.keybindings[scope][action]) || ""
  }

  function isConflicted(scope, action) {
    for (var i = 0; i < win.keyConflicts.length; i++) {
      var c = win.keyConflicts[i]
      if ((c.scopeA === scope && c.actionA === action) || (c.scopeB === scope && c.actionB === action)) return true
    }
    return false
  }

  readonly property var categories: [
    { key: "general",    label: "General" },
    { key: "keys",       label: "Keyboard & Shortcuts" },
    { key: "editor",     label: "Editor" },
    { key: "navigation", label: "Navigation" },
    { key: "clipboard",  label: "Clipboard" },
    { key: "ocr",        label: "OCR" },
    { key: "appearance", label: "Appearance" }
  ]

  Rectangle {
    id: frame
    anchors.fill: parent
    color: Commons.Color.menu.background

    Item {
      id: settingsKeys
      anchors.fill: parent
      focus: win.visible

      Keys.onPressed: function(event) {
        if (win.pendingOverride) {
          if (event.key === Qt.Key_Escape) {
            win.pendingOverride = null
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            win.confirmOverride()
            event.accepted = true
          }
          return
        }

        if (win.recordingScope && win.recordingAction) {
          if (event.key === Qt.Key_Escape) {
            win.recordingScope = ""
            win.recordingAction = ""
            event.accepted = true
            return
          }
          if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) && !event.modifiers) {
            win.recordBinding(win.recordingScope, win.recordingAction, "")
            event.accepted = true
            return
          }
          var qtCodes = {
            Key_Tab: Qt.Key_Tab, Key_Backtab: Qt.Key_Backtab, Key_Delete: Qt.Key_Delete,
            Key_Backspace: Qt.Key_Backspace, Key_Escape: Qt.Key_Escape, Key_Return: Qt.Key_Return,
            Key_Enter: Qt.Key_Enter, Key_Space: Qt.Key_Space,
            Key_Left: Qt.Key_Left, Key_Right: Qt.Key_Right, Key_Up: Qt.Key_Up, Key_Down: Qt.Key_Down,
            Key_Home: Qt.Key_Home, Key_End: Qt.Key_End, Key_PageUp: Qt.Key_PageUp, Key_PageDown: Qt.Key_PageDown,
            Key_F1: Qt.Key_F1, Key_F3: Qt.Key_F3, Key_F12: Qt.Key_F12,
            Key_Comma: Qt.Key_Comma, Key_Period: Qt.Key_Period, Key_Slash: Qt.Key_Slash,
            Key_Control: Qt.Key_Control, Key_Shift: Qt.Key_Shift, Key_Alt: Qt.Key_Alt, Key_Meta: Qt.Key_Meta
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
      anchors.margins: Style.space(16)
      spacing: 0

      // ── SIDEBAR ──────────────────────────────────────────────────────────
      Item {
        width: Style.space(196)
        height: parent.height

        Column {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: resetLinkItem.top
          spacing: 0

          // Window title
          Item {
            width: parent.width
            height: Style.space(44)

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              text: "Settings"
              color: Commons.Color.menu.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
              font.weight: Font.DemiBold
            }
          }

          // Search box
          Rectangle {
            width: parent.width
            height: Style.space(34)
            radius: Math.max(4, Style.space(5))
            color: Util.alpha(Commons.Color.menu.text, 0.07)
            border.width: 1
            border.color: win.searchQuery.length > 0
              ? Util.alpha(Commons.Color.accent, 0.5)
              : Util.alpha(Commons.Color.menu.text, 0.14)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)

              Text {
                width: parent.width - (clearSearchBtn.visible ? clearSearchBtn.width + Style.space(4) : 0)
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                textFormat: Text.PlainText
                text: win.searchQuery || "Search settings…"
                color: Commons.Color.menu.text
                opacity: win.searchQuery ? 1.0 : 0.45
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                id: clearSearchBtn
                visible: win.searchQuery.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: Util.alpha(Commons.Color.menu.text, 0.6)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    win.searchQuery = ""
                    settingsKeys.forceActiveFocus()
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              z: -1
              cursorShape: Qt.IBeamCursor
              onClicked: settingsKeys.forceActiveFocus()
            }
          }

          Item { width: 1; height: Style.space(8) }

          // Category items
          Repeater {
            model: win.categories

            Item {
              required property var modelData
              readonly property bool active: !win.searchQuery && win.activeCategory === modelData.key

              width: parent.width
              height: Style.space(38)

              // Active left bar
              Rectangle {
                visible: active
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: Style.space(4)
                anchors.bottomMargin: Style.space(4)
                width: Style.space(2)
                radius: Style.space(1)
                color: Commons.Color.menu.selectedText
              }

              // Active background
              Rectangle {
                visible: active
                anchors.fill: parent
                anchors.leftMargin: Style.space(2)
                radius: Math.max(4, Style.space(5))
                color: Util.alpha(Commons.Color.menu.selectedText, 0.08)
              }

              // Hover background
              Rectangle {
                visible: !active && sidebarItemMouse.containsMouse
                anchors.fill: parent
                anchors.leftMargin: Style.space(2)
                radius: Math.max(4, Style.space(5))
                color: Util.alpha(Commons.Color.menu.text, 0.05)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(14)
                textFormat: Text.PlainText
                text: modelData.label
                color: active ? Commons.Color.menu.selectedText : Commons.Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
                font.weight: active ? Font.DemiBold : Font.Normal
                opacity: active ? 1.0 : 0.72
              }

              MouseArea {
                id: sidebarItemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  win.searchQuery = ""
                  win.activeCategory = modelData.key
                }
              }
            }
          }
        }

        // Reset to Defaults — anchored to bottom
        Item {
          id: resetLinkItem
          width: parent.width
          height: Style.space(32)
          anchors.bottom: parent.bottom

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            text: "Reset to Defaults"
            color: resetMouse.containsMouse ? Commons.Color.urgent : Util.alpha(Commons.Color.urgent, 0.7)
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

      // Sidebar divider
      Rectangle {
        width: 1
        height: parent.height
        color: Util.alpha(Commons.Color.menu.border, 0.2)
      }

      Item { width: Style.space(16); height: 1 }

      // ── CONTENT PANE ─────────────────────────────────────────────────────
      Flickable {
        id: contentFlick
        width: parent.width - Style.space(196) - 1 - Style.space(16)
        height: parent.height
        clip: true
        contentWidth: width - Style.space(12)
        contentHeight: contentCol.implicitHeight + Style.space(24)
        boundsBehavior: Flickable.StopAtBounds

        // Scrollbar thumb
        Rectangle {
          visible: contentFlick.contentHeight > contentFlick.height
          anchors.right: parent.right
          anchors.rightMargin: Style.space(2)
          y: Math.max(0, contentFlick.visibleArea.yPosition * contentFlick.height)
          width: Style.space(3)
          height: Math.max(Style.space(24), contentFlick.visibleArea.heightRatio * contentFlick.height)
          radius: Style.space(2)
          color: Commons.Color.menu.text
          opacity: 0.3
          z: 5
        }

        Column {
          id: contentCol
          width: parent.width
          spacing: Style.space(24)

          // ── GENERAL ────────────────────────────────────────────────────
          Column {
            visible: win.searchQuery
              ? SettingsStore.matchesSettingSearch("Default Tab Close on Copy Startup Behavior", "General", win.searchQuery)
              : win.activeCategory === "general"
            width: parent.width
            spacing: 0

            // Page title
            Item {
              width: parent.width
              height: Style.space(36)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "General"
                color: Commons.Color.menu.selectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.heading
                font.weight: Font.DemiBold
              }
            }

            SettingsSection { title: "Startup"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Default tab"
              description: "Which tab opens when the clipboard is shown."
              SSegment {
                model: [
                  { val: "history", label: "History" },
                  { val: "pinned",  label: "Pinned" },
                  { val: "all",     label: "All" }
                ]
                currentValue: win.settings.general.defaultTab
                onSelected: function(v) { win.mutateSetting(function(s) { s.general.defaultTab = v }) }
              }
            }

            SettingsSection { title: "Behavior"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Close after copy"
              description: "Dismiss the clipboard overlay after choosing or copying an entry."
              SSwitch {
                checked: win.settings.general.closeOnCopy
                onToggled: win.mutateSetting(function(s) { s.general.closeOnCopy = !s.general.closeOnCopy })
              }
            }
          }

          // ── KEYBOARD & SHORTCUTS ────────────────────────────────────────
          Column {
            visible: win.searchQuery
              ? SettingsStore.matchesSettingSearch("Keyboard Shortcuts Keybindings Vim Global App Editor", "Shortcuts", win.searchQuery)
              : win.activeCategory === "keys"
            width: parent.width
            spacing: 0

            Item {
              width: parent.width
              height: Style.space(36)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Keyboard & Shortcuts"
                color: Commons.Color.menu.selectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.heading
                font.weight: Font.DemiBold
              }
            }

            WarningBanner {
              visible: win.keyConflicts.length > 0
              width: parent.width
              message: win.keyConflicts.length > 0
                ? ("Shortcut conflict: " + win.keyConflicts[0].combo + " is used by both " + win.keyConflicts[0].actionA + " and " + win.keyConflicts[0].actionB + ".")
                : ""
            }

            SettingsSection { title: "Global"; width: parent.width }

            Rectangle {
              width: parent.width
              height: globalGroupCol.implicitHeight
              radius: Math.max(6, Style.space(8))
              color: Util.alpha(Commons.Color.menu.text, 0.03)
              border.width: 1
              border.color: Util.alpha(Commons.Color.menu.text, 0.08)

              Column {
                id: globalGroupCol
                width: parent.width

                Repeater {
                  model: [
                    { scope: "global", action: "openClipboard",   label: "Open clipboard",     description: "Show or hide the clipboard overlay." },
                    { scope: "global", action: "ocrExtract",      label: "Screen OCR",          description: "Select a screen region and extract text." },
                    { scope: "global", action: "clipboardAndOcr", label: "Clipboard + OCR",     description: "Open the clipboard and trigger OCR." }
                  ]
                  KeycapRow {
                    required property var modelData
                    required property int index
                    width: parent.width
                    label: modelData.label
                    description: modelData.description
                    showDivider: index < 2
                    comboString: win.comboFor(modelData.scope, modelData.action)
                    recording: win.recordingScope === modelData.scope && win.recordingAction === modelData.action
                    conflicted: win.isConflicted(modelData.scope, modelData.action)
                    onEdit: {
                      win.recordingScope = modelData.scope
                      win.recordingAction = modelData.action
                      settingsKeys.forceActiveFocus()
                    }
                    onCancel: {
                      win.recordingScope = ""
                      win.recordingAction = ""
                    }
                    onClear: win.recordBinding(modelData.scope, modelData.action, "")
                  }
                }
              }
            }

            SettingsSection { title: "Application"; width: parent.width }

            Rectangle {
              width: parent.width
              height: appGroupCol.implicitHeight
              radius: Math.max(6, Style.space(8))
              color: Util.alpha(Commons.Color.menu.text, 0.03)
              border.width: 1
              border.color: Util.alpha(Commons.Color.menu.text, 0.08)

              Column {
                id: appGroupCol
                width: parent.width

                Repeater {
                  model: [
                    { scope: "app", action: "switchPanel",   label: "Switch panel",        description: "Move focus between the list and editor." },
                    { scope: "app", action: "switchTab",     label: "Next tab",             description: "Cycle through History / Pinned / All." },
                    { scope: "app", action: "togglePin",     label: "Pin / Unpin",          description: "Toggle the pin state of the selected entry." },
                    { scope: "app", action: "deleteEntry",   label: "Delete entry",         description: "Remove the selected entry from history." },
                    { scope: "app", action: "undoDelete",    label: "Undo delete",          description: "Restore the last deleted entry." },
                    { scope: "app", action: "startOcr",      label: "Start OCR",            description: "Begin a screen-region capture." },
                    { scope: "app", action: "openSettings",  label: "Open settings",        description: "Open the advanced settings window." }
                  ]
                  KeycapRow {
                    required property var modelData
                    required property int index
                    width: parent.width
                    label: modelData.label
                    description: modelData.description
                    showDivider: index < 6
                    comboString: win.comboFor(modelData.scope, modelData.action)
                    recording: win.recordingScope === modelData.scope && win.recordingAction === modelData.action
                    conflicted: win.isConflicted(modelData.scope, modelData.action)
                    onEdit: {
                      win.recordingScope = modelData.scope
                      win.recordingAction = modelData.action
                      settingsKeys.forceActiveFocus()
                    }
                    onCancel: {
                      win.recordingScope = ""
                      win.recordingAction = ""
                    }
                    onClear: win.recordBinding(modelData.scope, modelData.action, "")
                  }
                }
              }
            }

            SettingsSection { title: "Normal editor"; width: parent.width }

            Rectangle {
              width: parent.width
              height: normalGroupCol.implicitHeight
              radius: Math.max(6, Style.space(8))
              color: Util.alpha(Commons.Color.menu.text, 0.03)
              border.width: 1
              border.color: Util.alpha(Commons.Color.menu.text, 0.08)

              Column {
                id: normalGroupCol
                width: parent.width

                Repeater {
                  model: [
                    { scope: "normal", action: "undo",           label: "Undo" },
                    { scope: "normal", action: "redo",           label: "Redo" },
                    { scope: "normal", action: "copySelection",  label: "Copy selection" },
                    { scope: "normal", action: "paste",          label: "Paste" },
                    { scope: "normal", action: "find",           label: "Find in text" }
                  ]
                  KeycapRow {
                    required property var modelData
                    required property int index
                    width: parent.width
                    label: modelData.label
                    showDivider: index < 4
                    comboString: win.comboFor(modelData.scope, modelData.action)
                    recording: win.recordingScope === modelData.scope && win.recordingAction === modelData.action
                    conflicted: win.isConflicted(modelData.scope, modelData.action)
                    onEdit: {
                      win.recordingScope = modelData.scope
                      win.recordingAction = modelData.action
                      settingsKeys.forceActiveFocus()
                    }
                    onCancel: {
                      win.recordingScope = ""
                      win.recordingAction = ""
                    }
                    onClear: win.recordBinding(modelData.scope, modelData.action, "")
                  }
                }
              }
            }

            SettingsSection { title: "Vim editor"; width: parent.width }

            Rectangle {
              width: parent.width
              height: vimGroupCol.implicitHeight
              radius: Math.max(6, Style.space(8))
              color: Util.alpha(Commons.Color.menu.text, 0.03)
              border.width: 1
              border.color: Util.alpha(Commons.Color.menu.text, 0.08)

              Column {
                id: vimGroupCol
                width: parent.width

                Repeater {
                  model: [
                    { scope: "vim", action: "undo", label: "Undo" },
                    { scope: "vim", action: "redo", label: "Redo" }
                  ]
                  KeycapRow {
                    required property var modelData
                    required property int index
                    width: parent.width
                    label: modelData.label
                    showDivider: index < 1
                    comboString: win.comboFor(modelData.scope, modelData.action)
                    recording: win.recordingScope === modelData.scope && win.recordingAction === modelData.action
                    conflicted: win.isConflicted(modelData.scope, modelData.action)
                    onEdit: {
                      win.recordingScope = modelData.scope
                      win.recordingAction = modelData.action
                      settingsKeys.forceActiveFocus()
                    }
                    onCancel: {
                      win.recordingScope = ""
                      win.recordingAction = ""
                    }
                    onClear: win.recordBinding(modelData.scope, modelData.action, "")
                  }
                }
              }
            }
          }

          // ── EDITOR ──────────────────────────────────────────────────────
          Column {
            visible: win.searchQuery
              ? SettingsStore.matchesSettingSearch("Editor Vim Mode jk Exit Cursor Style Font Size", "Vim", win.searchQuery)
              : win.activeCategory === "editor"
            width: parent.width
            spacing: 0

            Item {
              width: parent.width
              height: Style.space(36)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Editor"
                color: Commons.Color.menu.selectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.heading
                font.weight: Font.DemiBold
              }
            }

            SettingsSection { title: "Editing mode"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Vim mode"
              description: "Modal editing with Normal, Insert, and Visual modes."
              SSwitch {
                checked: win.settings.editor.vimMode
                onToggled: win.mutateSetting(function(s) { s.editor.vimMode = !s.editor.vimMode })
              }
            }

            SettingsRow {
              width: parent.width
              label: "jk exit Insert"
              description: "Press j then k quickly to exit Insert mode."
              disabled: !win.settings.editor.vimMode
              SSwitch {
                checked: win.settings.editor.jkExit
                onToggled: win.mutateSetting(function(s) { s.editor.jkExit = !s.editor.jkExit })
              }
            }

            SettingsSection { title: "Cursor"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Normal mode cursor"
              description: "Cursor shape in Normal navigation mode."
              SSegment {
                model: [
                  { val: "block",     label: "Block" },
                  { val: "line",      label: "Line" },
                  { val: "underline", label: "Underline" }
                ]
                currentValue: win.settings.editor.normalCursorStyle || "block"
                onSelected: function(v) { win.mutateSetting(function(s) { s.editor.normalCursorStyle = v }) }
              }
            }

            SettingsRow {
              width: parent.width
              label: "Insert mode cursor"
              description: "Cursor shape in Insert typing mode."
              SSegment {
                model: [
                  { val: "line",      label: "Line" },
                  { val: "block",     label: "Block" },
                  { val: "underline", label: "Underline" }
                ]
                currentValue: win.settings.editor.insertCursorStyle || "line"
                onSelected: function(v) { win.mutateSetting(function(s) { s.editor.insertCursorStyle = v }) }
              }
            }

            SettingsSection { title: "Typography"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Editor font size"
              SSegment {
                model: [
                  { val: 12, label: "12px" },
                  { val: 14, label: "14px" },
                  { val: 16, label: "16px" },
                  { val: 18, label: "18px" }
                ]
                currentValue: win.settings.editor.fontSize
                onSelected: function(v) { win.mutateSetting(function(s) { s.editor.fontSize = v }) }
              }
            }
          }

          // ── NAVIGATION ──────────────────────────────────────────────────
          Column {
            visible: win.searchQuery
              ? SettingsStore.matchesSettingSearch("Navigation Wrap Selection", "Panels", win.searchQuery)
              : win.activeCategory === "navigation"
            width: parent.width
            spacing: 0

            Item {
              width: parent.width
              height: Style.space(36)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Navigation"
                color: Commons.Color.menu.selectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.heading
                font.weight: Font.DemiBold
              }
            }

            SettingsSection { title: "List behavior"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Wrap selection"
              description: "Moving past the last entry wraps back to the first, and vice versa."
              SSwitch {
                checked: win.settings.navigation.wrapSelection
                onToggled: win.mutateSetting(function(s) { s.navigation.wrapSelection = !s.navigation.wrapSelection })
              }
            }
          }

          // ── CLIPBOARD & RETENTION ───────────────────────────────────────
          Column {
            visible: win.searchQuery
              ? SettingsStore.matchesSettingSearch("Clipboard History Limit Retention Cleanup Age", "Retention", win.searchQuery)
              : win.activeCategory === "clipboard"
            width: parent.width
            spacing: 0

            Item {
              width: parent.width
              height: Style.space(36)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Clipboard & Retention"
                color: Commons.Color.menu.selectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.heading
                font.weight: Font.DemiBold
              }
            }

            SettingsSection { title: "History capacity"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Maximum entries"
              description: "Pinned entries are not counted towards this limit."
              SDropdown {
                width: Style.space(130)
                model: [
                  { val: 100,  label: "100 entries" },
                  { val: 250,  label: "250 entries" },
                  { val: 500,  label: "500 entries" },
                  { val: 1000, label: "1000 entries" },
                  { val: -1,   label: "Unlimited" }
                ]
                currentValue: win.settings.clipboard.historyLimit
                onSelected: function(v) { win.mutateSetting(function(s) { s.clipboard.historyLimit = v }) }
              }
            }

            SettingsSection { title: "Automatic cleanup"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Remove entries older than"
              description: "Pinned entries are always protected from automatic cleanup."
              SDropdown {
                width: Style.space(130)
                model: [
                  { val: 0,    label: "Never" },
                  { val: 24,   label: "24 hours" },
                  { val: 168,  label: "7 days" },
                  { val: 720,  label: "30 days" },
                  { val: 2160, label: "90 days" }
                ]
                currentValue: win.settings.clipboard.autoCleanupHours
                onSelected: function(v) { win.mutateSetting(function(s) { s.clipboard.autoCleanupHours = v }) }
              }
            }

            SettingsSection { title: "Manual cleanup"; width: parent.width }

            WarningBanner {
              width: parent.width
              message: "These actions permanently remove clipboard history. Pinned entries are not affected."
            }

            Item { width: 1; height: Style.space(8) }

            // Cleanup action buttons — text-style destructive buttons
            Flow {
              width: parent.width
              spacing: Style.space(8)

              Repeater {
                model: [
                  { hrs: 24,  label: "Remove older than 24h" },
                  { hrs: 168, label: "Remove older than 7d" },
                  { hrs: 720, label: "Remove older than 30d" }
                ]
                Rectangle {
                  required property var modelData
                  height: Style.space(32)
                  width: mcBtnText.implicitWidth + Style.space(16)
                  radius: Math.max(4, Style.space(5))
                  color: mcBtnMouse.containsMouse ? Util.alpha(Commons.Color.urgent, 0.18) : Util.alpha(Commons.Color.urgent, 0.08)
                  border.width: 1
                  border.color: Util.alpha(Commons.Color.urgent, mcBtnMouse.containsMouse ? 0.5 : 0.25)

                  Text {
                    id: mcBtnText
                    anchors.centerIn: parent
                    text: modelData.label
                    color: Commons.Color.urgent
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  MouseArea {
                    id: mcBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.manualCleanup(modelData.hrs)
                  }
                }
              }

              Rectangle {
                height: Style.space(32)
                width: gcBtnText.implicitWidth + Style.space(16)
                radius: Math.max(4, Style.space(5))
                color: gcBtnMouse.containsMouse ? Util.alpha(Commons.Color.urgent, 0.18) : Util.alpha(Commons.Color.urgent, 0.08)
                border.width: 1
                border.color: Util.alpha(Commons.Color.urgent, gcBtnMouse.containsMouse ? 0.5 : 0.25)

                Text {
                  id: gcBtnText
                  anchors.centerIn: parent
                  text: "Clean orphan images"
                  color: Commons.Color.urgent
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  id: gcBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: win.cleanupOrphanImages()
                }
              }
            }
          }

          // ── OCR ─────────────────────────────────────────────────────────
          Column {
            visible: win.searchQuery
              ? SettingsStore.matchesSettingSearch("OCR Language English Amharic Tesseract Screen Extraction", "OCR", win.searchQuery)
              : win.activeCategory === "ocr"
            width: parent.width
            spacing: 0

            Item {
              width: parent.width
              height: Style.space(36)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "OCR"
                color: Commons.Color.menu.selectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.heading
                font.weight: Font.DemiBold
              }
            }

            SettingsSection { title: "Feature"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Screen text extraction"
              description: "Select a screen region and extract text using Tesseract OCR."
              SSwitch {
                checked: win.settings.ocr.enabled
                onToggled: win.mutateSetting(function(s) { s.ocr.enabled = !s.ocr.enabled })
              }
            }

            SettingsSection { title: "Language"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Recognition language"
              description: "The Tesseract language pack used for extraction."
              disabled: !win.settings.ocr.enabled
              SSegment {
                model: [
                  { val: "eng",     label: "English" },
                  { val: "amh",     label: "Amharic" },
                  { val: "eng+amh", label: "English + Amharic" }
                ]
                currentValue: win.settings.ocr.languages
                onSelected: function(v) { win.mutateSetting(function(s) { s.ocr.languages = v }) }
              }
            }

            // Status list
            Item { width: 1; height: Style.space(8) }

            Repeater {
              model: [
                { code: "eng", label: "English (eng)" },
                { code: "amh", label: "Amharic (amh)" }
              ]
              Item {
                required property var modelData
                width: parent.width
                height: Style.space(28)

                Row {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(8)

                  Text {
                    text: win.hasLang(modelData.code) ? "✓" : "✗"
                    color: win.hasLang(modelData.code) ? Commons.Color.accent : Commons.Color.urgent
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: modelData.label
                    color: Commons.Color.menu.text
                    opacity: win.hasLang(modelData.code) ? 0.85 : 0.6
                    font.family: Style.font.menuFamily
                    font.pixelSize: Style.font.bodySmall
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }

            WarningBanner {
              visible: !win.hasLang("amh") && win.settings.ocr.languages.indexOf("amh") >= 0
              width: parent.width
              message: "Amharic language pack is not installed. Run: sudo dnf install tesseract-langpack-amh"
            }

            Item { width: 1; height: Style.space(4) }

            Text {
              text: "Installed packs: " + (win.installedOcrLangs.length > 0 ? win.installedOcrLangs.join(", ") : "none detected")
              color: Util.alpha(Commons.Color.menu.text, 0.5)
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
            }
          }

          // ── APPEARANCE ──────────────────────────────────────────────────
          Column {
            visible: win.searchQuery
              ? SettingsStore.matchesSettingSearch("Appearance Opacity Transparency Corner Radius", "Theme", win.searchQuery)
              : win.activeCategory === "appearance"
            width: parent.width
            spacing: 0

            Item {
              width: parent.width
              height: Style.space(36)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Appearance"
                color: Commons.Color.menu.selectedText
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.heading
                font.weight: Font.DemiBold
              }
            }

            SettingsSection { title: "Transparency"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Background opacity"
              description: "Controls how transparent the clipboard overlay is."
              SSlider {
                width: Style.space(180)
                min: 0.5
                max: 1.0
                step: 0.05
                value: win.settings.appearance.backgroundOpacity
                formatValue: function(v) { return Math.round(v * 100) + "%" }
                onMoved: function(v) { win.mutateSetting(function(s) { s.appearance.backgroundOpacity = v }) }
              }
            }

            SettingsSection { title: "Shape"; width: parent.width }

            SettingsRow {
              width: parent.width
              label: "Corner radius"
              description: "Controls the roundness of the overlay and its UI elements."
              SSegment {
                model: [
                  { val: 0,  label: "None" },
                  { val: 8,  label: "Small" },
                  { val: 12, label: "Medium" },
                  { val: 16, label: "Large" }
                ]
                currentValue: win.settings.appearance.cornerRadius
                onSelected: function(v) { win.mutateSetting(function(s) { s.appearance.cornerRadius = v }) }
              }
            }
          }

          // Footer spacer
          Item { width: 1; height: Style.space(8) }
        }
      }
    }

    // ── SHORTCUT CONFLICT OVERRIDE MODAL ──────────────────────────────────
    Rectangle {
      visible: win.pendingOverride !== null
      anchors.fill: parent
      color: Util.alpha("#000000", 0.55)
      z: 50

      MouseArea {
        anchors.fill: parent
        onClicked: win.pendingOverride = null
      }

      Rectangle {
        width: Math.min(Style.space(420), parent.width - Style.space(48))
        height: overrideDialogCol.implicitHeight + Style.space(36)
        anchors.centerIn: parent
        radius: Math.max(8, Style.space(10))
        color: Commons.Color.menu.background
        border.width: 1
        border.color: Util.alpha(Commons.Color.warning, 0.5)

        MouseArea { anchors.fill: parent } // absorb clicks inside dialog

        Column {
          id: overrideDialogCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(18)
          spacing: Style.space(12)

          Row {
            spacing: Style.space(8)
            Text {
              text: "⚠"
              color: Commons.Color.warning
              font.pixelSize: Style.font.heading
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "Shortcut Already Taken"
              color: Commons.Color.menu.selectedText
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.heading
              font.weight: Font.DemiBold
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Util.alpha(Commons.Color.menu.text, 0.85)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            text: {
              if (!win.pendingOverride) return ""
              var lines = []
              for (var i = 0; i < win.pendingOverride.conflicts.length; i++) {
                lines.push("• " + win.pendingOverride.conflicts[i].label)
              }
              return win.pendingOverride.combo + " is already assigned to:\n" + lines.join("\n") +
                "\n\nOverride and assign " + win.pendingOverride.combo + " to \"" +
                win.actionLabelFor(win.pendingOverride.scope, win.pendingOverride.action) + "\"?"
            }
          }

          Row {
            anchors.right: parent.right
            spacing: Style.space(8)

            Rectangle {
              height: Style.space(30)
              width: cancelOvText.implicitWidth + Style.space(24)
              radius: Math.max(4, Style.space(5))
              color: cancelOvMouse.containsMouse
                ? Util.alpha(Commons.Color.menu.text, 0.14)
                : Util.alpha(Commons.Color.menu.text, 0.07)
              border.width: 1
              border.color: Util.alpha(Commons.Color.menu.text, 0.18)

              Text {
                id: cancelOvText
                anchors.centerIn: parent
                text: "Cancel"
                color: Commons.Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: cancelOvMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.pendingOverride = null
              }
            }

            Rectangle {
              height: Style.space(30)
              width: confirmOvText.implicitWidth + Style.space(24)
              radius: Math.max(4, Style.space(5))
              color: confirmOvMouse.containsMouse
                ? Util.alpha(Commons.Color.warning, 0.28)
                : Util.alpha(Commons.Color.warning, 0.18)
              border.width: 1
              border.color: Util.alpha(Commons.Color.warning, 0.65)

              Text {
                id: confirmOvText
                anchors.centerIn: parent
                text: "Override"
                color: Commons.Color.warning
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.DemiBold
              }

              MouseArea {
                id: confirmOvMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.confirmOverride()
              }
            }
          }
        }
      }
    }
  }
}
