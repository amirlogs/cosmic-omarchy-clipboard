const test = require("node:test")
const assert = require("node:assert/strict")
const Editor = require("../EditorEngine.js")
const Vim = require("../VimEngine.js")

function press(vim, editor, text, opts = {}) {
  return Vim.handleKey(vim, editor, {
    text,
    keyName: opts.keyName || "",
    ctrl: !!opts.ctrl,
    shift: !!opts.shift,
    alt: !!opts.alt
  }, Editor)
}

test("normal mode motions: h,j,k,l,w,b,e,0,$,gg,G", () => {
  const ed = Editor.createState("one two three\nalpha beta", "e1")
  const vim = Vim.createVimState()

  press(vim, ed, "w")
  assert.equal(ed.cursor, 4) // 't' in two
  press(vim, ed, "e")
  assert.equal(ed.cursor, 6) // 'o' in two
  press(vim, ed, "b")
  assert.equal(ed.cursor, 4)
  press(vim, ed, "$")
  assert.equal(ed.cursor, 12) // 'e' in three
  press(vim, ed, "0")
  assert.equal(ed.cursor, 0)
  press(vim, ed, "j")
  assert.equal(ed.cursor, 14) // 'a' in alpha
  press(vim, ed, "k")
  assert.equal(ed.cursor, 0)
  press(vim, ed, "G")
  assert.equal(ed.cursor, ed.text.length)
  press(vim, ed, "g")
  press(vim, ed, "g")
  assert.equal(ed.cursor, 0)
})

test("insert mode entry (i,a,I,A), jk exit, and undo/redo (u, Ctrl+r)", () => {
  const ed = Editor.createState("hello", "e1")
  const vim = Vim.createVimState({ jkExit: true })

  press(vim, ed, "A")
  assert.equal(vim.mode, "insert")
  press(vim, ed, "!")
  press(vim, ed, "j")
  press(vim, ed, "k")
  assert.equal(vim.mode, "normal")
  assert.equal(ed.text, "hello!")

  press(vim, ed, "u")
  assert.equal(ed.text, "hello")
  press(vim, ed, "r", { ctrl: true })
  assert.equal(ed.text, "hello!")
})

test("dd, yy, p, P, and x operate with linewise and charwise registers", () => {
  const ed = Editor.createState("first\nsecond\nthird", "e1")
  const vim = Vim.createVimState()

  press(vim, ed, "j")
  press(vim, ed, "y")
  const yRes = press(vim, ed, "y")
  assert.equal(yRes.yankText, "second\n")

  press(vim, ed, "d")
  press(vim, ed, "d")
  assert.equal(ed.text, "first\nthird")

  press(vim, ed, "p")
  assert.equal(ed.text, "first\nthird\nsecond")
})

test("visual and visual line modes yank and delete selections", () => {
  const ed = Editor.createState("abc def\nghi jkl", "e1")
  const vim = Vim.createVimState()

  press(vim, ed, "v")
  press(vim, ed, "l")
  press(vim, ed, "l")
  const yRes = press(vim, ed, "y")
  assert.equal(yRes.yankText, "abc")
  assert.equal(vim.mode, "normal")

  press(vim, ed, "V")
  press(vim, ed, "d")
  assert.equal(ed.text, "ghi jkl")
})

test("visual block mode (Ctrl+v) extracts rectangular column", () => {
  const ed = Editor.createState("1234\nabcd\nwxyz", "e1")
  const vim = Vim.createVimState()

  press(vim, ed, "l")
  press(vim, ed, "v", { ctrl: true })
  press(vim, ed, "j")
  press(vim, ed, "l")
  const yRes = press(vim, ed, "y")
  assert.equal(yRes.yankText, "23\nbc")
  assert.equal(vim.mode, "normal")
})

test("search mode (/) with n and N navigation", () => {
  const ed = Editor.createState("cat dog cat bird cat", "e1")
  const vim = Vim.createVimState()

  press(vim, ed, "/")
  assert.equal(vim.mode, "search")
  press(vim, ed, "c")
  press(vim, ed, "a")
  press(vim, ed, "t")
  press(vim, ed, "", { keyName: "Return" })
  assert.equal(vim.mode, "normal")
  assert.equal(ed.cursor, 0)

  press(vim, ed, "n")
  assert.equal(ed.cursor, 8)
  press(vim, ed, "N")
  assert.equal(ed.cursor, 0)
})

test("text objects and operator-motions: ciw, diw, daw, ci\", ci(, cw, dw, C, D, o, O, r, f, J", () => {
  const ed = Editor.createState('say "hello world" (foo bar)', "e1")
  const vim = Vim.createVimState()

  // Jump to 'hello' via f" + l -> ciw
  press(vim, ed, "f")
  press(vim, ed, '"')
  press(vim, ed, "l")
  press(vim, ed, "c")
  press(vim, ed, "i")
  press(vim, ed, "w")
  assert.equal(vim.mode, "insert")
  assert.equal(ed.text, 'say " world" (foo bar)')
  press(vim, ed, "h")
  press(vim, ed, "i")
  press(vim, ed, "", { keyName: "Escape" })
  assert.equal(ed.text, 'say "hi world" (foo bar)')

  // ci" replaces inside quotes
  press(vim, ed, "c")
  press(vim, ed, "i")
  press(vim, ed, '"')
  assert.equal(vim.mode, "insert")
  assert.equal(ed.text, 'say "" (foo bar)')
  press(vim, ed, "o")
  press(vim, ed, "k")
  press(vim, ed, "", { keyName: "Escape" })
  assert.equal(ed.text, 'say "ok" (foo bar)')

  // di( inside parens
  press(vim, ed, "f")
  press(vim, ed, "(")
  press(vim, ed, "l")
  press(vim, ed, "d")
  press(vim, ed, "i")
  press(vim, ed, "(")
  assert.equal(vim.mode, "normal")
  assert.equal(ed.text, 'say "ok" ()')

  // r<char>, o, J
  press(vim, ed, "0")
  press(vim, ed, "r")
  press(vim, ed, "S")
  assert.equal(ed.text, 'Say "ok" ()')
  press(vim, ed, "o")
  press(vim, ed, "n")
  press(vim, ed, "e")
  press(vim, ed, "x")
  press(vim, ed, "t")
  press(vim, ed, "", { keyName: "Escape" })
  assert.equal(ed.text, 'Say "ok" ()\nnext')
  press(vim, ed, "k")
  press(vim, ed, "J")
  assert.equal(ed.text, 'Say "ok" () next')
})

test("cw, dw, C, D, cc, viw work as expected", () => {
  const ed = Editor.createState("alpha beta gamma", "e1")
  const vim = Vim.createVimState()

  // cw preserves trailing space
  press(vim, ed, "c")
  press(vim, ed, "w")
  assert.equal(vim.mode, "insert")
  assert.equal(ed.text, " beta gamma")
  press(vim, ed, "A")
  press(vim, ed, "", { keyName: "Escape" })
  assert.equal(ed.text, "A beta gamma")

  // w then D deletes to end of line
  press(vim, ed, "w")
  press(vim, ed, "D")
  assert.equal(ed.text, "A ")

  // viw selects word in visual mode
  const ed2 = Editor.createState("one two three", "e2")
  const vim2 = Vim.createVimState()
  press(vim2, ed2, "w")
  press(vim2, ed2, "v")
  press(vim2, ed2, "i")
  press(vim2, ed2, "w")
  const y = press(vim2, ed2, "y")
  assert.equal(y.yankText, "two")
})
