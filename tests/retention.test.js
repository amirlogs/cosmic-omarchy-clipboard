const test = require("node:test")
const assert = require("node:assert/strict")
const H = require("../ClipboardHistory.js")

test("applyLimit(-1) supports unlimited history", () => {
  const items = Array.from({ length: 10 }, (_, i) => ({
    id: `e${i}`,
    type: "text",
    text: `item ${i}`,
    pinned: false
  }))
  const res = H.applyLimit(items, -1)
  assert.equal(res.length, 10)
})

test("pruneByAge removes old unpinned entries while protecting pinned entries", () => {
  const now = Date.parse("2026-11-26T20:00:00Z")
  const old = "2026-11-20T10:00:00Z"
  const fresh = "2026-11-26T19:00:00Z"
  const h = [
    { id: "old_unpinned", type: "text", text: "a", pinned: false, lastUsedAt: old },
    { id: "old_pinned", type: "text", text: "b", pinned: true, lastUsedAt: old },
    { id: "new_unpinned", type: "text", text: "c", pinned: false, lastUsedAt: fresh }
  ]
  const res = H.pruneByAge(h, 24, now)
  assert.deepEqual(res.map(e => e.id), ["old_pinned", "new_unpinned"])
})

test("pruneBeforeDate and pruneInRange protect pinned entries", () => {
  const h = [
    { id: "e1", type: "text", text: "a", pinned: false, lastUsedAt: "2026-11-01T00:00:00Z" },
    { id: "e2", type: "text", text: "b", pinned: true, lastUsedAt: "2026-11-01T00:00:00Z" },
    { id: "e3", type: "text", text: "c", pinned: false, lastUsedAt: "2026-11-15T00:00:00Z" },
    { id: "e4", type: "text", text: "d", pinned: false, lastUsedAt: "2026-11-25T00:00:00Z" }
  ]
  const before = H.pruneBeforeDate(h, "2026-11-10T00:00:00Z")
  assert.deepEqual(before.map(e => e.id), ["e2", "e3", "e4"])

  const ranged = H.pruneInRange(h, "2026-11-01T00:00:00Z", "2026-11-16T00:00:00Z")
  assert.deepEqual(ranged.map(e => e.id), ["e2", "e4"])
})
