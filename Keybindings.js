// Centralized keybinding configuration, normalization, matching, and conflict detection.
// Keeps Normal and Vim editor profiles separate and supports JSON persistence.

function defaultConfig() {
  return {
    version: 1,
    global: {
      openClipboard: "Super+V",
      ocrExtract: "Super+Shift+S",
      clipboardAndOcr: ""
    },
    app: {
      switchPanel: "Tab",
      switchTab: "Ctrl+Tab",
      tabHistory: "Alt+1",
      tabPinned: "Alt+2",
      togglePin: "Ctrl+P",
      deleteEntry: "Delete",
      clearHistory: "Shift+Delete",
      undoDelete: "Ctrl+Z",
      openSettings: "Ctrl+,",
      startOcr: "Ctrl+O"
    },
    normal: {
      undo: "Ctrl+Z",
      redo: "Ctrl+Shift+Z",
      copySelection: "Ctrl+C",
      cutSelection: "Ctrl+X",
      paste: "Ctrl+V",
      selectAll: "Ctrl+A",
      find: "Ctrl+F",
      findNext: "F3",
      findPrev: "Shift+F3"
    },
    vim: {
      undo: "u",
      redo: "Ctrl+R",
      search: "/",
      searchNext: "n",
      searchPrev: "N",
      yank: "y",
      visualBlock: "Ctrl+V",
      exitInsertSequence: "jk"
    }
  }
}

function normalizeCombo(raw) {
  var s = String(raw || "").trim()
  if (!s) return ""
  if (s === "/" || s === "jk" || (s.length === 1 && s.indexOf("+") < 0)) return s

  var parts = s.split("+").map(function(p) { return p.trim() }).filter(Boolean)
  if (parts.length === 0) return ""

  var mods = { Ctrl: false, Shift: false, Alt: false, Super: false }
  var key = ""
  for (var i = 0; i < parts.length; i++) {
    var lower = parts[i].toLowerCase()
    if (lower === "ctrl" || lower === "control") mods.Ctrl = true
    else if (lower === "shift") mods.Shift = true
    else if (lower === "alt") mods.Alt = true
    else if (lower === "super" || lower === "meta") mods.Super = true
    else key = parts[i]
  }
  if (!key) return ""

  var keyLower = key.toLowerCase()
  if (keyLower === "tab" || keyLower === "backtab") key = "Tab"
  else if (keyLower === "del" || keyLower === "delete") key = "Delete"
  else if (keyLower === "esc" || keyLower === "escape") key = "Escape"
  else if (keyLower === "ret" || keyLower === "return" || keyLower === "enter") key = "Return"
  else if (keyLower === "space") key = "Space"
  else if (/^f\d{1,2}$/i.test(key)) key = key.toUpperCase()
  else if (key.length === 1) key = key.toUpperCase()

  var out = []
  if (mods.Ctrl) out.push("Ctrl")
  if (mods.Shift) out.push("Shift")
  if (mods.Alt) out.push("Alt")
  if (mods.Super) out.push("Super")
  out.push(key)
  return out.join("+")
}

function parseConfig(raw) {
  var base = defaultConfig()
  if (!raw) return base
  try {
    var parsed = typeof raw === "string" ? JSON.parse(raw) : raw
    if (!parsed || typeof parsed !== "object") return base
    var scopes = ["global", "app", "normal", "vim"]
    for (var s = 0; s < scopes.length; s++) {
      var sc = scopes[s]
      if (parsed[sc] && typeof parsed[sc] === "object") {
        for (var k in base[sc]) {
          if (parsed[sc][k] !== undefined && parsed[sc][k] !== null) {
            base[sc][k] = sc === "vim" && String(parsed[sc][k]).indexOf("+") < 0
              ? String(parsed[sc][k])
              : normalizeCombo(parsed[sc][k])
          }
        }
      }
    }
    return base
  } catch (e) {
    return base
  }
}

function serializeConfig(cfg) {
  return JSON.stringify(parseConfig(cfg), null, 2) + "\n"
}

