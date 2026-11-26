const test = require("node:test")
const assert = require("node:assert/strict")
const KB = require("../Keybindings.js")

test("defaultConfig has no conflicts and separates Normal and Vim profiles", () => {
  const cfg = KB.defaultConfig()
  assert.deepEqual(KB.detectConflicts(cfg), [])
  assert.equal(cfg.normal.undo, "Ctrl+Z")
  assert.equal(cfg.vim.undo, "u")

  const updated = KB.setBinding(cfg, "normal", "undo", "Ctrl+U")
  assert.equal(updated.config.normal.undo, "Ctrl+U")
  assert.equal(updated.config.vim.undo, "u")
})

test("normalizeCombo canonicalizes modifier order and key names", () => {
  assert.equal(KB.normalizeCombo("shift+ctrl+z"), "Ctrl+Shift+Z")
  assert.equal(KB.normalizeCombo("super + v"), "Super+V")
  assert.equal(KB.normalizeCombo("del"), "Delete")
  assert.equal(KB.normalizeCombo("f3"), "F3")
})

test("detectConflicts reports duplicate combos within and across global/app scopes", () => {
  const cfg = KB.defaultConfig()
  const res = KB.setBinding(cfg, "app", "togglePin", "Ctrl+Z")
  assert.equal(res.conflicts.length, 1)
  assert.equal(res.conflicts[0].scopeA, "app")
  assert.equal(res.conflicts[0].combo, "Ctrl+Z")

  const globalConflict = KB.setBinding(cfg, "app", "startOcr", "Super+V")
  assert.equal(globalConflict.conflicts.some(c => c.scopeA === "global" && c.scopeB === "app"), true)
})

test("parseConfig merges partial JSON and preserves defaults", () => {
  const parsed = KB.parseConfig(JSON.stringify({ app: { togglePin: "ctrl+b" } }))
  assert.equal(parsed.app.togglePin, "Ctrl+B")
  assert.equal(parsed.app.switchPanel, "Tab")
  assert.equal(parsed.global.openClipboard, "Super+V")
})
