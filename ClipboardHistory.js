// Clipboard data model and storage helpers.
//
// The on-disk history is still a flat JSON array so the existing shell
// helpers (which read entries by index) keep working. Entries now carry a
// stable id, timestamps, a content hash, a pinned flag and a source. Older
// entries are upgraded in place the first time they are loaded.
//
// This file is deliberately free of QML imports so it can be tested with
// Node's built-in test runner. The QML side imports it as a JS library.

var SCHEMA_VERSION = 2

function nowMs(value) {
  var n = Number(value)
  return isFinite(n) && n > 0 ? n : Date.now()
}

function iso(ms) {
  return new Date(nowMs(ms)).toISOString()
}

function isIsoDate(value) {
  if (typeof value !== "string" || value.length === 0) return false
  var t = Date.parse(value)
  return isFinite(t)
}

// FNV-1a is used only to derive a deterministic fallback id for entries that
// predate the id field. New entries get a random id that survives edits.
function fnv1a(value) {
  var text = String(value || "")
  var hash = 0x811c9dc5
  for (var i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i)
    hash = (hash + ((hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24))) >>> 0
  }
  return ("00000000" + hash.toString(16)).slice(-8)
}

function legacyId(key) {
  return "legacy_" + fnv1a(key)
}

function newId(ms) {
  var base = Number(ms || Date.now()).toString(36)
  var rand = Math.random().toString(36).slice(2, 10)
  return "e_" + base + "_" + rand
}

function copyKnown(value) {
  var out = {}
  if (!value || typeof value !== "object") return out
  for (var key in value) out[key] = value[key]
  return out
}

function entryKey(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image:" + String(entry.path || "")
  return "text:" + String(entry.text || "")
}

function normalizeEntry(value, now, index) {
  var ms = nowMs(now)
  var fallback = iso(ms - (Number(index) || 0) * 1000)
  var entry = null

  if (typeof value === "string") {
    if (value.trim().length === 0) return null
    entry = { type: "text", text: value }
  } else if (value && typeof value === "object") {
    var type = String(value.type || value.kind || "")
    if (type === "text") {
      var text = String(value.text || "")
      var hasId = typeof value.id === "string" && value.id.length > 0
      // Empty text is allowed for an existing entry (the editor may clear it),
      // but a brand-new empty clipboard capture is ignored.
      if (text.trim().length === 0 && !hasId) return null
      entry = copyKnown(value)
      entry.type = "text"
      entry.text = text
      delete entry.path
      delete entry.mime
      delete entry.bytes
      delete entry.image
      delete entry.capturedAt
    } else if (type === "image") {
      var path = String(value.path || "")
      if (!path) return null
      entry = copyKnown(value)
      entry.type = "image"
      entry.path = path
      entry.mime = String(value.mime || "image/png")
      delete entry.text
      if (value.capturedAt !== undefined && value.capturedAt !== null)
        entry.capturedAt = String(value.capturedAt)
      var bytes = Number(value.bytes)
      if (isFinite(bytes) && bytes >= 0) entry.bytes = bytes
      else delete entry.bytes
      if (value.image && typeof value.image === "object")
        entry.image = copyKnown(value.image)
    } else {
      return null
    }
  } else {
    return null
  }

  delete entry.kind

  if (typeof entry.id !== "string" || entry.id.length === 0)
    entry.id = legacyId(entryKey(entry))

  var created = isIsoDate(entry.createdAt) ? String(entry.createdAt) : fallback
  var updated = isIsoDate(entry.updatedAt) ? String(entry.updatedAt) : created
  var used = isIsoDate(entry.lastUsedAt) ? String(entry.lastUsedAt) : created
  entry.createdAt = created
  entry.updatedAt = updated
  entry.lastUsedAt = used
  entry.pinned = entry.pinned === true
  entry.source = (typeof entry.source === "string" && entry.source.length > 0)
    ? entry.source
    : "clipboard"
  entry.hash = typeof entry.hash === "string" ? entry.hash : ""

  // Older images are content-addressed by SHA-256 filename, so recover the
  // hash without re-reading the file.
  if (entry.type === "image" && entry.hash.length === 0) {
    var parts = entry.path.split("/")
    var base = parts.length > 0 ? parts[parts.length - 1].split(".")[0] : ""
    if (/^[0-9a-f]{64}$/.test(base)) entry.hash = base
  }

  return entry
}

