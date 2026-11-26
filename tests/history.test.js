"use strict"

const test = require("node:test")
const assert = require("node:assert/strict")
const H = require("../ClipboardHistory.js")

const NOW = Date.parse("2026-11-26T12:00:00.000Z")
const ISO = new Date(NOW).toISOString()

test("normalizeEntry gives text entries an id, timestamps and defaults", () => {
  const entry = H.normalizeEntry("hello", NOW)
  assert.equal(entry.type, "text")
  assert.equal(entry.text, "hello")
  assert.match(entry.id, /^legacy_/)
  assert.equal(entry.createdAt, ISO)
  assert.equal(entry.updatedAt, ISO)
  assert.equal(entry.lastUsedAt, ISO)
  assert.equal(entry.pinned, false)
  assert.equal(entry.source, "clipboard")
  assert.equal(entry.hash, "")
})

test("normalizeEntry rejects empty new text but keeps an existing empty entry", () => {
  assert.equal(H.normalizeEntry("", NOW), null)
  assert.equal(H.normalizeEntry("   ", NOW), null)
  const existing = H.normalizeEntry({ id: "e_1", type: "text", text: "" }, NOW)
  assert.equal(existing.text, "")
  assert.equal(existing.id, "e_1")
})

test("normalizeEntry keeps image metadata and recovers a content hash", () => {
  const hash = "a".repeat(64)
  const entry = H.normalizeEntry({
    type: "image",
    path: "/tmp/clipboard-images/" + hash + ".png",
    mime: "image/png",
    capturedAt: "Thursday 15:20",
    bytes: 1234
  }, NOW)
  assert.equal(entry.type, "image")
  assert.equal(entry.hash, hash)
  assert.equal(entry.bytes, 1234)
  assert.equal(entry.capturedAt, "Thursday 15:20")
  assert.equal(entry.text, undefined)
})

test("parseHistory migrates legacy entries and is idempotent after serialization", () => {
  const raw = JSON.stringify([
    { type: "text", text: "first" },
    { type: "image", path: "/tmp/a.png", mime: "image/png", capturedAt: "Thursday 15:20" }
  ])
  const first = H.parseHistory(raw, NOW)
  assert.equal(first.entries.length, 2)
  assert.equal(first.migrated, true)
  assert.ok(first.entries[0].id)
  assert.equal(first.entries[0].pinned, false)
  assert.equal(first.entries[0].source, "clipboard")
  assert.equal(first.entries[1].hash, "")

  const saved = H.serialize(first.entries, 500)
  const second = H.parseHistory(saved, NOW)
  assert.equal(second.migrated, false)
  assert.deepEqual(second.entries.map(e => e.id), first.entries.map(e => e.id))
})

test("parseHistory deduplicates exact content and preserves pinned state", () => {
  const raw = JSON.stringify([
    { type: "text", text: "same", pinned: false },
    { type: "text", text: "same", pinned: true },
    { type: "text", text: "other" }
  ])
  const { entries, migrated } = H.parseHistory(raw, NOW)
  assert.equal(migrated, true)
  assert.equal(entries.length, 2)
  assert.equal(entries[0].text, "same")
  assert.equal(entries[0].pinned, true)
})

test("parseHistory handles invalid JSON and versioned objects", () => {
  assert.deepEqual(H.parseHistory("not json", NOW), { entries: [], migrated: false })
  const wrapped = H.parseHistory(JSON.stringify({ entries: [{ type: "text", text: "x" }] }), NOW)
  assert.equal(wrapped.entries.length, 1)
  assert.equal(wrapped.migrated, true)
})

test("addEntry assigns a durable id and moves a re-copy to the top without duplicating", () => {
  let history = H.addEntry([], { type: "text", text: "a" }, 500, NOW)
  const idA = history[0].id
  assert.match(idA, /^e_/)
  assert.equal(history[0].createdAt, ISO)

  history = H.addEntry(history, { type: "text", text: "b" }, 500, NOW + 1000)
  history = H.addEntry(history, { type: "text", text: "a" }, 500, NOW + 2000)

  assert.equal(history.length, 2)
  assert.equal(history[0].text, "a")
  assert.equal(history[0].id, idA)
  assert.equal(history[0].createdAt, ISO)
  assert.equal(history[0].lastUsedAt, new Date(NOW + 2000).toISOString())
})

