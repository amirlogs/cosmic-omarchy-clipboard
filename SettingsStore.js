// Pure-JS settings store with validation, safe defaults, migration, and search.

function defaultSettings() {
  return {
    version: 1,
    general: {
      defaultTab: "history",       // "history" | "pinned" | "all"
      closeOnCopy: true
    },
    editor: {
      vimMode: false,
      jkExit: true,
      cursorStyle: "auto",         // "auto" | "line" | "block"
      fontSize: 14                 // 12 | 14 | 16 | 18
    },
    navigation: {
      wrapSelection: true
    },
    clipboard: {
      historyLimit: 500,           // 100 | 250 | 500 | 1000 | -1 (unlimited) | custom
      autoCleanupHours: 0          // 0 (never) | 24 | 168 | 720 | 2160
    },
    ocr: {
      enabled: true,
      languages: "eng"             // "eng" | "amh" | "eng+amh"
    },
    appearance: {
      backgroundOpacity: 0.94,     // 0.65 .. 1.0
      cornerRadius: 12             // 0 | 8 | 12 | 16
    }
  }
}

function clampOpacity(v) {
  var n = Number(v)
  if (!isFinite(n)) return 0.94
  return Math.max(0.65, Math.min(1.0, Math.round(n * 100) / 100))
}

function validateLimit(v) {
  var n = Number(v)
  if (!isFinite(n)) return 500
  if (n < 0) return -1
  return Math.max(10, Math.min(10000, Math.floor(n)))
}

function validateCleanupHours(v) {
  var n = Number(v)
  if (!isFinite(n) || n <= 0) return 0
  return Math.floor(n)
}

function parseSettings(raw) {
  var d = defaultSettings()
  if (!raw) return d
  try {
    var obj = typeof raw === "string" ? JSON.parse(raw) : raw
    if (!obj || typeof obj !== "object") return d

    if (obj.general && typeof obj.general === "object") {
      if (obj.general.defaultTab === "history" || obj.general.defaultTab === "pinned" || obj.general.defaultTab === "all") {
        d.general.defaultTab = obj.general.defaultTab
      }
      if (typeof obj.general.closeOnCopy === "boolean") d.general.closeOnCopy = obj.general.closeOnCopy
    }
    if (obj.editor && typeof obj.editor === "object") {
      if (typeof obj.editor.vimMode === "boolean") d.editor.vimMode = obj.editor.vimMode
      if (typeof obj.editor.jkExit === "boolean") d.editor.jkExit = obj.editor.jkExit
      if (obj.editor.cursorStyle === "auto" || obj.editor.cursorStyle === "line" || obj.editor.cursorStyle === "block") {
        d.editor.cursorStyle = obj.editor.cursorStyle
      }
      if (obj.editor.fontSize !== undefined) {
        var fs = Number(obj.editor.fontSize)
        if (isFinite(fs)) d.editor.fontSize = Math.max(10, Math.min(24, Math.floor(fs)))
      }
    }
    if (obj.navigation && typeof obj.navigation === "object") {
      if (typeof obj.navigation.wrapSelection === "boolean") d.navigation.wrapSelection = obj.navigation.wrapSelection
    }
    if (obj.clipboard && typeof obj.clipboard === "object") {
      if (obj.clipboard.historyLimit !== undefined) d.clipboard.historyLimit = validateLimit(obj.clipboard.historyLimit)
      if (obj.clipboard.autoCleanupHours !== undefined) d.clipboard.autoCleanupHours = validateCleanupHours(obj.clipboard.autoCleanupHours)
    }
    if (obj.ocr && typeof obj.ocr === "object") {
      if (typeof obj.ocr.enabled === "boolean") d.ocr.enabled = obj.ocr.enabled
      if (typeof obj.ocr.languages === "string" && obj.ocr.languages.trim().length > 0) {
        d.ocr.languages = obj.ocr.languages.trim()
      }
    }
    if (obj.appearance && typeof obj.appearance === "object") {
      if (obj.appearance.backgroundOpacity !== undefined) {
        d.appearance.backgroundOpacity = clampOpacity(obj.appearance.backgroundOpacity)
      }
      if (obj.appearance.cornerRadius !== undefined) {
        var cr = Number(obj.appearance.cornerRadius)
        if (isFinite(cr)) d.appearance.cornerRadius = Math.max(0, Math.min(24, Math.floor(cr)))
      }
    }
    return d
  } catch (e) {
    return d
  }
}

function serializeSettings(settings) {
  return JSON.stringify(parseSettings(settings), null, 2) + "\n"
}

function matchesSettingSearch(title, description, query) {
  var q = String(query || "").trim().toLowerCase()
  if (!q) return true
  return String(title || "").toLowerCase().indexOf(q) >= 0 ||
    String(description || "").toLowerCase().indexOf(q) >= 0
}

if (typeof module !== "undefined") {
  module.exports = {
    defaultSettings: defaultSettings,
    parseSettings: parseSettings,
    serializeSettings: serializeSettings,
    matchesSettingSearch: matchesSettingSearch
  }
}
