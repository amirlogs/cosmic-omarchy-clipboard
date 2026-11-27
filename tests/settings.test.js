const test = require("node:test")
const assert = require("node:assert/strict")
const S = require("../SettingsStore.js")

test("parseSettings handles invalid JSON and clamps invalid numbers safely", () => {
  const fallback = S.parseSettings("{bad json")
  assert.deepEqual(fallback, S.defaultSettings())

  const clamped = S.parseSettings(JSON.stringify({
    general: { defaultTab: "bogus", closeOnCopy: false },
    clipboard: { historyLimit: -5, autoCleanupHours: -10 },
    appearance: { backgroundOpacity: 0.1, cornerRadius: 99 },
    editor: { vimMode: true, normalCursorStyle: "underline", insertCursorStyle: "block", cursorStyle: "line", fontSize: 50 }
  }))
  assert.equal(clamped.general.defaultTab, "history")
  assert.equal(clamped.general.closeOnCopy, false)
  assert.equal(clamped.clipboard.historyLimit, -1)
  assert.equal(clamped.clipboard.autoCleanupHours, 0)
  assert.equal(clamped.appearance.backgroundOpacity, 0.65)
  assert.equal(clamped.appearance.cornerRadius, 24)
  assert.equal(clamped.editor.vimMode, true)
  assert.equal(clamped.editor.normalCursorStyle, "underline")
  assert.equal(clamped.editor.insertCursorStyle, "block")
  assert.equal(clamped.editor.cursorStyle, "line")
  assert.equal(clamped.editor.fontSize, 24)
})

test("serializeSettings round-trips valid settings", () => {
  const s = S.defaultSettings()
  s.editor.vimMode = true
  s.editor.normalCursorStyle = "line"
  s.editor.insertCursorStyle = "underline"
  s.ocr.languages = "eng+amh"
  const round = S.parseSettings(S.serializeSettings(s))
  assert.deepEqual(round, s)
})

test("cursor styles default to block for normal and line for insert with fallback", () => {
  const def = S.defaultSettings()
  assert.equal(def.editor.normalCursorStyle, "block")
  assert.equal(def.editor.insertCursorStyle, "line")

  const invalid = S.parseSettings({
    editor: { normalCursorStyle: "invalid_shape", insertCursorStyle: "bad_cursor" }
  })
  assert.equal(invalid.editor.normalCursorStyle, "block")
  assert.equal(invalid.editor.insertCursorStyle, "line")
})

test("autoPaste defaults to false and validates boolean", () => {
  const def = S.defaultSettings()
  assert.equal(def.general.autoPaste, false)

  const parsed = S.parseSettings(JSON.stringify({
    general: { autoPaste: true }
  }))
  assert.equal(parsed.general.autoPaste, true)

  const invalid = S.parseSettings(JSON.stringify({
    general: { autoPaste: "not-a-boolean" }
  }))
  assert.equal(invalid.general.autoPaste, false)
})