test("applyLimit keeps pinned entries outside the unpinned limit", () => {
  let history = []
  history = H.addEntry(history, { type: "text", text: "pin", pinned: true }, 2, NOW)
  history = H.addEntry(history, { type: "text", text: "a" }, 2, NOW + 1000)
  history = H.addEntry(history, { type: "text", text: "b" }, 2, NOW + 2000)
  history = H.addEntry(history, { type: "text", text: "c" }, 2, NOW + 3000)

  assert.equal(history.length, 3)
  assert.equal(history.filter(e => e.pinned).length, 1)
  assert.equal(history.filter(e => !e.pinned).length, 2)
  assert.equal(history.filter(e => e.text === "c").length, 1)
  assert.equal(history.filter(e => e.text === "a").length, 0)
})

test("updateEntry edits by id, preserves metadata and moves to the top", () => {
  let history = H.addEntry([], { type: "text", text: "a" }, 500, NOW)
  const id = history[0].id
  history = H.addEntry(history, { type: "text", text: "b" }, 500, NOW + 1000)
  history = H.updateEntry(history, id, { text: "a edited" }, NOW + 2000)

  assert.equal(history[0].id, id)
  assert.equal(history[0].text, "a edited")
  assert.equal(history[0].createdAt, ISO)
  assert.equal(history[0].updatedAt, new Date(NOW + 2000).toISOString())
})

test("removeEntryById and restoreEntry round-trip the entry and position", () => {
  let history = H.addEntry([], { type: "text", text: "a" }, 500, NOW)
  const id = history[0].id
  history = H.addEntry(history, { type: "text", text: "b" }, 500, NOW + 1000)

  const removed = H.removeEntryById(history, id)
  assert.equal(removed.index, 1)
  assert.equal(removed.removed.id, id)
  assert.equal(removed.history.length, 1)

  const restored = H.restoreEntry(removed.history, removed.removed, removed.index)
  assert.equal(restored.length, 2)
  assert.equal(restored[1].id, id)
})

test("setPinned toggles state without changing order", () => {
  let history = H.addEntry([], { type: "text", text: "a" }, 500, NOW)
  const id = history[0].id
  history = H.addEntry(history, { type: "text", text: "b" }, 500, NOW + 1000)

  const pinned = H.setPinned(history, id, true, NOW + 2000)
  assert.equal(pinned[1].pinned, true)
  const unpinned = H.setPinned(pinned, id, false, NOW + 3000)
  assert.equal(unpinned[1].pinned, false)
})

test("clearHistory keeps pinned entries unless explicitly included", () => {
  const history = [
    { type: "text", text: "pin", pinned: true },
    { type: "text", text: "temp", pinned: false }
  ]
  const kept = H.clearHistory(history)
  assert.equal(kept.length, 1)
  assert.equal(kept[0].text, "pin")
  assert.equal(H.clearHistory(history, true).length, 0)
})

test("displayRows exposes stable ids and pinned state", () => {
  let history = H.addEntry([], { type: "text", text: "a" }, 500, NOW)
  history = H.addEntry(history, { type: "text", text: "b", pinned: true }, 500, NOW + 1000)
  const rows = H.displayRows(history, "", 50)
  assert.equal(rows[0].id, history[0].id)
  assert.equal(rows[0].pinned, true)
  assert.equal(rows[1].id, history[1].id)
})

test("displayRows filters by tab and keeps original history indices", () => {
  let history = H.addEntry([], { type: "text", text: "a" }, 500, NOW)
  history = H.addEntry(history, { type: "text", text: "b", pinned: true }, 500, NOW + 1000)
  history = H.addEntry(history, { type: "text", text: "c" }, 500, NOW + 2000)

  const all = H.displayRows(history, "", 50, undefined, undefined, undefined, "all")
  const unpinned = H.displayRows(history, "", 50, undefined, undefined, undefined, "history")
  const pinned = H.displayRows(history, "", 50, undefined, undefined, undefined, "pinned")

  assert.deepEqual(all.map(r => r.previewText), ["c", "b", "a"])
  assert.deepEqual(unpinned.map(r => r.previewText), ["c", "a"])
  assert.deepEqual(pinned.map(r => r.previewText), ["b"])
  assert.equal(pinned[0].index, 1)
  assert.equal(unpinned[1].index, 2)
})