function cloneConfig(cfg) {
  return JSON.parse(JSON.stringify(parseConfig(cfg)))
}

function matchAction(cfg, scope, combo) {
  var c = normalizeCombo(combo)
  if (!c || !cfg || !cfg[scope]) return ""
  var map = cfg[scope]
  for (var action in map) {
    if (normalizeCombo(map[action]) === c) return action
  }
  return ""
}

function detectConflicts(cfg) {
  var c = parseConfig(cfg)
  var conflicts = []
  var scopes = ["global", "app", "normal", "vim"]

  // Within each scope, no two actions should share the same combo.
  for (var s = 0; s < scopes.length; s++) {
    var sc = scopes[s]
    var seen = {}
    for (var action in c[sc]) {
      var combo = normalizeCombo(c[sc][action])
      if (!combo) continue
      if (seen[combo]) {
        conflicts.push({
          scopeA: sc,
          actionA: seen[combo],
          scopeB: sc,
          actionB: action,
          combo: combo,
          severity: "error"
        })
      } else {
        seen[combo] = action
      }
    }
  }

  // Global vs app/editor collisions
  for (var gAction in c.global) {
    var gCombo = normalizeCombo(c.global[gAction])
    if (!gCombo) continue
    for (var aAction in c.app) {
      if (normalizeCombo(c.app[aAction]) === gCombo) {
        conflicts.push({
          scopeA: "global",
          actionA: gAction,
          scopeB: "app",
          actionB: aAction,
          combo: gCombo,
          severity: "warning"
        })
      }
    }
  }

  return conflicts
}

function setBinding(cfg, scope, action, combo) {
  var next = cloneConfig(cfg)
  if (!next[scope] || next[scope][action] === undefined) {
    return { config: next, conflicts: detectConflicts(next) }
  }
  var normalized = (scope === "vim" && String(combo).indexOf("+") < 0)
    ? String(combo || "")
    : normalizeCombo(combo)
  next[scope][action] = normalized
  return {
    config: next,
    conflicts: detectConflicts(next)
  }
}

function qtEventToCombo(key, modifiers, text, qtKeys) {
  // qtKeys is optional map of Qt key codes passed from QML
  var ctrl = !!(modifiers & 0x04000000)
  var shift = !!(modifiers & 0x02000000)
  var alt = !!(modifiers & 0x08000000)
  var meta = !!(modifiers & 0x10000000)

  var name = ""
  if (qtKeys) {
    if (key === qtKeys.Key_Tab || key === qtKeys.Key_Backtab) {
      name = "Tab"
      if (key === qtKeys.Key_Backtab) shift = true
    } else if (key === qtKeys.Key_Delete) name = "Delete"
    else if (key === qtKeys.Key_Backspace) name = "Backspace"
    else if (key === qtKeys.Key_Escape) name = "Escape"
    else if (key === qtKeys.Key_Return || key === qtKeys.Key_Enter) name = "Return"
    else if (key === qtKeys.Key_F3) name = "F3"
    else if (key === qtKeys.Key_Comma) name = ","
    else if (key >= 0x41 && key <= 0x5a) name = String.fromCharCode(key)
    else if (key >= 0x30 && key <= 0x39) name = String.fromCharCode(key)
  }

  if (!name && text && text.length === 1 && text.charCodeAt(0) >= 32 && text.charCodeAt(0) !== 127) {
    name = text.toUpperCase()
  }
  if (!name) return ""

  var parts = []
  if (ctrl) parts.push("Ctrl")
  if (shift) parts.push("Shift")
  if (alt) parts.push("Alt")
  if (meta) parts.push("Super")
  parts.push(name)
  return parts.join("+")
}

if (typeof module !== "undefined") {
  module.exports = {
    defaultConfig: defaultConfig,
    normalizeCombo: normalizeCombo,
    parseConfig: parseConfig,
    serializeConfig: serializeConfig,
    matchAction: matchAction,
    detectConflicts: detectConflicts,
    setBinding: setBinding,
    qtEventToCombo: qtEventToCombo
  }
}