function needsMigration(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return true
  if (typeof value.type !== "string" || value.type.length === 0) return true
  if (typeof value.id !== "string" || value.id.length === 0) return true
  if (typeof value.pinned !== "boolean") return true
  if (typeof value.source !== "string" || value.source.length === 0) return true
  if (!isIsoDate(value.createdAt) || !isIsoDate(value.updatedAt) || !isIsoDate(value.lastUsedAt)) return true
  if (value.hash === undefined) return true
  return false
}

// Returns { entries, migrated }. `migrated` tells the caller to write the
// upgraded array back so the next load is a no-op.
function parseHistory(raw, now) {
  var ms = nowMs(now)
  var parsed
  try {
    parsed = JSON.parse(String(raw || "[]"))
  } catch (e) {
    return { entries: [], migrated: false }
  }

  var migrated = false
  if (parsed && !Array.isArray(parsed) && Array.isArray(parsed.entries)) {
    parsed = parsed.entries
    migrated = true
  }
  if (!Array.isArray(parsed)) return { entries: [], migrated: false }

  var entries = []
  var seen = {}
  for (var i = 0; i < parsed.length; i++) {
    var value = parsed[i]
    if (needsMigration(value)) migrated = true
    var entry = normalizeEntry(value, ms, i)
    if (!entry) {
      migrated = true
      continue
    }
    var key = entryKey(entry)
    if (seen[key] !== undefined) {
      migrated = true
      if (entry.pinned) entries[seen[key]].pinned = true
      continue
    }
    seen[key] = entries.length
    entries.push(entry)
  }

  return { entries: entries, migrated: migrated }
}

// Keep every pinned entry and at most `limit` unpinned entries, preserving
// newest-first order. A negative or non-finite limit means unlimited.
function applyLimit(history, limit) {
  var values = Array.isArray(history) ? history : []
  if (limit === undefined || limit === null) return values.slice()
  var max = Number(limit)
  if (!isFinite(max) || max < 0) return values.slice()
  max = Math.floor(max)

  var out = []
  var unpinned = 0
  for (var i = 0; i < values.length; i++) {
    var entry = values[i]
    if (entry && entry.pinned === true) {
      out.push(entry)
    } else if (unpinned < max) {
      out.push(entry)
      unpinned++
    }
  }
  return out
}

function addEntry(history, entry, limit, now) {
  var ms = nowMs(now)
  var stamp = iso(ms)
  var normalized = normalizeEntry(entry, ms)
  if (!normalized) return Array.isArray(history) ? applyLimit(history, limit) : []

  // A fallback id means this is a new entry, not a legacy record being
  // re-read. Give it an id that will survive future edits.
  if (normalized.id.indexOf("legacy_") === 0) normalized.id = newId(ms)

  var key = entryKey(normalized)
  var values = Array.isArray(history) ? history : []
  var found = null
  var next = []

  for (var i = 0; i < values.length; i++) {
    var existing = normalizeEntry(values[i], ms, i)
    if (!existing) continue
    if (!found && entryKey(existing) === key) {
      found = existing
      continue
    }
    next.push(existing)
  }

  if (found) {
    found.lastUsedAt = stamp
    if (normalized.pinned) found.pinned = true
    if (!found.source && normalized.source) found.source = normalized.source
    if (!found.hash && normalized.hash) found.hash = normalized.hash
    next.unshift(found)
  } else {
    next.unshift(normalized)
  }

  return applyLimit(next, limit)
}

function updateEntry(history, id, changes, now) {
  var ms = nowMs(now)
  var stamp = iso(ms)
  var target = String(id || "")
  var values = Array.isArray(history) ? history : []
  var found = null
  var next = []

  for (var i = 0; i < values.length; i++) {
    var entry = normalizeEntry(values[i], ms, i)
    if (!entry) continue
    if (entry.id === target) {
      found = entry
      continue
    }
    next.push(entry)
  }

  if (!found) return values.slice()

  var patch = changes || {}
  if (patch.text !== undefined) found.text = String(patch.text)
  if (patch.path !== undefined) found.path = String(patch.path)
  if (patch.mime !== undefined) found.mime = String(patch.mime)
  if (patch.hash !== undefined) found.hash = String(patch.hash)
  if (patch.source !== undefined) found.source = String(patch.source)
  if (patch.pinned !== undefined) found.pinned = patch.pinned === true
  if (patch.bytes !== undefined) {
    var bytes = Number(patch.bytes)
    if (isFinite(bytes) && bytes >= 0) found.bytes = bytes
  }
  if (patch.image !== undefined && patch.image && typeof patch.image === "object")
    found.image = copyKnown(patch.image)

  found.updatedAt = stamp
  found.lastUsedAt = stamp
  next.unshift(found)
  return next
}

