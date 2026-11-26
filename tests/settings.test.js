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
    editor: { vimMode: true, cursorStyle: "line", fontSize: 50 }
  }))
  assert.equal(clamped.general.defaultTab, "history")
  assert.equal(clamped.general.closeOnCopy, false)
  assert.equal(clamped.clipboard.historyLimit, -1)
  assert.equal(clamped.clipboard.autoCleanupHours, 0)
  assert.equal(clamped.appearance.backgroundOpacity, 0.65)
  assert.equal(clamped.appearance.cornerRadius, 24)
  assert.equal(clamped.editor.vimMode, true)
  assert.equal(clamped.editor.cursorStyle, "line")
  assert.equal(clamped.editor.fontSize, 24)
})

test("serializeSettings round-trips valid settings", () => {
  const s = S.defaultSettings()
  s.editor.vimMode = true
  s.ocr.languages = "eng+amh"
  const round = S.parseSettings(S.serializeSettings(s))
  assert.deepEqual(round, s)
})
