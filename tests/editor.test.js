const test = require("node:test")
const assert = require("node:assert/strict")
const Editor = require("../EditorEngine.js")

test("cursor navigation across lines preserves preferred column", () => {
  const s = Editor.createState("hello world\nhi\nthird line", "e1")
  Editor.setCursor(s, 8, false) // line 0, col 8 ('r')
  assert.deepEqual(Editor.cursorLineCol(s.text, s.cursor), { line: 0, col: 8, totalLines: 3 })

  Editor.moveDown(s, false) // line 1 ("hi") clamps to col 2
  assert.deepEqual(Editor.cursorLineCol(s.text, s.cursor), { line: 1, col: 2, totalLines: 3 })

  Editor.moveDown(s, false) // line 2 restores col 8
  assert.deepEqual(Editor.cursorLineCol(s.text, s.cursor), { line: 2, col: 8, totalLines: 3 })

  Editor.moveUp(s, false)
  Editor.moveUp(s, false)
  assert.equal(s.cursor, 8)
})

test("word navigation and selection work predictably", () => {
  const s = Editor.createState("alpha beta_123 gamma", "e1")
  Editor.moveWordRight(s, false)
  assert.equal(s.cursor, 6) // start of beta_123

  Editor.moveWordRight(s, true)
  assert.equal(Editor.selectedText(s), "beta_123 ")

  Editor.moveWordLeft(s, false)
  assert.equal(s.cursor, 6)
  assert.equal(Editor.hasSelection(s), false)

  Editor.moveLineEnd(s, true)
  assert.equal(Editor.selectedText(s), "beta_123 gamma")

  Editor.moveLineStart(s, false)
  assert.equal(s.cursor, 0)
})

test("insertText replaces selection and coalesces word-char typing for undo/redo", () => {
  const s = Editor.createState("hello world", "e1")
  Editor.setCursor(s, 6, false)
  Editor.insertText(s, "b", true)
  Editor.insertText(s, "i", true)
  Editor.insertText(s, "g", true)
  Editor.insertText(s, " ", true) // whitespace commits transaction
  assert.equal(s.text, "hello big world")
  assert.equal(s.undoStack.length, 2)

  assert.equal(Editor.undo(s), true)
  assert.equal(s.text, "hello bigworld")
  assert.equal(Editor.undo(s), true)
  assert.equal(s.text, "hello world")

  assert.equal(Editor.redo(s), true)
  assert.equal(Editor.redo(s), true)
  assert.equal(s.text, "hello big world")
})

test("deleteBackward and deleteForward handle selections, words, and undo", () => {
  const s = Editor.createState("one two three", "e1")
  Editor.setSelection(s, 4, 8) // "two "
  Editor.deleteBackward(s, false, false)
  assert.equal(s.text, "one three")
  assert.equal(s.cursor, 4)

  Editor.undo(s)
  assert.equal(s.text, "one two three")

  Editor.setCursor(s, 4, false)
  Editor.deleteForward(s, true, false) // deletes "two "
  assert.equal(s.text, "one three")
})

test("in-editor search finds matches and wraps with nextMatch", () => {
  const s = Editor.createState("Foo bar foo baz FOO", "e1")
  Editor.setSearch(s, "foo")
  assert.equal(s.searchMatches.length, 3)
  assert.equal(s.searchIndex, 0)
  assert.equal(Editor.selectedText(s), "Foo")

  Editor.nextMatch(s, 1)
  assert.equal(s.searchIndex, 1)
  assert.equal(Editor.selectedText(s), "foo")

  Editor.nextMatch(s, 1)
  assert.equal(s.searchIndex, 2)
  assert.equal(Editor.selectedText(s), "FOO")

  Editor.nextMatch(s, 1)
  assert.equal(s.searchIndex, 0)

  Editor.nextMatch(s, -1)
  assert.equal(s.searchIndex, 2)
})
