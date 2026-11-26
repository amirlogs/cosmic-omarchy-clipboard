import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ClipboardHistory.js" as ClipboardHistory
import "EditorEngine.js" as EditorEngine
import "VimEngine.js" as VimEngine
import "Keybindings.js" as Keybindings
import "SettingsStore.js" as SettingsStore

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string pluginPath: {
    var envClip = Quickshell.env("OMARCHY_CLIPBOARD_PATH")
    if (envClip && envClip.length > 0) return envClip
    var op = Quickshell.env("OMARCHY_PATH")
    if (op && op.length > 0) return op
    var url = String(Qt.resolvedUrl("."))
    if (url.indexOf("file://") === 0) {
      url = url.substring(7)
    }
    return url.replace(/\/+$/, "")
  }
  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property bool clearConfirmOpen: false
  property var history: []
  property string activeTab: "history"
  property string typeFilter: "all"
  property string activePanel: "list"
  property var pendingUndo: null
  property string toastText: ""
  property bool toastCanUndo: false
  property var editorState: EditorEngine.createState("", "")
  property var vimState: VimEngine.createVimState({ jkExit: root.settings.editor.jkExit })
  property bool vimMode: root.settings.editor.vimMode
  property int editorRevision: 0
  property int displayRevision: 0
  property bool listSearchActive: false
  property bool editorCursorBlinkOn: true
  property bool editorSearchOpen: false
  property string editorSearchQuery: ""
  property bool _syncingEditor: false

  readonly property int pinnedCount: {
    var n = 0
    for (var i = 0; i < root.history.length; i++)
      if (root.history[i] && root.history[i].pinned === true) n++
    return n
  }
  readonly property int historyCount: Math.max(0, root.history.length - root.pinnedCount)

  property string historyPath: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"
  property string captureScript: {
    var f = pluginPath + "/capture.sh"
    return f
  }
  property string pasteFileScript: pluginPath + "/bin/omarchy-clipboard-paste-file"
  property string pasteTextScript: pluginPath + "/bin/omarchy-clipboard-paste-text"
  property string openScript: pluginPath + "/bin/omarchy-clipboard-open"
  property string writeTextScript: pluginPath + "/bin/omarchy-clipboard-write-text"
  property string ocrScript: pluginPath + "/bin/omarchy-clipboard-ocr"
  property string saveImageScript: pluginPath + "/bin/omarchy-clipboard-save-image"
  property string cleanupImagesScript: pluginPath + "/bin/omarchy-clipboard-cleanup-images"
  property int autoCleanupHours: root.settings.clipboard.autoCleanupHours
  property var imageDimensionsMap: ({})
  property int imageMetaRevision: 0
  property string ocrLanguages: root.settings.ocr.languages
  property bool ocrEnabled: root.settings.ocr.enabled
  property bool ocrReopenAfter: false
  property string editorSyncTmpPath: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-editor-sync.tmp"
  property var settings: SettingsStore.defaultSettings()
  property string settingsPath: Quickshell.env("HOME") + "/.config/omarchy-clipboard/settings.json"
  property bool quickSettingsOpen: false
  property bool shortcutsHelpOpen: false
  property string hoverTooltipText: ""
  property real hoverTooltipX: 0
  property real hoverTooltipY: 0
  property var installedOcrLangs: []
  property var keybindings: Keybindings.defaultConfig()
  property string keybindingsPath: Quickshell.env("HOME") + "/.config/omarchy-clipboard/keybindings.json"
  property string shortcutsSyncScript: pluginPath + "/bin/omarchy-clipboard-shortcuts"
  readonly property var qtKeyCodes: ({
    Key_Tab: Qt.Key_Tab,
    Key_Backtab: Qt.Key_Backtab,
    Key_Delete: Qt.Key_Delete,
    Key_Backspace: Qt.Key_Backspace,
    Key_Escape: Qt.Key_Escape,
    Key_Return: Qt.Key_Return,
    Key_Enter: Qt.Key_Enter,
    Key_Space: Qt.Key_Space,
    Key_Left: Qt.Key_Left,
    Key_Right: Qt.Key_Right,
    Key_Up: Qt.Key_Up,
    Key_Down: Qt.Key_Down,
    Key_Home: Qt.Key_Home,
    Key_End: Qt.Key_End,
    Key_PageUp: Qt.Key_PageUp,
    Key_PageDown: Qt.Key_PageDown,
    Key_F1: Qt.Key_F1,
    Key_F3: Qt.Key_F3,
    Key_F12: Qt.Key_F12,
    Key_Comma: Qt.Key_Comma,
    Key_Period: Qt.Key_Period,
    Key_Slash: Qt.Key_Slash,
    Key_Control: Qt.Key_Control,
    Key_Shift: Qt.Key_Shift,
    Key_Alt: Qt.Key_Alt,
    Key_Meta: Qt.Key_Meta
  })
  // Shares the [menu] surface tokens — themes that style the menu also
  // style the clipboard. Selected-row colors composed in the
  // singleton so consumers drop them straight into Rectangle bindings.
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  readonly property int cornerRadius: root.settings.appearance.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(875), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(600), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int historyLimit: root.settings.clipboard.historyLimit

  function applySettings(nextSettings) {
    root.settings = SettingsStore.parseSettings(nextSettings)
    root.vimState.jkExit = root.settings.editor.jkExit
    settingsFile.setText(SettingsStore.serializeSettings(root.settings))
    root.editorRevision++
  }

  function applyKeybindings(nextKb) {
    root.keybindings = Keybindings.parseConfig(nextKb)
    keybindingsFile.setText(Keybindings.serializeConfig(root.keybindings))
    shortcutsSyncProc.running = false
    shortcutsSyncProc.running = true
  }

  function resetAllDefaults() {
    root.applySettings(SettingsStore.defaultSettings())
    root.applyKeybindings(Keybindings.defaultConfig())
    root.showToast("Settings reset to defaults", false)
  }

  function openAdvancedSettings() {
    root.quickSettingsOpen = false
    root.close()
    ocrLangsProc.running = false
    ocrLangsProc.running = true
    settingsWindow.opened = true
  }

  function showHoverTooltip(item, text) {
    if (!item || !text) return
    var pos = item.mapToItem(card, item.width / 2, item.height)
    root.hoverTooltipX = Math.max(root.contentMargin, Math.min(card.width - root.contentMargin - Style.space(220), pos.x - Style.space(80)))
    root.hoverTooltipY = Math.min(card.height - Style.space(34), pos.y + Style.space(6))
    root.hoverTooltipText = text
  }

  function hideHoverTooltip() {
    root.hoverTooltipText = ""
  }

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.activeTab = root.settings.general.defaultTab || "history"
    root.activePanel = "list"
    root.listSearchActive = false
    root.quickSettingsOpen = false
    root.shortcutsHelpOpen = false
    root.hideHoverTooltip()
    root.clearToast()
    root.disarmPointer()
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.commitEditorChanges()
    root.editorSearchOpen = false
    root.editorSearchQuery = ""
    root.cancelClearHistory()
    root.clearToast()
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function startOcr(reopenAfter) {
    if (!root.ocrEnabled) return
    root.ocrReopenAfter = reopenAfter === true
    if (root.opened) {
      root.close()
      root.ocrReopenAfter = true
    }
    ocrOverlay.shown = true
  }

  function switchTab(tab) {
    if (tab !== "all" && tab !== "history" && tab !== "pinned") return
    root.commitEditorChanges()
    root.editorSearchOpen = false
    root.editorSearchQuery = ""
    root.activeTab = tab
    root.activePanel = "list"
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function setTypeFilter(kind) {
    if (kind !== "all" && kind !== "text" && kind !== "image") return
    root.typeFilter = kind
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
  }

  function isEditableActiveRow() {
    var row = displayModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count
      ? displayModel.get(root.selectedIndex)
      : null
    return !!row && !row.previewImage && row.entryType === "text"
  }

  function loadEditorFromActiveRow(forceReset) {
    var row = displayModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count
      ? displayModel.get(root.selectedIndex)
      : null
    if (!row || row.previewImage || row.entryType !== "text") {
      if (root.editorState.entryId !== "" || forceReset) {
        root.editorState = EditorEngine.createState("", "")
        root.editorSearchOpen = false
        root.editorSearchQuery = ""
        root.editorRevision++
        root.syncEditorView()
      }
      return
    }
    if (!forceReset && root.editorState && root.editorState.entryId === row.id) {
      root.syncEditorView()
      return
    }
    var fullEntryText = row.fullText
    for (var i = 0; i < root.history.length; i++) {
      if (root.history[i] && root.history[i].id === row.id && root.history[i].type === "text") {
        fullEntryText = String(root.history[i].text || "")
        break
      }
    }
    root.editorState = EditorEngine.createState(fullEntryText, row.id)
    VimEngine.resetVimState(root.vimState, "normal")
    root.editorSearchOpen = false
    root.editorSearchQuery = ""
    root.editorRevision++
    Qt.callLater(function() {
      root.syncEditorView()
      previewFlickable.contentY = 0
    })
  }

  function syncEditorView() {
    if (!editorTextEdit) return
    root._syncingEditor = true
    var st = root.editorState
    if (editorTextEdit.text !== st.text) editorTextEdit.text = st.text
    var a = Math.max(0, Math.min(st.anchor, editorTextEdit.length))
    var c = Math.max(0, Math.min(st.cursor, editorTextEdit.length))
    if (a !== c) editorTextEdit.select(a, c)
    else editorTextEdit.cursorPosition = c
    root._syncingEditor = false
    root.editorCursorBlinkOn = true
    cursorBlinkTimer.restart()
    root.ensureEditorCursorVisible()
  }

  function ensureEditorCursorVisible() {
    if (!editorTextEdit || !root.isEditableActiveRow()) return
    var rect = editorTextEdit.cursorRectangle
    var margin = Style.space(12)
    if (rect.y < previewFlickable.contentY) {
      previewFlickable.contentY = Math.max(0, rect.y - margin)
    } else if (rect.y + rect.height > previewFlickable.contentY + previewFlickable.height) {
      var maxY = Math.max(0, previewFlickable.contentHeight - previewFlickable.height)
      previewFlickable.contentY = Math.min(maxY, rect.y + rect.height - previewFlickable.height + margin)
    }
  }

  function syncTextToClipboard(text, source) {
    editorSyncFile.setText(String(text || ""))
    writeTextProc.sourceName = source || "editor"
    writeTextProc.running = false
    writeTextProc.running = true
  }

  function copyEditorSelection() {
    if (!EditorEngine.hasSelection(root.editorState)) return false
    var sel = EditorEngine.selectedText(root.editorState)
    root.syncTextToClipboard(sel, "editor-selection")
    root.showToast(Commons.I18n.t("clipboard.selectionCopied", "Selection copied"), false)
    return true
  }

  function commitEditorChanges() {
    editorSaveTimer.stop()
    var st = root.editorState
    if (!st || !st.entryId || !st.dirty) return
    var targetId = st.entryId
    var existing = null
    for (var i = 0; i < root.history.length; i++) {
      if (root.history[i] && root.history[i].id === targetId) {
        existing = root.history[i]
        break
      }
    }
    if (!existing || existing.type !== "text") {
      st.dirty = false
      return
    }
    if (existing.text === st.text) {
      st.dirty = false
      root.editorRevision++
      return
    }
    root.history = ClipboardHistory.updateEntry(root.history, targetId, { text: st.text })
    st.dirty = false
    root.saveHistory()
    root.rebuildDisplay()
    for (var j = 0; j < displayModel.count; j++) {
      if (displayModel.get(j).id === targetId) {
        root.selectedIndex = j
        break
      }
    }
    root.editorRevision++
    root.syncTextToClipboard(st.text, "editor")
  }

  function scheduleEditorCommit(immediate) {
    // Commit edits when leaving the editor, switching entries, or closing
    // rather than rewriting/reordering history mid-typing.
    if (immediate) root.commitEditorChanges()
  }

  function handleEditorKey(event) {
    if (!root.isEditableActiveRow()) {
      if (event.key === Qt.Key_Left && event.modifiers === Qt.NoModifier) {
        root.focusPanel("list")
      } else if (event.key === Qt.Key_Up) {
        root.scrollPreview(-48)
      } else if (event.key === Qt.Key_Down) {
        root.scrollPreview(48)
      } else if (event.key === Qt.Key_PageUp) {
        root.scrollPreview(-Math.max(96, previewFlickable.height * 0.85))
      } else if (event.key === Qt.Key_PageDown) {
        root.scrollPreview(Math.max(96, previewFlickable.height * 0.85))
      } else if (event.key === Qt.Key_Home) {
        root.scrollPreviewToEdge(false)
      } else if (event.key === Qt.Key_End) {
        root.scrollPreviewToEdge(true)
      } else if (event.key === Qt.Key_Delete) {
        if (event.modifiers & Qt.ShiftModifier) root.requestClearHistory()
        else root.removeDisplayIndex(root.selectedIndex)
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (root.cursorActive && (event.modifiers & Qt.AltModifier)) root.openIndex(root.selectedIndex)
        else if (root.cursorActive && (event.modifiers & Qt.ShiftModifier)) root.copyIndex(root.selectedIndex)
        else if (root.cursorActive) root.activateIndex(root.selectedIndex)
      }
      return true
    }

    var ctrl = !!(event.modifiers & Qt.ControlModifier)
    var shift = !!(event.modifiers & Qt.ShiftModifier)
    var alt = !!(event.modifiers & Qt.AltModifier)
    var st = root.editorState
    var combo = Keybindings.qtEventToCombo(event.key, event.modifiers, event.text, root.qtKeyCodes)
    var normalAction = Keybindings.matchAction(root.keybindings, "normal", combo)

    if (root.vimMode) {
      var keyName = ""
      if (event.key === Qt.Key_Escape) keyName = "Escape"
      else if (event.key === Qt.Key_Return) keyName = "Return"
      else if (event.key === Qt.Key_Enter) keyName = "Enter"
      else if (event.key === Qt.Key_Backspace) keyName = "Backspace"
      else if (event.key === Qt.Key_Delete) keyName = "Delete"
      else if (event.key === Qt.Key_Left) keyName = "Left"
      else if (event.key === Qt.Key_Right) keyName = "Right"
      else if (event.key === Qt.Key_Up) keyName = "Up"
      else if (event.key === Qt.Key_Down) keyName = "Down"
      else if (event.key === Qt.Key_Home) keyName = "Home"
      else if (event.key === Qt.Key_End) keyName = "End"

      var vRes = VimEngine.handleKey(root.vimState, st, {
        keyName: keyName,
        text: event.text || "",
        ctrl: ctrl,
        shift: shift,
        alt: alt
      }, EditorEngine)

      if (vRes.yankText) {
        root.syncTextToClipboard(vRes.yankText, "vim-yank")
        root.showToast(Commons.I18n.t("clipboard.selectionCopied", "Selection copied"), false)
      }
      if (vRes.mutated) root.scheduleEditorCommit(false)
      root.editorRevision++
      root.syncEditorView()
      return true
    }

    if (root.editorSearchOpen) {
      if (event.key === Qt.Key_Escape) {
        root.editorSearchOpen = false
        return true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_F3) {
        EditorEngine.nextMatch(st, shift ? -1 : 1)
        root.editorRevision++
        root.syncEditorView()
        return true
      } else if (event.key === Qt.Key_Backspace) {
        root.editorSearchQuery = root.editorSearchQuery.slice(0, -1)
        EditorEngine.setSearch(st, root.editorSearchQuery)
        root.editorRevision++
        root.syncEditorView()
        return true
      } else if (!ctrl && !alt && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
        root.editorSearchQuery += event.text
        EditorEngine.setSearch(st, root.editorSearchQuery)
        root.editorRevision++
        root.syncEditorView()
        return true
      }
      return true
    }

    if (normalAction === "find") {
      root.editorSearchOpen = true
      if (EditorEngine.hasSelection(st)) root.editorSearchQuery = EditorEngine.selectedText(st)
      EditorEngine.setSearch(st, root.editorSearchQuery)
      root.editorRevision++
      root.syncEditorView()
      return true
    } else if (normalAction === "findNext" || normalAction === "findPrev") {
      if (st.searchQuery) {
        EditorEngine.nextMatch(st, normalAction === "findPrev" ? -1 : 1)
        root.editorRevision++
        root.syncEditorView()
      }
      return true
    } else if (normalAction === "copySelection") {
      if (EditorEngine.hasSelection(st)) root.copyEditorSelection()
      else root.copyIndex(root.selectedIndex)
      return true
    } else if (normalAction === "cutSelection") {
      if (EditorEngine.hasSelection(st)) {
        root.copyEditorSelection()
        EditorEngine.deleteBackward(st, false, false)
        root.editorRevision++
        root.syncEditorView()
        root.scheduleEditorCommit(false)
      }
      return true
    } else if (normalAction === "paste") {
      pasteReadProc.running = false
      pasteReadProc.running = true
      return true
    } else if (normalAction === "redo") {
      if (EditorEngine.redo(st)) {
        root.editorRevision++
        root.syncEditorView()
        root.scheduleEditorCommit(true)
      }
      return true
    } else if (normalAction === "undo") {
      if (EditorEngine.undo(st)) {
        root.editorRevision++
        root.syncEditorView()
        root.scheduleEditorCommit(true)
      }
      return true
    } else if (normalAction === "selectAll") {
      EditorEngine.selectAll(st)
      root.editorRevision++
      root.syncEditorView()
      return true
    } else if (event.key === Qt.Key_Left) {
      if (ctrl) EditorEngine.moveWordLeft(st, shift)
      else EditorEngine.moveLeft(st, shift)
      root.editorRevision++
      root.syncEditorView()
      return true
    } else if (event.key === Qt.Key_Right) {
      if (ctrl) EditorEngine.moveWordRight(st, shift)
      else EditorEngine.moveRight(st, shift)
      root.editorRevision++
      root.syncEditorView()
      return true
    } else if (event.key === Qt.Key_Up) {
      EditorEngine.moveUp(st, shift)
      root.editorRevision++
      root.syncEditorView()
      return true
    } else if (event.key === Qt.Key_Down) {
      EditorEngine.moveDown(st, shift)
      root.editorRevision++
      root.syncEditorView()
      return true
    } else if (event.key === Qt.Key_Home) {
      if (ctrl) EditorEngine.moveDocStart(st, shift)
      else EditorEngine.moveLineStart(st, shift)
      root.editorRevision++
      root.syncEditorView()
      return true
    } else if (event.key === Qt.Key_End) {
      if (ctrl) EditorEngine.moveDocEnd(st, shift)
      else EditorEngine.moveLineEnd(st, shift)
      root.editorRevision++
      root.syncEditorView()
      return true
    } else if (event.key === Qt.Key_PageUp) {
      root.scrollPreview(-Math.max(96, previewFlickable.height * 0.85))
      return true
    } else if (event.key === Qt.Key_PageDown) {
      root.scrollPreview(Math.max(96, previewFlickable.height * 0.85))
      return true
    } else if (event.key === Qt.Key_Backspace) {
      EditorEngine.deleteBackward(st, ctrl, !ctrl)
      root.editorRevision++
      root.syncEditorView()
      root.scheduleEditorCommit(false)
      return true
    } else if (event.key === Qt.Key_Delete) {
      EditorEngine.deleteForward(st, ctrl, !ctrl)
      root.editorRevision++
      root.syncEditorView()
      root.scheduleEditorCommit(false)
      return true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (alt) {
        root.openIndex(root.selectedIndex)
      } else if (ctrl) {
        root.commitEditorChanges()
        root.activateIndex(root.selectedIndex)
      } else {
        EditorEngine.insertText(st, "\n", false)
        root.editorRevision++
        root.syncEditorView()
        root.scheduleEditorCommit(false)
      }
      return true
    } else if (!ctrl && !alt && event.text && event.text.length > 0) {
      var code = event.text.charCodeAt(0)
      if (code >= 32 && code !== 127) {
        EditorEngine.insertText(st, event.text, true)
        root.editorRevision++
        root.syncEditorView()
        root.scheduleEditorCommit(false)
        return true
      }
    }

    return true
  }

  function focusPanel(panelName) {
    if (panelName !== "list" && panelName !== "preview") return
    if (panelName === "preview" && displayModel.count === 0) return
    root.activePanel = panelName
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function togglePanelFocus() {
    if (root.activePanel === "list") {
      if (displayModel.count > 0) root.focusPanel("preview")
    } else {
      root.focusPanel("list")
    }
  }

  function scrollPreview(deltaY) {
    var maxY = Math.max(0, previewFlickable.contentHeight - previewFlickable.height)
    previewFlickable.contentY = Math.max(0, Math.min(maxY, previewFlickable.contentY + deltaY))
  }

  function scrollPreviewToEdge(toBottom) {
    var maxY = Math.max(0, previewFlickable.contentHeight - previewFlickable.height)
    previewFlickable.contentY = toBottom ? maxY : 0
  }

  function showToast(message, canUndo) {
    root.toastText = message
    root.toastCanUndo = canUndo === true
    toastTimer.restart()
  }

  function clearToast() {
    root.toastText = ""
    root.toastCanUndo = false
    root.pendingUndo = null
    toastTimer.stop()
  }

  function undoDelete() {
    var pending = root.pendingUndo
    if (!pending || !pending.entry) {
      root.clearToast()
      return
    }

    // If the same content was copied again after the deletion, keep the new
    // entry instead of restoring a duplicate.
    var key = ClipboardHistory.entryKey(pending.entry)
    var alreadyThere = false
    for (var i = 0; i < root.history.length; i++) {
      if (ClipboardHistory.entryKey(root.history[i]) === key) { alreadyThere = true; break }
    }
    if (!alreadyThere)
      root.history = ClipboardHistory.restoreEntry(root.history, pending.entry, pending.index)
    root.saveHistory()

    var targetTab = pending.entry.pinned === true ? "pinned" : "history"
    if (root.activeTab !== targetTab) {
      root.activeTab = targetTab
      root.selectedIndex = 0
    }
    root.rebuildDisplay()
    for (var j = 0; j < displayModel.count; j++) {
      if (displayModel.get(j).id === pending.entry.id) { root.selectedIndex = j; break }
    }
    root.cursorActive = displayModel.count > 0
    root.disarmPointer()
    root.clearToast()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function normalizeEntry(value) {
    return ClipboardHistory.normalizeEntry(value)
  }

  function entryKey(entry) {
    return ClipboardHistory.entryKey(entry)
  }

  function loadHistory(raw) {
    var parsed = ClipboardHistory.parseHistory(raw)
    root.history = parsed.entries
    // Upgrade legacy entries once, then the file is a no-op on the next load.
    if (parsed.migrated) Qt.callLater(root.saveHistory)
    if (root.opened) root.rebuildDisplay()
  }

  function saveHistory() {
    if (root.autoCleanupHours > 0) {
      root.history = ClipboardHistory.pruneByAge(root.history, root.autoCleanupHours)
    }
    // Pinned entries are kept outside the unpinned limit by serialize().
    historyFile.setText(ClipboardHistory.serialize(root.history, root.historyLimit))
  }

  function pruneOlderThanHours(hours) {
    root.history = ClipboardHistory.pruneByAge(root.history, hours)
    root.saveHistory()
    root.rebuildDisplay()
    cleanupImagesProc.running = false
    cleanupImagesProc.running = true
    root.showToast("Cleaned old unpinned entries", false)
  }

  function addClipboardEntry(entry) {
    var normalized = ClipboardHistory.normalizeEntry(entry)
    if (!normalized) return

    root.history = ClipboardHistory.addEntry(root.history, normalized, root.historyLimit)
    root.saveHistory()
    if (root.opened) root.rebuildDisplay()
  }

  function addClipboardJson(line) {
    root.addClipboardEntry(ClipboardHistory.parseEntryJson(line))
  }

  function requestClearHistory() {
    if (root.historyCount === 0) return
    clearConfirm.selectedIndex = 1
    root.clearConfirmOpen = true
  }

  function cancelClearHistory() {
    root.clearConfirmOpen = false
    root.disarmPointer()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmClearHistory() {
    // Pinned entries survive "clear history"; only an explicit "delete
    // everything" action would pass true.
    root.history = ClipboardHistory.clearHistory(root.history)
    root.pendingUndo = null
    root.saveHistory()
    root.selectedIndex = 0
    root.cursorActive = false
    root.disarmPointer()
    root.clearConfirmOpen = false
    root.rebuildDisplay()
    root.showToast(Commons.I18n.t("clipboard.historyCleared", "History cleared"), false)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function removeDisplayIndex(index) {
    if (index < 0 || index >= displayModel.count) return

    var row = displayModel.get(index)
    var removed = ClipboardHistory.removeEntryById(root.history, row.id)
    if (!removed.removed) return
    root.history = removed.history
    root.pendingUndo = { entry: removed.removed, index: removed.index }
    root.saveHistory()

    if (displayModel.count <= 1) {
      root.selectedIndex = 0
      root.cursorActive = false
      root.activePanel = "list"
    } else if (root.selectedIndex >= displayModel.count - 1) {
      root.selectedIndex = displayModel.count - 2
    }

    root.disarmPointer()
    root.rebuildDisplay()
    root.showToast(Commons.I18n.t("clipboard.deleted", "Entry deleted"), true)
  }

  function togglePinIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    var wasPinned = row.pinned === true
    root.history = ClipboardHistory.setPinned(root.history, row.id, !wasPinned)
    root.saveHistory()
    root.rebuildDisplay()
    if (displayModel.count === 0) root.cursorActive = false
    root.showToast(wasPinned
      ? Commons.I18n.t("clipboard.unpinned", "Unpinned")
      : Commons.I18n.t("clipboard.pinned", "Pinned"), false)
  }

  onSelectedIndexChanged: {
    root.commitEditorChanges()
    root.loadEditorFromActiveRow(false)
    root.probeActiveImageDimensions()
  }

  function probeActiveImageDimensions() {
    var row = previewPanel.activeRow
    if (!row || !row.previewImage || !row.path) return
    if (root.imageDimensionsMap[row.path]) return
    imageDimsProc.targetPath = row.path
    imageDimsProc.running = false
    imageDimsProc.running = true
  }

  function saveSelectedImage() {
    var row = previewPanel.activeRow
    if (!row || !row.path) return
    saveImageProc.targetPath = row.path
    saveImageProc.running = false
    saveImageProc.running = true
  }

  function rebuildDisplay() {
    var rows = ClipboardHistory.displayRows(root.history, root.filterText, 50, Commons.I18n.t, Commons.I18n.tn, Commons.I18n.formatNumber, root.activeTab, root.typeFilter)

    displayModel.clear()
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      displayModel.append({
        id: row.id,
        pinned: row.pinned,
        entryType: row.entryType,
        fullText: row.fullText,
        previewText: row.previewText,
        previewImage: row.previewImage ? Util.fileUrl(row.previewImage) : "",
        path: row.path,
        mime: row.mime,
        bytes: row.bytes || 0,
        capturedAt: row.capturedAt || "",
        historyIndex: row.index
      })
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0

    root.displayRevision++
    root.loadEditorFromActiveRow(false)
    root.probeActiveImageDimensions()

    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  // Preview text is composed imperatively, so rebuild it when the
  // language (and with it the string catalog) changes under an open panel.
  Connections {
    target: Commons.I18n
    function onStringsChanged() { if (root.opened) root.rebuildDisplay() }
  }

  function select(delta) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else if (root.settings.navigation.wrapSelection) {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    } else {
      selectedIndex = Math.max(0, Math.min(displayModel.count - 1, selectedIndex + delta))
    }
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectAbsolute(index) {
    if (displayModel.count === 0) return
    root.disarmPointer()
    root.cursorActive = true
    root.selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.disarmPointer()
    root.rebuildDisplay()
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.applySelected(row)
  }

  function copyIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.copySelected(row)
  }

  function openIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.openSelected(row)
  }

  function applySelected(row) {
    if (!row) return
    root.opened = false
    if (row.entryType === "image") {
      Quickshell.execDetached([root.pasteFileScript, row.mime, row.path])
    } else if (row.fullText) {
      Quickshell.execDetached([root.pasteTextScript, "--shift-insert", "--history-index", String(row.historyIndex)])
    }
  }

  function copySelected(row) {
    if (!row) return
    if (root.settings.general.closeOnCopy) root.opened = false
    else root.showToast("Copied to clipboard", false)
    if (row.entryType === "image") {
      Quickshell.execDetached([root.pasteFileScript, "--copy-only", row.mime, row.path])
    } else if (row.fullText) {
      Quickshell.execDetached([root.pasteTextScript, "--copy-only", "--history-index", String(row.historyIndex)])
    }
  }

  function openSelected(row) {
    if (!row) return
    root.opened = false
    Quickshell.execDetached([root.openScript, "--history-index", String(row.historyIndex)])
  }

  // Start the watchers directly. Their pdeathsig makes the kernel kill them
  // when this shell exits, and the launcher's single-instance lock keeps a
  // second shell from starting duplicate watchers, so no pkill sweep is
  // needed (and the old sweep killed a healthy sibling instance).
  Component.onCompleted: {
    ensureConfigDirProc.running = true
    currentProc.running = true
    textWatchProc.running = true
    imageWatchProc.running = true
  }

  Process {
    id: ensureConfigDirProc
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.config/omarchy-clipboard"]
  }

  ListModel { id: displayModel }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  FileView {
    id: historyFile
    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
    onFileChanged: reload()
  }

  // The watchers are started from Component.onCompleted above. Keep the
  // restart timer so a watcher that dies is brought back.
  Process {
    id: currentProc
    command: [root.captureScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.addClipboardJson(text)
    }
  }

  Process {
    id: textWatchProc
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch", root.captureScript, "text"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser {
      onRead: function(data) { root.addClipboardJson(data) }
    }
  }

  Process {
    id: imageWatchProc
    command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image/png", "--watch", root.captureScript, "image/png"]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser {
      onRead: function(data) { root.addClipboardJson(data) }
    }
  }

  // A watcher that dies takes clipboard history with it, silently: copying still
  // works, the picker still opens, and the old entries are all still there, so
  // nothing recorded until the next shell reload. Bring it back instead.
  Timer {
    id: watchRestartTimer
    interval: 1000
    repeat: false
    onTriggered: {
      if (!textWatchProc.running) textWatchProc.running = true
      if (!imageWatchProc.running) imageWatchProc.running = true
    }
  }

  Timer {
    id: toastTimer
    interval: 4500
    repeat: false
    onTriggered: root.clearToast()
  }

  Timer {
    id: editorSaveTimer
    interval: 350
    repeat: false
    onTriggered: root.commitEditorChanges()
  }

  Timer {
    id: cursorBlinkTimer
    interval: 530
    repeat: true
    running: root.opened && root.activePanel === "preview" && root.isEditableActiveRow()
    onTriggered: root.editorCursorBlinkOn = !root.editorCursorBlinkOn
  }

  FileView {
    id: editorSyncFile
    path: root.editorSyncTmpPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
  }

  FileView {
    id: keybindingsFile
    path: root.keybindingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.keybindings = Keybindings.parseConfig(text())
    onLoadFailed: root.keybindings = Keybindings.defaultConfig()
    onFileChanged: reload()
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.settings = SettingsStore.parseSettings(text())
      root.vimState.jkExit = root.settings.editor.jkExit
    }
    onLoadFailed: root.settings = SettingsStore.defaultSettings()
    onFileChanged: reload()
  }

  Process {
    id: ocrLangsProc
    command: [root.ocrScript, "--check-langs"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split(/\r?\n/).map(function(s) { return s.trim() }).filter(Boolean)
        root.installedOcrLangs = lines
      }
    }
  }

  Process {
    id: shortcutsSyncProc
    command: [root.shortcutsSyncScript]
  }

  SettingsWindow {
    id: settingsWindow
    settings: root.settings
    keybindings: root.keybindings
    installedOcrLangs: root.installedOcrLangs
    onUpdateSettings: function(next) { root.applySettings(next) }
    onUpdateKeybindings: function(next) { root.applyKeybindings(next) }
    onResetDefaults: root.resetAllDefaults()
    onManualCleanup: function(hours) { root.pruneOlderThanHours(hours) }
    onCleanupOrphanImages: {
      cleanupImagesProc.running = false
      cleanupImagesProc.running = true
      root.showToast("Cleaned orphan images", false)
    }
  }

  Process {
    id: writeTextProc
    property string sourceName: "editor"
    command: [root.writeTextScript, "--suppress", "--source", sourceName, "--file", root.editorSyncTmpPath]
  }

  Process {
    id: pasteReadProc
    command: ["wl-paste", "--type", "text", "--no-newline"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || !root.isEditableActiveRow()) return
        EditorEngine.insertText(root.editorState, text, false)
        root.editorRevision++
        root.syncEditorView()
        root.scheduleEditorCommit(false)
      }
    }
  }

  Process {
    id: ocrProc
    property string regionSpec: ""
    property string errOutput: ""
    command: [root.ocrScript, "--langs", root.ocrLanguages, "--region", regionSpec]
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: ocrProc.errOutput = String(text || "").trim()
    }
    onExited: function(exitCode) {
      if (root.ocrReopenAfter && !root.opened) root.open("{}")
      if (exitCode === 0) {
        root.showToast(Commons.I18n.t("clipboard.ocrSuccess", "Text extracted to clipboard"), false)
      } else if (exitCode !== 2) {
        var msg = ocrProc.errOutput || Commons.I18n.t("clipboard.ocrFailed", "OCR failed")
        root.showToast(msg, false)
      }
      ocrProc.errOutput = ""
    }
  }

  OcrOverlay {
    id: ocrOverlay
    onRegionSelected: function(region) {
      ocrProc.regionSpec = region
      ocrProc.errOutput = ""
      ocrProc.running = false
      ocrProc.running = true
    }
    onCanceled: {
      if (root.ocrReopenAfter && !root.opened) root.open("{}")
    }
  }

  Process {
    id: imageDimsProc
    property string targetPath: ""
    command: ["magick", "identify", "-format", "%wx%h", targetPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var dims = String(text || "").trim()
        if (dims && imageDimsProc.targetPath) {
          var next = Object.assign({}, root.imageDimensionsMap)
          next[imageDimsProc.targetPath] = dims
          root.imageDimensionsMap = next
          root.imageMetaRevision++
        }
      }
    }
  }

  Process {
    id: saveImageProc
    property string targetPath: ""
    property string savedOut: ""
    command: [root.saveImageScript, targetPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: saveImageProc.savedOut = String(text || "").trim()
    }
    onExited: function(exitCode) {
      if (exitCode === 0 && saveImageProc.savedOut) {
        root.showToast("Saved: " + ClipboardHistory.fileName(saveImageProc.savedOut), false)
      } else {
        root.showToast("Failed to save image", false)
      }
      saveImageProc.savedOut = ""
    }
  }

  Process {
    id: cleanupImagesProc
    command: [root.cleanupImagesScript]
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-clipboard"

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: Util.alpha(root.background, root.settings.appearance.backgroundOpacity)
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.clearConfirmOpen ? 20 : 0
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.clearConfirmOpen) {
            if (clearConfirm.handleKey(event)) event.accepted = true
            return
          }

          var combo = Keybindings.qtEventToCombo(event.key, event.modifiers, event.text, root.qtKeyCodes)
          var appAction = Keybindings.matchAction(root.keybindings, "app", combo)

          if (event.key === Qt.Key_Escape) {
            if (root.activePanel === "preview" && root.vimMode && root.vimState.mode !== "normal") {
              root.handleEditorKey(event)
            } else if (root.shortcutsHelpOpen) {
              root.shortcutsHelpOpen = false
            } else if (root.quickSettingsOpen) {
              root.quickSettingsOpen = false
            } else if (root.activePanel === "preview" && root.editorSearchOpen) {
              root.editorSearchOpen = false
            } else if (root.activePanel === "preview") {
              root.commitEditorChanges()
              root.focusPanel("list")
            } else if (root.filterText) {
              root.setFilter("")
              root.listSearchActive = false
            } else if (root.listSearchActive) {
              root.listSearchActive = false
            } else {
              root.close()
            }
            event.accepted = true
          } else if (event.key === Qt.Key_F1 || (event.text === "?" && root.activePanel === "list" && !root.listSearchActive)) {
            root.quickSettingsOpen = false
            root.shortcutsHelpOpen = !root.shortcutsHelpOpen
            event.accepted = true
          } else if (appAction === "switchTab") {
            root.switchTab(root.activeTab === "history" ? "pinned" : "history")
            event.accepted = true
          } else if (appAction === "switchPanel") {
            if (root.activePanel === "preview") root.commitEditorChanges()
            root.togglePanelFocus()
            event.accepted = true
          } else if (appAction === "tabHistory") {
            root.switchTab("history")
            event.accepted = true
          } else if (appAction === "tabPinned") {
            root.switchTab("pinned")
            event.accepted = true
          } else if (appAction === "togglePin") {
            if (root.cursorActive) root.togglePinIndex(root.selectedIndex)
            event.accepted = true
          } else if (appAction === "startOcr") {
            root.startOcr(true)
            event.accepted = true
          } else if (appAction === "openSettings") {
            root.openAdvancedSettings()
            event.accepted = true
          } else if (root.activePanel === "preview") {
            if (root.handleEditorKey(event)) event.accepted = true
          } else if (appAction === "undoDelete") {
            if (root.pendingUndo) root.undoDelete()
            event.accepted = true
          } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_J) {
            root.select(1)
            event.accepted = true
          } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K) {
            root.select(-1)
            event.accepted = true
          } else if (root.vimMode && !root.listSearchActive && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            if (event.text === "j") {
              root.select(1)
              event.accepted = true
            } else if (event.text === "k") {
              root.select(-1)
              event.accepted = true
            } else if (event.text === "g") {
              root.selectAbsolute(0)
              event.accepted = true
            } else if (event.text === "G") {
              root.selectAbsolute(displayModel.count - 1)
              event.accepted = true
            } else if (event.text === "l" && displayModel.count > 0) {
              root.focusPanel("preview")
              event.accepted = true
            } else if (event.text === "/" || event.text === "i") {
              root.listSearchActive = true
              event.accepted = true
            } else if (event.text === "p" && root.cursorActive) {
              root.togglePinIndex(root.selectedIndex)
              event.accepted = true
            } else if (event.text === "d" && root.cursorActive) {
              root.removeDisplayIndex(root.selectedIndex)
              event.accepted = true
            }
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (appAction === "clearHistory") {
            root.requestClearHistory()
            event.accepted = true
          } else if (appAction === "deleteEntry") {
            root.removeDisplayIndex(root.selectedIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_Right && event.modifiers === Qt.NoModifier && !root.filterText && displayModel.count > 0) {
            root.focusPanel("preview")
            event.accepted = true
          } else if (event.key === Qt.Key_Left && event.modifiers === Qt.NoModifier && !root.filterText) {
            var order = ["all", "history", "pinned"]
            var idx = order.indexOf(root.activeTab)
            root.switchTab(order[(idx + order.length - 1) % order.length])
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.select(-6)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.select(6)
            event.accepted = true
          } else if (event.key === Qt.Key_Home) {
            root.selectAbsolute(0)
            event.accepted = true
          } else if (event.key === Qt.Key_End) {
            root.selectAbsolute(displayModel.count - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive && (event.modifiers & Qt.AltModifier)) root.openIndex(root.selectedIndex)
            else if (root.cursorActive && (event.modifiers & Qt.ShiftModifier)) root.copyIndex(root.selectedIndex)
            else if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (displayModel.count > 0) root.cursorActive = true
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: clearConfirm

          anchors.fill: parent
          opened: root.clearConfirmOpen
          z: 10
          message: Commons.I18n.t("clipboard.deleteHistory")
          confirmText: Commons.I18n.t("common.delete")
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: root.cornerRadius
          onCanceled: root.cancelClearHistory()
          onConfirmed: root.confirmClearHistory()
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          Row {
            anchors.fill: parent
            spacing: Style.space(12)

            Text {
              textFormat: Text.PlainText
              width: parent.width - tabBar.width - parent.spacing
              anchors.verticalCenter: parent.verticalCenter
              text: root.filterText || Commons.I18n.t("clipboard.search")
              color: root.foreground
              opacity: root.filterText ? 1 : 0.58
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideRight
            }

            Row {
              id: tabBar
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Repeater {
                model: [
                  { key: "all", label: "All", count: root.history.length },
                  { key: "history", label: Commons.I18n.t("clipboard.history", "History"), count: root.historyCount },
                  { key: "pinned", label: Commons.I18n.t("clipboard.pinned", "Pinned"), count: root.pinnedCount }
                ]

                Rectangle {
                  required property var modelData
                  readonly property bool active: root.activeTab === modelData.key

                  width: tabLabel.implicitWidth + Style.space(18)
                  height: Math.max(Style.space(28), root.headerHeight - Style.space(4))
                  radius: root.cornerRadius
                  color: active ? root.selectedBackground : "transparent"
                  border.width: active ? Style.normalBorderWidth : 0
                  border.color: active ? Util.alpha(root.border, 0.35) : "transparent"

                  Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.count > 0 ? (modelData.label + " (" + modelData.count + ")") : modelData.label
                    color: active ? root.selectedText : root.foreground
                    opacity: active ? 1.0 : 0.65
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.weight: active ? Font.DemiBold : Font.Normal
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchTab(modelData.key)
                  }
                }
              }

              Rectangle {
                id: ocrHeaderBtn
                visible: root.ocrEnabled
                width: Math.max(Style.space(34), root.headerHeight - Style.space(2))
                height: Math.max(Style.space(34), root.headerHeight - Style.space(2))
                radius: root.cornerRadius
                color: ocrBtnMouse.containsMouse ? root.selectedBackground : "transparent"
                border.width: ocrBtnMouse.containsMouse ? Style.normalBorderWidth : 0
                border.color: Util.alpha(root.border, 0.35)

                Text {
                  anchors.centerIn: parent
                  text: "󰈭"
                  color: ocrBtnMouse.containsMouse ? root.selectedText : root.foreground
                  opacity: ocrBtnMouse.containsMouse ? 1.0 : 0.8
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(18)
                }

                MouseArea {
                  id: ocrBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.showHoverTooltip(ocrHeaderBtn, "Screen OCR (" + (root.keybindings.app.startOcr || "Ctrl+O") + ")")
                  onExited: root.hideHoverTooltip()
                  onClicked: {
                    root.hideHoverTooltip()
                    root.startOcr(true)
                  }
                }
              }

              Rectangle {
                id: settingsHeaderBtn
                width: Math.max(Style.space(34), root.headerHeight - Style.space(2))
                height: Math.max(Style.space(34), root.headerHeight - Style.space(2))
                radius: root.cornerRadius
                color: (root.quickSettingsOpen || settingsBtnMouse.containsMouse) ? root.selectedBackground : "transparent"
                border.width: (root.quickSettingsOpen || settingsBtnMouse.containsMouse) ? Style.normalBorderWidth : 0
                border.color: Util.alpha(root.border, 0.35)

                Text {
                  anchors.centerIn: parent
                  text: "󰒓"
                  color: (root.quickSettingsOpen || settingsBtnMouse.containsMouse) ? root.selectedText : root.foreground
                  opacity: (root.quickSettingsOpen || settingsBtnMouse.containsMouse) ? 1.0 : 0.8
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(18)
                }

                MouseArea {
                  id: settingsBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.showHoverTooltip(settingsHeaderBtn, "Quick Settings (" + (root.keybindings.app.openSettings || "Ctrl+,") + ")")
                  onExited: root.hideHoverTooltip()
                  onClicked: {
                    root.shortcutsHelpOpen = false
                    root.quickSettingsOpen = !root.quickSettingsOpen
                  }
                }
              }

              Rectangle {
                id: helpHeaderBtn
                width: Math.max(Style.space(34), root.headerHeight - Style.space(2))
                height: Math.max(Style.space(34), root.headerHeight - Style.space(2))
                radius: root.cornerRadius
                color: (root.shortcutsHelpOpen || helpBtnMouse.containsMouse) ? root.selectedBackground : "transparent"
                border.width: (root.shortcutsHelpOpen || helpBtnMouse.containsMouse) ? Style.normalBorderWidth : 0
                border.color: Util.alpha(root.border, 0.35)

                Text {
                  anchors.centerIn: parent
                  text: "?"
                  color: (root.shortcutsHelpOpen || helpBtnMouse.containsMouse) ? root.selectedText : root.foreground
                  opacity: (root.shortcutsHelpOpen || helpBtnMouse.containsMouse) ? 1.0 : 0.85
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(17)
                  font.weight: Font.DemiBold
                }

                MouseArea {
                  id: helpBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.showHoverTooltip(helpHeaderBtn, "Active Shortcuts (? or F1)")
                  onExited: root.hideHoverTooltip()
                  onClicked: {
                    root.quickSettingsOpen = false
                    root.shortcutsHelpOpen = !root.shortcutsHelpOpen
                  }
                }
              }
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing

          Row {
            id: typeFilterRow
            anchors.left: parent.left
            anchors.top: parent.top
            height: Style.space(24)
            spacing: Style.space(6)
            z: 2

            Repeater {
              model: [
                { key: "all", label: "All types" },
                { key: "text", label: "Text" },
                { key: "image", label: "Images" }
              ]

              Rectangle {
                required property var modelData
                readonly property bool active: root.typeFilter === modelData.key
                width: typeLabel.implicitWidth + Style.space(14)
                height: Style.space(22)
                radius: Math.max(4, root.cornerRadius - 4)
                color: active ? root.selectedBackground : Util.alpha(root.foreground, 0.05)

                Text {
                  id: typeLabel
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: active ? root.selectedText : root.foreground
                  opacity: active ? 1.0 : 0.65
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setTypeFilter(modelData.key)
                }
              }
            }
          }

          Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: typeFilterRow.bottom
            anchors.topMargin: Style.space(6)
            anchors.bottom: parent.bottom
            spacing: 0

            Item {
              width: parent.width / 2
              height: parent.height
              clip: true

              ListView {
                id: resultList
                anchors.fill: parent
                anchors.rightMargin: root.contentMargin
                model: displayModel
                clip: true
                spacing: Style.space(4)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                  id: row
                  required property int index
                  required property string id
                  required property bool pinned
                  required property string entryType
                  required property string previewText
                  required property string fullText
                  required property string previewImage

                  readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex
                  readonly property bool showActions: hasCursor || rowMouse.containsMouse || row.pinned

                  width: ListView.view.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: hasCursor ? root.selectedBackground : "transparent"

                  MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: function(mouse) {
                      root.selectFromPointer(row.index, row, mouse)
                    }
                    onClicked: {
                      root.cursorActive = true
                      root.selectedIndex = row.index
                      root.activateIndex(row.index)
                    }
                  }

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(10)
                    anchors.topMargin: Style.space(8)
                    anchors.bottomMargin: Style.space(8)
                    spacing: Style.space(10)

                    SizedImage {
                      visible: row.previewImage.length > 0
                      width: visible ? parent.height : 0
                      height: parent.height
                      url: row.previewImage
                      asynchronous: true
                      smooth: true
                    }

                    Text {
                      textFormat: root.filterText ? Text.StyledText : Text.PlainText
                      width: parent.width - (row.previewImage.length > 0 ? parent.height + parent.spacing : 0) - (rowActions.visible ? rowActions.width + parent.spacing : 0)
                      height: parent.height
                      text: root.filterText
                        ? ClipboardHistory.highlightText(row.previewText, root.filterText, root.selectedText)
                        : row.previewText
                      color: row.hasCursor ? root.selectedText : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      opacity: row.entryType === "image" || row.entryType === "file" ? 0.72 : 1.0
                      elide: Text.ElideRight
                      wrapMode: Text.NoWrap
                      verticalAlignment: Text.AlignVCenter
                    }

                    Row {
                      id: rowActions
                      visible: row.showActions
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)

                      Rectangle {
                        id: pinActionBtn
                        width: Style.space(30)
                        height: Style.space(30)
                        radius: Math.max(4, root.cornerRadius - 4)
                        color: pinActionMouse.containsMouse ? Util.alpha(root.foreground, 0.14) : "transparent"

                        Text {
                          anchors.centerIn: parent
                          text: row.pinned ? "󰐃" : "󰐄"
                          color: row.pinned ? root.selectedText : root.foreground
                          opacity: row.pinned ? 1.0 : 0.78
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(17)
                        }

                        MouseArea {
                          id: pinActionMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onEntered: root.showHoverTooltip(pinActionBtn, (row.pinned ? "Unpin" : "Pin") + " (" + (root.keybindings.app.togglePin || "Ctrl+P") + ")")
                          onExited: root.hideHoverTooltip()
                          onClicked: function(mouse) {
                            mouse.accepted = true
                            root.hideHoverTooltip()
                            root.cursorActive = true
                            root.selectedIndex = row.index
                            root.togglePinIndex(row.index)
                          }
                        }
                      }

                      Rectangle {
                        id: deleteActionBtn
                        visible: row.hasCursor || rowMouse.containsMouse
                        width: Style.space(30)
                        height: Style.space(30)
                        radius: Math.max(4, root.cornerRadius - 4)
                        color: deleteActionMouse.containsMouse ? Util.alpha(root.foreground, 0.14) : "transparent"

                        Text {
                          anchors.centerIn: parent
                          text: "󰆴"
                          color: root.foreground
                          opacity: 0.78
                          font.family: root.fontFamily
                          font.pixelSize: Style.space(17)
                        }

                        MouseArea {
                          id: deleteActionMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onEntered: root.showHoverTooltip(deleteActionBtn, "Delete (" + (root.keybindings.app.deleteEntry || "Delete") + ")")
                          onExited: root.hideHoverTooltip()
                          onClicked: function(mouse) {
                            mouse.accepted = true
                            root.hideHoverTooltip()
                            root.cursorActive = true
                            root.selectedIndex = row.index
                            root.removeDisplayIndex(row.index)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            Item {
              id: previewPanel
              width: parent.width / 2
              height: parent.height
              clip: true

              property var activeRow: {
                var _rev = root.displayRevision
                return displayModel.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < displayModel.count
                  ? displayModel.get(root.selectedIndex)
                  : null
              }
              readonly property bool panelFocused: root.activePanel === "preview"
              readonly property bool isTextEditable: !!activeRow && !activeRow.previewImage && activeRow.entryType === "text"

              Rectangle {
                visible: displayModel.count > 0
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: previewPanel.panelFocused ? Math.max(2, Style.normalBorderWidth * 2) : Style.normalBorderWidth
                color: previewPanel.panelFocused ? Util.alpha(root.selectedText, 0.75) : Util.alpha(root.border, 0.28)
              }

              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: true
                onPressed: function(mouse) {
                  root.focusPanel("preview")
                  mouse.accepted = false
                }
              }

              Rectangle {
                id: editorFindBar
                visible: root.editorSearchOpen && previewPanel.isTextEditable
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: root.contentMargin
                height: visible ? Style.space(30) : 0
                radius: Math.max(4, root.cornerRadius - 4)
                color: Util.alpha(root.foreground, 0.08)
                border.width: Style.normalBorderWidth
                border.color: Util.alpha(root.border, 0.35)
                z: 5

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(8)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: root.editorSearchQuery || Commons.I18n.t("clipboard.findInEntry", "Find in entry…")
                    width: parent.width - findCountLabel.width - parent.spacing
                    color: root.foreground
                    opacity: root.editorSearchQuery ? 1.0 : 0.55
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }

                  Text {
                    id: findCountLabel
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: {
                      var _rev = root.editorRevision
                      var st = root.editorState
                      if (!root.editorSearchQuery) return ""
                      if (!st || !st.searchMatches || st.searchMatches.length === 0) return "0/0"
                      return String(st.searchIndex + 1) + "/" + String(st.searchMatches.length)
                    }
                    color: root.selectedText
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }
              }

              Flickable {
                id: previewFlickable
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: editorFindBar.visible ? editorFindBar.bottom : parent.top
                anchors.bottom: editorStatusBar.visible ? editorStatusBar.top : (imageStatusBar.visible ? imageStatusBar.top : parent.bottom)
                anchors.leftMargin: root.contentMargin
                anchors.rightMargin: Style.space(8)
                anchors.topMargin: editorFindBar.visible ? Style.space(6) : 0
                anchors.bottomMargin: (editorStatusBar.visible || imageStatusBar.visible) ? Style.space(6) : 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: previewPanel.isTextEditable
                  ? editorTextEdit.implicitHeight
                  : (previewPanel.activeRow && !previewPanel.activeRow.previewImage
                    ? previewTextItem.implicitHeight
                    : height)

                TextEdit {
                  id: editorTextEdit
                  visible: previewPanel.isTextEditable
                  width: previewFlickable.width
                  height: Math.max(previewFlickable.height, implicitHeight)
                  textFormat: TextEdit.PlainText
                  readOnly: true
                  activeFocusOnPress: false
                  selectByMouse: true
                  cursorVisible: false
                  wrapMode: TextEdit.WrapAnywhere
                  color: root.foreground
                  selectionColor: root.selectedBackground
                  selectedTextColor: root.selectedText
                  font.family: root.fontFamily
                  font.pixelSize: root.settings.editor.fontSize
                  verticalAlignment: TextEdit.AlignTop

                  Rectangle {
                    id: editorCustomCursor
                    readonly property string styleMode: root.settings.editor.cursorStyle || "auto"
                    readonly property bool isBlock: styleMode === "block" || (styleMode === "auto" && root.vimMode && (!root.vimState || root.vimState.mode !== "insert"))
                    visible: previewPanel.panelFocused && previewPanel.isTextEditable && (isBlock || root.editorCursorBlinkOn)
                    x: editorTextEdit.cursorRectangle.x
                    y: editorTextEdit.cursorRectangle.y
                    width: isBlock ? Math.max(Style.space(9), root.settings.editor.fontSize * 0.6) : Math.max(2, Style.space(2))
                    height: Math.max(root.settings.editor.fontSize + 2, editorTextEdit.cursorRectangle.height)
                    color: root.selectedText
                    opacity: isBlock ? (root.editorCursorBlinkOn ? 0.52 : 0.18) : 1.0
                    z: 2
                  }

                  onCursorPositionChanged: {
                    if (root._syncingEditor || !previewPanel.isTextEditable) return
                    var st = root.editorState
                    if (!st) return
                    if (selectionStart !== selectionEnd) {
                      var a = cursorPosition === selectionEnd ? selectionStart : selectionEnd
                      EditorEngine.setSelection(st, a, cursorPosition)
                    } else {
                      EditorEngine.setCursor(st, cursorPosition, false)
                    }
                    root.editorCursorBlinkOn = true
                    cursorBlinkTimer.restart()
                    root.editorRevision++
                  }

                  onSelectionStartChanged: {
                    if (root._syncingEditor || !previewPanel.isTextEditable) return
                    var st = root.editorState
                    if (!st) return
                    if (selectionStart !== selectionEnd) {
                      var a = cursorPosition === selectionEnd ? selectionStart : selectionEnd
                      EditorEngine.setSelection(st, a, cursorPosition)
                      root.editorCursorBlinkOn = true
                      cursorBlinkTimer.restart()
                      root.editorRevision++
                    }
                  }
                }

                Text {
                  id: previewTextItem
                  textFormat: Text.PlainText
                  visible: previewPanel.activeRow && !previewPanel.activeRow.previewImage && !previewPanel.isTextEditable
                  width: previewFlickable.width
                  text: previewPanel.activeRow ? previewPanel.activeRow.fullText : ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: root.settings.editor.fontSize
                  wrapMode: Text.WrapAnywhere
                  verticalAlignment: Text.AlignTop
                }

                SizedImage {
                  visible: previewPanel.activeRow && previewPanel.activeRow.previewImage
                  width: previewFlickable.width
                  height: previewFlickable.height
                  url: previewPanel.activeRow ? previewPanel.activeRow.previewImage : ""
                  verticalAlignment: Image.AlignTop
                  asynchronous: true
                  smooth: true
                }
              }

              Rectangle {
                id: editorStatusBar
                visible: previewPanel.isTextEditable
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: root.contentMargin
                height: visible ? Style.space(22) : 0
                color: "transparent"

                Row {
                  anchors.fill: parent
                  spacing: Style.space(10)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: {
                      var _rev = root.editorRevision
                      if (!previewPanel.panelFocused) return "PREVIEW"
                      if (!root.vimMode) return "EDIT"
                      var m = root.vimState ? root.vimState.mode : "normal"
                      if (m === "insert") return "VIM · INSERT"
                      if (m === "visual") return "VIM · VISUAL"
                      if (m === "visual_line") return "VIM · V-LINE"
                      if (m === "visual_block") return "VIM · V-BLOCK"
                      if (m === "search") return "VIM · /" + (root.vimState ? root.vimState.searchBuffer : "")
                      return "VIM · NORMAL"
                    }
                    color: previewPanel.panelFocused ? root.selectedText : root.foreground
                    opacity: previewPanel.panelFocused ? 1.0 : 0.55
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.weight: Font.DemiBold
                  }

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: vimToggleText.implicitWidth + Style.space(10)
                    height: Style.space(18)
                    radius: Style.space(4)
                    color: root.vimMode ? root.selectedBackground : Util.alpha(root.foreground, 0.08)

                    Text {
                      id: vimToggleText
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: root.vimMode ? "Vim: ON" : "Vim: OFF"
                      color: root.vimMode ? root.selectedText : root.foreground
                      opacity: root.vimMode ? 1.0 : 0.65
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var next = SettingsStore.parseSettings(root.settings)
                        next.editor.vimMode = !next.editor.vimMode
                        root.applySettings(next)
                        VimEngine.resetVimState(root.vimState, "normal")
                        root.editorRevision++
                      }
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: {
                      var _rev = root.editorRevision
                      var st = root.editorState
                      var lc = EditorEngine.cursorLineCol(st ? st.text : "", st ? st.cursor : 0)
                      return "Ln " + (lc.line + 1) + ", Col " + (lc.col + 1)
                    }
                    color: root.foreground
                    opacity: 0.65
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: {
                      var _rev = root.editorRevision
                      return root.editorState && root.editorState.dirty ? "Modified" : ""
                    }
                    color: root.selectedText
                    opacity: 0.85
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              Rectangle {
                id: imageStatusBar
                visible: !!previewPanel.activeRow && !!previewPanel.activeRow.previewImage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: root.contentMargin
                height: visible ? Style.space(28) : 0
                color: "transparent"

                Row {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(8)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: {
                      var _rev = root.imageMetaRevision
                      var r = previewPanel.activeRow
                      if (!r || !r.previewImage) return ""
                      var parts = []
                      var dims = r.path ? root.imageDimensionsMap[r.path] : ""
                      if (dims) parts.push(dims)
                      var sz = ClipboardHistory.formatBytes(r.bytes)
                      if (sz) parts.push(sz)
                      if (r.mime) parts.push(r.mime)
                      return parts.join(" · ")
                    }
                    color: root.foreground
                    opacity: 0.68
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Repeater {
                    model: [
                      { action: "copy", label: "Copy" },
                      { action: "save", label: "Save" },
                      { action: "pin", label: (previewPanel.activeRow && previewPanel.activeRow.pinned) ? "Unpin" : "Pin" },
                      { action: "delete", label: "Delete" }
                    ]

                    Rectangle {
                      required property var modelData
                      width: imgBtnText.implicitWidth + Style.space(12)
                      height: Style.space(22)
                      radius: Style.space(4)
                      color: imgBtnMouse.containsMouse ? root.selectedBackground : Util.alpha(root.foreground, 0.08)

                      Text {
                        id: imgBtnText
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: modelData.label
                        color: imgBtnMouse.containsMouse ? root.selectedText : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      MouseArea {
                        id: imgBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (modelData.action === "copy") root.copyIndex(root.selectedIndex)
                          else if (modelData.action === "save") root.saveSelectedImage()
                          else if (modelData.action === "pin") root.togglePinIndex(root.selectedIndex)
                          else if (modelData.action === "delete") root.removeDisplayIndex(root.selectedIndex)
                        }
                      }
                    }
                  }
                }
              }

              Rectangle {
                visible: previewFlickable.contentHeight > previewFlickable.height && displayModel.count > 0
                anchors.right: parent.right
                anchors.top: previewFlickable.top
                anchors.bottom: previewFlickable.bottom
                width: Style.space(4)
                radius: Style.space(2)
                color: Util.alpha(root.foreground, 0.08)

                Rectangle {
                  width: parent.width
                  radius: parent.radius
                  color: previewPanel.panelFocused ? Util.alpha(root.selectedText, 0.7) : Util.alpha(root.foreground, 0.32)
                  y: previewFlickable.contentHeight > 0
                    ? (previewFlickable.contentY / previewFlickable.contentHeight) * parent.height
                    : 0
                  height: previewFlickable.contentHeight > 0
                    ? Math.max(Style.space(24), (previewFlickable.height / previewFlickable.contentHeight) * parent.height)
                    : parent.height
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            width: parent.width - 2 * root.contentMargin
            spacing: Style.space(8)
            visible: displayModel.count === 0

            Text {
              text: "󰅌"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
              textFormat: Text.PlainText
              text: root.filterText
                ? Commons.I18n.t("common.noMatchesFor", "No matches for “%1”").replace("%1", root.filterText)
                : (root.activeTab === "pinned"
                  ? Commons.I18n.t("clipboard.emptyPinned", "No pinned entries")
                  : Commons.I18n.t("clipboard.empty"))
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
              elide: Text.ElideRight
            }
          }
        }
      }

      BorderSurface {
        id: shortcutsHelpCard
        visible: root.shortcutsHelpOpen
        anchors.centerIn: parent
        z: 19
        width: Math.min(parent.width - Style.space(48), Style.space(520))
        height: Math.min(parent.height - Style.space(48), helpCol.implicitHeight + Style.space(28))
        radius: root.cornerRadius
        color: root.background
        borderSpec: Border.flat(Util.alpha(root.selectedText, 0.5), Style.normalBorderWidth)
        padding: Style.space(14)

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: helpCol
          anchors.fill: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(8)

          Row {
            width: parent.width
            Text {
              width: parent.width - closeHelpBtn.width
              text: "Active Shortcuts (" + (root.vimMode ? "Vim Mode" : "Normal Mode") + ")"
              color: root.selectedText
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.weight: Font.DemiBold
            }
            Rectangle {
              id: closeHelpBtn
              width: Style.space(24); height: Style.space(24); radius: Style.space(4)
              color: Util.alpha(root.foreground, 0.1)
              Text { anchors.centerIn: parent; text: "✕"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.shortcutsHelpOpen = false }
            }
          }

          Repeater {
            model: {
              var kb = root.keybindings
              var list = [
                { k: kb.global.openClipboard || "Unbound", d: "Global: Open / Toggle Clipboard" },
                { k: kb.global.ocrExtract || "Unbound", d: "Global: Screen OCR" },
                { k: kb.app.switchPanel || "Tab", d: "Switch Left List ↔ Right Editor" },
                { k: "↑ / ↓ / ← / →", d: "Navigate list, switch tabs (←), focus editor (→)" },
                { k: kb.app.switchTab || "Ctrl+Tab", d: "Next Tab (All / History / Pinned)" },
                { k: kb.app.togglePin || "Ctrl+P", d: "Pin / Unpin selected entry" },
                { k: (kb.app.deleteEntry || "Delete") + " / " + (kb.app.undoDelete || "Ctrl+Z"), d: "Delete entry / Undo delete" },
                { k: kb.app.startOcr || "Ctrl+O", d: "Screen Text Extraction (OCR)" },
                { k: kb.app.openSettings || "Ctrl+,", d: "Open Advanced Settings" },
                { k: "Enter / Shift+Enter / Alt+Enter", d: "Paste / Copy only / Open externally" }
              ]
              if (root.vimMode) {
                list.push({ k: "j / k / g / G / l / /", d: "List Vim: Down / Up / Top / Bottom / Editor / Search" })
                list.push({ k: "i a I A / v V Ctrl+V", d: "Editor Vim: Insert / Visual / Visual Line / Block" })
                list.push({ k: "h j k l w b e 0 $ gg G", d: "Editor Vim: Motions" })
                list.push({ k: "dd yy p P x / u Ctrl+R", d: "Editor Vim: Delete / Yank / Paste / Undo / Redo" })
              } else {
                list.push({ k: (kb.normal.undo || "Ctrl+Z") + " / " + (kb.normal.redo || "Ctrl+Shift+Z"), d: "Editor: Undo / Redo" })
                list.push({ k: (kb.normal.copySelection || "Ctrl+C") + " / " + (kb.normal.paste || "Ctrl+V"), d: "Editor: Copy selection / Paste" })
                list.push({ k: (kb.normal.find || "Ctrl+F") + " / " + (kb.normal.findNext || "F3"), d: "Editor: Find in entry / Next match" })
              }
              return list
            }

            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(10)
              Text {
                width: Style.space(185)
                textFormat: Text.PlainText
                text: modelData.k
                color: root.selectedText
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
              Text {
                width: parent.width - Style.space(195)
                textFormat: Text.PlainText
                text: modelData.d
                color: root.foreground
                opacity: 0.85
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      BorderSurface {
        id: hoverTooltipCard
        visible: root.hoverTooltipText.length > 0
        x: root.hoverTooltipX
        y: root.hoverTooltipY
        z: 25
        width: hoverTooltipLabel.implicitWidth + Style.space(16)
        height: Style.space(26)
        radius: Math.max(4, root.cornerRadius - 4)
        color: root.background
        borderSpec: Border.flat(Util.alpha(root.border, 0.5), Style.normalBorderWidth)

        Text {
          id: hoverTooltipLabel
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.hoverTooltipText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      BorderSurface {
        id: quickSettingsCard
        visible: root.quickSettingsOpen
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.contentMargin + root.headerHeight + Style.space(6)
        anchors.rightMargin: root.contentMargin
        z: 18
        width: Style.space(250)
        height: qsCol.implicitHeight + Style.space(24)
        radius: root.cornerRadius
        color: root.background
        borderSpec: Border.flat(Util.alpha(root.border, 0.45), Style.normalBorderWidth)
        padding: Style.space(12)

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: qsCol
          anchors.fill: parent
          anchors.margins: Style.space(12)
          spacing: Style.space(8)

          Text { text: "Quick Settings"; color: root.selectedText; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.weight: Font.DemiBold }

          Rectangle {
            width: parent.width; height: Style.space(26); radius: Math.max(4, root.cornerRadius - 4)
            color: root.vimMode ? root.selectedBackground : Util.alpha(root.foreground, 0.08)
            Text { anchors.centerIn: parent; text: "Vim Mode: " + (root.vimMode ? "ON" : "OFF"); color: root.vimMode ? root.selectedText : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                var next = SettingsStore.parseSettings(root.settings)
                next.editor.vimMode = !next.editor.vimMode
                root.applySettings(next)
                VimEngine.resetVimState(root.vimState, "normal")
              }
            }
          }

          Rectangle {
            width: parent.width; height: Style.space(26); radius: Math.max(4, root.cornerRadius - 4)
            color: root.ocrEnabled ? root.selectedBackground : Util.alpha(root.foreground, 0.08)
            Text { anchors.centerIn: parent; text: "OCR: " + (root.ocrEnabled ? "ON" : "OFF") + " (" + root.ocrLanguages + ")"; color: root.ocrEnabled ? root.selectedText : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                var next = SettingsStore.parseSettings(root.settings)
                next.ocr.enabled = !next.ocr.enabled
                root.applySettings(next)
              }
            }
          }

          Rectangle {
            width: parent.width; height: Style.space(26); radius: Math.max(4, root.cornerRadius - 4)
            color: Util.alpha(root.foreground, 0.08)
            Text {
              anchors.centerIn: parent
              text: "History Limit: " + (root.historyLimit < 0 ? "Unlimited" : String(root.historyLimit))
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                var cycle = [100, 250, 500, 1000, -1]
                var idx = cycle.indexOf(root.historyLimit)
                var next = SettingsStore.parseSettings(root.settings)
                next.clipboard.historyLimit = cycle[(idx + 1) % cycle.length]
                root.applySettings(next)
              }
            }
          }

          Rectangle {
            width: parent.width; height: Style.space(28); radius: Math.max(4, root.cornerRadius - 4)
            color: advBtnMouse.containsMouse ? root.selectedBackground : Util.alpha(root.foreground, 0.12)
            Text { anchors.centerIn: parent; text: "Advanced Settings… (Ctrl+,)"; color: advBtnMouse.containsMouse ? root.selectedText : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.weight: Font.DemiBold }
            MouseArea {
              id: advBtnMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.openAdvancedSettings()
            }
          }
        }
      }

      BorderSurface {
        visible: root.toastText.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.contentMargin
        z: 15
        width: toastRow.implicitWidth + Style.space(24)
        height: Style.space(34)
        radius: root.cornerRadius
        color: root.background
        borderSpec: Border.flat(Util.alpha(root.border, 0.45), Style.normalBorderWidth)

        Row {
          id: toastRow
          anchors.centerIn: parent
          spacing: Style.space(12)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.toastText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Rectangle {
            visible: root.toastCanUndo
            anchors.verticalCenter: parent.verticalCenter
            width: undoLabel.implicitWidth + Style.space(14)
            height: Style.space(24)
            radius: Math.max(4, root.cornerRadius - 4)
            color: undoMouse.containsMouse ? root.selectedBackground : Util.alpha(root.foreground, 0.1)

            Text {
              id: undoLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: Commons.I18n.t("clipboard.undo", "Undo")
              color: root.selectedText
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.weight: Font.DemiBold
            }

            MouseArea {
              id: undoMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.undoDelete()
            }
          }
        }
      }
    }
  }
}