test("tab filtering still applies the search query", () => {
  let history = H.addEntry([], { type: "text", text: "alpha", pinned: true }, 500, NOW)
  history = H.addEntry(history, { type: "text", text: "alphabet" }, 500, NOW + 1000)
  history = H.addEntry(history, { type: "text", text: "beta" }, 500, NOW + 2000)

  const pinned = H.displayRows(history, "alpha", 50, undefined, undefined, undefined, "pinned")
  const unpinned = H.displayRows(history, "alpha", 50, undefined, undefined, undefined, "history")
  assert.deepEqual(pinned.map(r => r.previewText), ["alpha"])
  assert.deepEqual(unpinned.map(r => r.previewText), ["alphabet"])
})

test("pin and unpin keep array order and metadata", () => {
  let history = H.addEntry([], { type: "text", text: "a" }, 500, NOW)
  const id = history[0].id
  history = H.addEntry(history, { type: "text", text: "b" }, 500, NOW + 1000)

  const pinned = H.setPinned(history, id, true, NOW + 2000)
  assert.deepEqual(pinned.map(e => e.text), ["b", "a"])
  assert.equal(pinned[1].pinned, true)
  assert.equal(pinned[1].createdAt, ISO)

  const unpinned = H.setPinned(pinned, id, false, NOW + 3000)
  assert.deepEqual(unpinned.map(e => e.text), ["b", "a"])
  assert.equal(unpinned[1].pinned, false)
})

test("deleted pinned entries restore with pin state and position", () => {
  let history = H.addEntry([], { type: "text", text: "a" }, 500, NOW)
  history = H.addEntry(history, { type: "text", text: "b", pinned: true }, 500, NOW + 1000)
  history = H.addEntry(history, { type: "text", text: "c" }, 500, NOW + 2000)

  const removed = H.removeEntryById(history, history[1].id)
  assert.equal(removed.index, 1)
  assert.equal(removed.removed.pinned, true)

  const restored = H.restoreEntry(removed.history, removed.removed, removed.index)
  assert.deepEqual(restored.map(e => e.text), ["c", "b", "a"])
  assert.equal(restored[1].pinned, true)
  assert.equal(restored[1].createdAt, new Date(NOW + 1000).toISOString())
})

test("serialize keeps pinned entries outside the unpinned limit", () => {
  const history = [
    { type: "text", text: "pinned", pinned: true },
    { type: "text", text: "u0", pinned: false },
    { type: "text", text: "u1", pinned: false },
    { type: "text", text: "u2", pinned: false }
  ]
  const out = JSON.parse(H.serialize(history, 2))
  assert.equal(out.filter(e => e.pinned).length, 1)
  assert.equal(out.filter(e => !e.pinned).length, 2)
  assert.deepEqual(out.filter(e => !e.pinned).map(e => e.text), ["u0", "u1"])
})

test("displayRows supports unified all/history/pinned and text/image filters", () => {
  const h = [
    { id: "t1", type: "text", text: "alpha", pinned: false },
    { id: "i1", type: "image", path: "/tmp/a.png", mime: "image/png", pinned: true },
    { id: "t2", type: "text", text: "beta", pinned: true }
  ]
  assert.deepEqual(H.displayRows(h, "", 50, null, null, null, "all", "all").map(r => r.id), ["t1", "i1", "t2"])
  assert.deepEqual(H.displayRows(h, "", 50, null, null, null, "all", "text").map(r => r.id), ["t1", "t2"])
  assert.deepEqual(H.displayRows(h, "", 50, null, null, null, "all", "image").map(r => r.id), ["i1"])
  assert.deepEqual(H.displayRows(h, "", 50, null, null, null, "pinned", "text").map(r => r.id), ["t2"])
})

test("highlightText escapes HTML and highlights matched query safely", () => {
  const out = H.highlightText("<script>alert(1)</script> foo", "foo", "#abcdef")
  assert.equal(out.includes("<script>"), false)
  assert.equal(out.includes("&lt;script&gt;"), true)
  assert.equal(out.includes('<b><font color="#abcdef">foo</font></b>'), true)
})

test("the bundled English catalog defines every key the UI looks up", () => {
  const catalog = require("../i18n/en.json")
  const keys = [
    "common.cancel", "common.confirm", "common.delete", "common.search",
    "common.noMatchesFor", "clipboard.search", "clipboard.empty",
    "clipboard.deleteHistory", "clipboard.files", "clipboard.image",
    "clipboard.imageFrom", "clipboard.screenshotFrom"
  ]
  for (const key of keys) {
    assert.ok(catalog[key] !== undefined, "missing catalog key: " + key)
  }
  assert.equal(catalog["clipboard.files"].one, "%1 file")
  assert.equal(catalog["clipboard.files"].other, "%1 files")
})