function removeEntryById(history, id) {
  var values = Array.isArray(history) ? history : []
  var target = String(id || "")
  for (var i = 0; i < values.length; i++) {
    var entry = normalizeEntry(values[i], Date.now(), i)
    if (entry && entry.id === target) {
      var next = values.slice()
      next.splice(i, 1)
      return { history: next, removed: entry, index: i }
    }
  }
  return { history: values.slice(), removed: null, index: -1 }
}

function restoreEntry(history, entry, index) {
  var values = Array.isArray(history) ? history : []
  var normalized = normalizeEntry(entry, Date.now())
  if (!normalized) return values.slice()

  for (var i = 0; i < values.length; i++) {
    if (values[i] && values[i].id === normalized.id) return values.slice()
  }

  var at = Number(index)
  if (!isFinite(at) || at < 0 || at > values.length) at = 0
  var next = values.slice()
  next.splice(Math.floor(at), 0, normalized)
  return next
}

function setPinned(history, id, pinned, now) {
  var ms = nowMs(now)
  var target = String(id || "")
  var values = Array.isArray(history) ? history : []
  var next = []
  for (var i = 0; i < values.length; i++) {
    var entry = normalizeEntry(values[i], ms, i)
    if (!entry) continue
    if (entry.id === target) entry.pinned = pinned === true
    next.push(entry)
  }
  return next
}

// Clear unpinned history by default; pinned entries survive. Pass true only
// for an explicit "delete everything" action.
function clearHistory(history, includePinned) {
  var values = Array.isArray(history) ? history : []
  if (includePinned === true) return []
  var next = []
  for (var i = 0; i < values.length; i++) {
    if (values[i] && values[i].pinned === true) next.push(values[i])
  }
  return next
}

function removeEntryAt(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()

  var next = values.slice()
  next.splice(target, 1)
  return next
}

function serialize(history, limit) {
  return JSON.stringify(applyLimit(history, limit), null, 2) + "\n"
}

function parseEntryJson(line) {
  var raw = String(line || "").trim()
  if (!raw) return null
  try {
    return normalizeEntry(JSON.parse(raw))
  } catch (e) {
    return null
  }
}

function searchableText(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image screenshot " + String(entry.mime || "") + " " + String(entry.capturedAt || "")
  return String(entry.text || "") + " " + fileEntryText(entry)
}

function decodeFileUri(uri) {
  var value = String(uri || "").trim()
  if (value.indexOf("file://") !== 0) return ""

  var path = value.substring(7)
  if (path.indexOf("localhost/") === 0) path = path.substring(9)
  if (path.charAt(0) !== "/") return ""

  try { return decodeURIComponent(path) } catch (e) { return path }
}

function filePaths(entry) {
  if (!entry || entry.type !== "text") return []

  var lines = String(entry.text || "").split(/\r?\n/)
  var paths = []
  for (var i = 0; i < lines.length; i++) {
    var path = decodeFileUri(lines[i])
    if (path) paths.push(path)
  }
  return paths
}

function fileName(path) {
  var parts = String(path || "").split("/")
  return parts.length > 0 ? parts[parts.length - 1] : String(path || "")
}

function isImagePath(path) {
  return /\.(png|jpe?g|webp|gif|bmp|tiff?)$/i.test(String(path || ""))
}

// tr is an optional translate(key, english) from the QML side (I18n.t),
// trn its plural form (I18n.tn) and fmt a number formatter
// (I18n.formatNumber); without them the English text and plain digits
// stand, which is what the Node tests assert.
function translator(tr) {
  return typeof tr === "function" ? tr : function(key, english) { return english }
}

function fileEntryText(entry, tr, trn, fmt) {
  var tn = typeof trn === "function" ? trn : function(key, count, english) { return count === 1 ? english.one : english.other }
  var number = typeof fmt === "function" ? fmt : function(v) { return String(v) }
  var paths = filePaths(entry)
  if (paths.length === 0) return ""
  if (paths.length === 1) return fileName(paths[0])
  return tn("clipboard.files", paths.length, { one: "%1 file", other: "%1 files" }).replace("%1", number(paths.length))
}

function imagePreviewText(entry, tr) {
  var t = translator(tr)
  var timestamp = String(entry && entry.capturedAt || "")
  if (!timestamp) return t("clipboard.image", "Image")

  var screenshot = String(entry && entry.mime || "") === "image/png"
  var pattern = screenshot
    ? t("clipboard.screenshotFrom", "Screenshot from %1")
    : t("clipboard.imageFrom", "Image from %1")
  return pattern.replace("%1", timestamp)
}

function previewText(entry, tr, trn, fmt) {
  if (!entry) return ""
  if (entry.type === "image") return imagePreviewText(entry, tr)
  var fileText = fileEntryText(entry, tr, trn, fmt)
  if (fileText) return fileText
  return String(entry.text || "").replace(/\s+/g, " ")
}

function fullText(entry) {
  if (!entry) return ""
  var paths = filePaths(entry)
  if (paths.length > 0) return paths.join("\n")
  return String(entry.text || "")
}

// The picker only ever searches and renders a prefix of an entry, so scan and
// render just that much. A single huge paste otherwise costs hundreds of
// megabytes of string work on every keystroke and stalls the whole shell.
// The editor loads the full entry from the store by id, so nothing is lost.
var displayTextLimit = 8192

function cappedEntry(entry) {
  if (!entry || entry.type !== "text" || entry.text.length <= displayTextLimit) return entry

  // Cut on a line break so a file:// URI never truncates into a bogus path.
  var cut = entry.text.lastIndexOf("\n", displayTextLimit)
  var capped = copyKnown(entry)
  capped.text = entry.text.slice(0, cut > 0 ? cut : displayTextLimit)
  return capped
}

function displayRows(history, query, limit, tr, trn, fmt, mode) {
  var values = Array.isArray(history) ? history : []
  var needle = String(query || "").trim().toLowerCase()
  var tab = String(mode || "all")
  var max = limit === undefined || limit === null ? 50 : Number(limit)
  if (isNaN(max)) max = 50
  max = Math.max(0, max)
  if (max === 0) return []

  var rows = []

  for (var i = 0; i < values.length; i++) {
    var entry = cappedEntry(normalizeEntry(values[i], undefined, i))
    if (!entry) continue
    if (tab === "history" && entry.pinned === true) continue
    if (tab === "pinned" && entry.pinned !== true) continue
    if (needle && searchableText(entry).toLowerCase().indexOf(needle) < 0) continue

    var paths = filePaths(entry)
    var isFile = paths.length > 0
    var isImage = entry.type === "image"
    var previewPath = isImage ? String(entry.path || "") : (isFile && paths.length === 1 && isImagePath(paths[0]) ? paths[0] : "")
    rows.push({
      id: String(entry.id || ""),
      pinned: entry.pinned === true,
      entryType: isFile ? "file" : entry.type,
      fullText: isImage ? "" : fullText(entry),
      previewText: previewText(entry, tr, trn, fmt),
      previewImage: previewPath,
      path: isImage ? String(entry.path || "") : (isFile && paths.length === 1 ? paths[0] : ""),
      mime: isImage ? String(entry.mime || "image/png") : "text/plain",
      index: i
    })
    if (rows.length >= max) break
  }

  return rows
}

if (typeof module !== "undefined") {
  module.exports = {
    SCHEMA_VERSION: SCHEMA_VERSION,
    normalizeEntry: normalizeEntry,
    entryKey: entryKey,
    parseHistory: parseHistory,
    addEntry: addEntry,
    updateEntry: updateEntry,
    removeEntryById: removeEntryById,
    removeEntryAt: removeEntryAt,
    restoreEntry: restoreEntry,
    setPinned: setPinned,
    applyLimit: applyLimit,
    clearHistory: clearHistory,
    serialize: serialize,
    parseEntryJson: parseEntryJson,
    searchableText: searchableText,
    previewText: previewText,
    imagePreviewText: imagePreviewText,
    filePaths: filePaths,
    fileEntryText: fileEntryText,
    fullText: fullText,
    displayRows: displayRows
  }
}
