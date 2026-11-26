// Pure-JS Vim modal editing engine operating on EditorEngine states.
// Portable between Node tests and Qt QML (receives EditorEngine as a parameter
// to avoid QML-only .import directives).

function createVimState(options) {
  var opts = options || {}
  return {
    mode: "normal", // normal | insert | visual | visual_line | visual_block | search
    pending: "",
    registerText: "",
    registerLinewise: false,
    visualAnchor: 0,
    blockAnchorLine: 0,
    blockAnchorCol: 0,
    searchBuffer: "",
    jkExit: opts.jkExit !== false,
    lastInsertChar: ""
  }
}

function resetVimState(vim, mode) {
  vim.mode = mode || "normal"
  vim.pending = ""
  vim.searchBuffer = ""
  vim.lastInsertChar = ""
  return vim
}

function isWordChar(ch) {
  return /[A-Za-z0-9_]/.test(ch)
}

function lineBoundsAt(text, pos) {
  var s = String(text || "")
  var p = Math.max(0, Math.min(pos, s.length))
  var start = s.lastIndexOf("\n", p - 1)
  start = start < 0 ? 0 : start + 1
  var end = s.indexOf("\n", p)
  if (end < 0) end = s.length
  return { start: start, end: end }
}

function wordEndPos(text, pos) {
  var s = String(text || "")
  var len = s.length
  var i = Math.max(0, Math.min(pos, len))
  if (i >= len - 1) return Math.max(0, len - 1)
  i++
  while (i < len && /\s/.test(s.charAt(i))) i++
  if (i >= len) return Math.max(0, len - 1)
  if (isWordChar(s.charAt(i))) {
    while (i + 1 < len && isWordChar(s.charAt(i + 1))) i++
  } else {
    while (i + 1 < len && !/\s/.test(s.charAt(i + 1)) && !isWordChar(s.charAt(i + 1))) i++
  }
  return i
}

function nextWordStartPos(text, pos) {
  var s = String(text || "")
  var len = s.length
  var i = Math.max(0, Math.min(pos, len))
  if (i >= len) return len
  if (isWordChar(s.charAt(i))) {
    while (i < len && isWordChar(s.charAt(i))) i++
  } else if (!/\s/.test(s.charAt(i))) {
    while (i < len && !/\s/.test(s.charAt(i)) && !isWordChar(s.charAt(i))) i++
  }
  while (i < len && /\s/.test(s.charAt(i))) i++
  return i
}

function prevWordStartPos(text, pos) {
  var s = String(text || "")
  var i = Math.max(0, Math.min(pos, s.length))
  while (i > 0 && /\s/.test(s.charAt(i - 1))) i--
  if (i === 0) return 0
  if (isWordChar(s.charAt(i - 1))) {
    while (i > 0 && isWordChar(s.charAt(i - 1))) i--
  } else {
    while (i > 0 && !/\s/.test(s.charAt(i - 1)) && !isWordChar(s.charAt(i - 1))) i--
  }
  return i
}

function lineColToOffset(text, line, col) {
  var lines = String(text || "").split("\n")
  var l = Math.max(0, Math.min(line, lines.length - 1))
  var offset = 0
  for (var i = 0; i < l; i++) offset += lines[i].length + 1
  return offset + Math.max(0, Math.min(col, lines[l].length))
}

function visualCharLineRange(vim, editor) {
  if (vim.mode === "visual_line") {
    var b1 = lineBoundsAt(editor.text, vim.visualAnchor)
    var b2 = lineBoundsAt(editor.text, editor.cursor)
    var start = Math.min(b1.start, b2.start)
    var end = Math.max(b1.end, b2.end)
    if (end < editor.text.length) end++
    return { start: start, end: end }
  }
  var a = vim.visualAnchor
  var c = editor.cursor
  var s = Math.min(a, c)
  var e = Math.min(editor.text.length, Math.max(a, c) + 1)
  return { start: s, end: e }
}

function applyVisualSelection(vim, editor, Editor) {
  if (vim.mode === "visual") {
    var a = vim.visualAnchor
    var c = editor.cursor
    if (c >= a) {
      Editor.setSelection(editor, a, Math.min(editor.text.length, c + 1))
      editor.cursor = c
    } else {
      Editor.setSelection(editor, Math.min(editor.text.length, a + 1), c)
      editor.cursor = c
    }
  } else if (vim.mode === "visual_line") {
    var b1 = lineBoundsAt(editor.text, vim.visualAnchor)
    var b2 = lineBoundsAt(editor.text, editor.cursor)
    var start = Math.min(b1.start, b2.start)
    var end = Math.max(b1.end, b2.end)
    if (end < editor.text.length) end++
    var cPos = editor.cursor
    Editor.setSelection(editor, start, end)
    editor.cursor = cPos
  } else if (vim.mode === "visual_block") {
    var lc = Editor.cursorLineCol(editor.text, editor.cursor)
    var minL = Math.min(vim.blockAnchorLine, lc.line)
    var maxL = Math.max(vim.blockAnchorLine, lc.line)
    var minC = Math.min(vim.blockAnchorCol, lc.col)
    var maxC = Math.max(vim.blockAnchorCol, lc.col)
    var sOff = lineColToOffset(editor.text, minL, minC)
    var eOff = Math.min(editor.text.length, lineColToOffset(editor.text, maxL, maxC) + 1)
    var cur = editor.cursor
    Editor.setSelection(editor, sOff, eOff)
    editor.cursor = cur
  }
}

function extractVisualBlockText(text, l1, l2, c1, c2) {
  var lines = String(text || "").split("\n")
  var minL = Math.max(0, Math.min(l1, l2))
  var maxL = Math.min(lines.length - 1, Math.max(l1, l2))
  var minC = Math.max(0, Math.min(c1, c2))
  var maxC = Math.max(c1, c2)
  var out = []
  for (var i = minL; i <= maxL; i++) {
    out.push(lines[i].slice(minC, maxC + 1))
  }
  return out.join("\n")
}

function deleteVisualBlock(editor, Editor, l1, l2, c1, c2) {
  var lines = String(editor.text || "").split("\n")
  var minL = Math.max(0, Math.min(l1, l2))
  var maxL = Math.min(lines.length - 1, Math.max(l1, l2))
  var minC = Math.max(0, Math.min(c1, c2))
  var maxC = Math.max(c1, c2)
  var removed = []
  for (var i = minL; i <= maxL; i++) {
    removed.push(lines[i].slice(minC, maxC + 1))
    lines[i] = lines[i].slice(0, minC) + lines[i].slice(maxC + 1)
  }
  Editor.selectAll(editor)
  Editor.insertText(editor, lines.join("\n"), false)
  Editor.setCursor(editor, lineColToOffset(editor.text, minL, minC), false)
  return removed.join("\n")
}

function firstNonBlankOnLine(text, pos) {
  var b = lineBoundsAt(text, pos)
  var i = b.start
  while (i < b.end && (text.charAt(i) === " " || text.charAt(i) === "\t")) i++
  return i
}

function findCharOnLine(text, pos, target, forward, till) {
  if (!target) return -1
  var b = lineBoundsAt(text, pos)
  if (forward) {
    for (var i = pos + 1; i < b.end; i++) {
      if (text.charAt(i) === target) return till ? i - 1 : i
    }
  } else {
    for (var j = pos - 1; j >= b.start; j--) {
      if (text.charAt(j) === target) return till ? j + 1 : j
    }
  }
  return -1
}

function wordObjectRange(text, pos, around) {
  var s = String(text || "")
  var len = s.length
  if (len === 0) return null
  var p = Math.max(0, Math.min(pos, len - 1))
  var ch = s.charAt(p)
  var start = p
  var end = p + 1

  if (isWordChar(ch)) {
    while (start > 0 && isWordChar(s.charAt(start - 1))) start--
    while (end < len && isWordChar(s.charAt(end))) end++
  } else if (!/\s/.test(ch)) {
    while (start > 0 && !/\s/.test(s.charAt(start - 1)) && !isWordChar(s.charAt(start - 1))) start--
    while (end < len && !/\s/.test(s.charAt(end)) && !isWordChar(s.charAt(end))) end++
  } else {
    while (start > 0 && /[ \t]/.test(s.charAt(start - 1))) start--
    while (end < len && /[ \t]/.test(s.charAt(end))) end++
  }

  if (around) {
    var b = lineBoundsAt(s, p)
    var trail = end
    while (trail < b.end && /[ \t]/.test(s.charAt(trail))) trail++
    if (trail > end) {
      end = trail
    } else {
      while (start > b.start && /[ \t]/.test(s.charAt(start - 1))) start--
    }
  }
  return { start: start, end: end }
}

function quoteObjectRange(text, pos, quote, around) {
  var b = lineBoundsAt(text, pos)
  var line = String(text || "").slice(b.start, b.end)
  var rel = Math.max(0, Math.min(pos - b.start, line.length))
  var quotes = []
  for (var i = 0; i < line.length; i++) {
    if (line.charAt(i) === quote && (i === 0 || line.charAt(i - 1) !== "\\")) {
      quotes.push(i)
    }
  }
  for (var q = 0; q + 1 < quotes.length; q += 2) {
    var q1 = quotes[q]
    var q2 = quotes[q + 1]
    if ((rel >= q1 && rel <= q2) || q1 > rel) {
      return around
        ? { start: b.start + q1, end: b.start + q2 + 1 }
        : { start: b.start + q1 + 1, end: b.start + q2 }
    }
  }
  return null
}

function pairObjectRange(text, pos, openCh, closeCh, around) {
  var s = String(text || "")
  var p = Math.max(0, Math.min(pos, s.length - 1))
  var depth = 0
  var openIdx = -1
  if (s.charAt(p) === openCh) {
    openIdx = p
  } else {
    for (var i = p; i >= 0; i--) {
      var c = s.charAt(i)
      if (c === closeCh && i !== p) depth++
      else if (c === openCh) {
        if (depth === 0) { openIdx = i; break }
        depth--
      }
    }
  }
  if (openIdx < 0) return null
  depth = 0
  var closeIdx = -1
  for (var j = openIdx + 1; j < s.length; j++) {
    var cj = s.charAt(j)
    if (cj === openCh) depth++
    else if (cj === closeCh) {
      if (depth === 0) { closeIdx = j; break }
      depth--
    }
  }
  if (closeIdx < 0) return null
  return around
    ? { start: openIdx, end: closeIdx + 1 }
    : { start: openIdx + 1, end: closeIdx }
}

function textObjectRange(text, pos, kind, obj) {
  var around = (kind === "a")
  if (obj === "w") return wordObjectRange(text, pos, around)
  if (obj === '"' || obj === "'" || obj === "`") return quoteObjectRange(text, pos, obj, around)
  if (obj === "(" || obj === ")" || obj === "b") return pairObjectRange(text, pos, "(", ")", around)
  if (obj === "[" || obj === "]") return pairObjectRange(text, pos, "[", "]", around)
  if (obj === "{" || obj === "}" || obj === "B") return pairObjectRange(text, pos, "{", "}", around)
  if (obj === "<" || obj === ">") return pairObjectRange(text, pos, "<", ">", around)
  return null
}

function applyOperatorOnRange(op, start, end, linewise, vim, editor, Editor, result) {
  var s = Math.max(0, Math.min(start, editor.text.length))
  var e = Math.max(s, Math.min(end, editor.text.length))
  if (op === "y") {
    vim.registerText = editor.text.slice(s, e)
    vim.registerLinewise = !!linewise
    result.yankText = vim.registerText
    Editor.setCursor(editor, s, false)
    return
  }
  vim.registerText = editor.text.slice(s, e)
  vim.registerLinewise = !!linewise
  if (e > s) {
    Editor.setSelection(editor, s, e)
    Editor.deleteBackward(editor, false, false)
    result.mutated = true
    result.commitImmediate = true
  } else {
    Editor.setCursor(editor, s, false)
  }
  if (op === "c") resetVimState(vim, "insert")
}

function runMotion(key, ctrl, vim, editor, Editor) {
  if (key === "h" || key === "Left") {
    Editor.setCursor(editor, editor.cursor - 1, false)
    return true
  }
  if (key === "l" || key === "Right") {
    Editor.setCursor(editor, editor.cursor + 1, false)
    return true
  }
  if (key === "j" || key === "Down") {
    Editor.moveDown(editor, false)
    return true
  }
  if (key === "k" || key === "Up") {
    Editor.moveUp(editor, false)
    return true
  }
  if (key === "w") {
    Editor.setCursor(editor, nextWordStartPos(editor.text, editor.cursor), false)
    return true
  }
  if (key === "b") {
    Editor.setCursor(editor, prevWordStartPos(editor.text, editor.cursor), false)
    return true
  }
  if (key === "e") {
    Editor.setCursor(editor, wordEndPos(editor.text, editor.cursor), false)
    return true
  }
  if (key === "0" || key === "Home") {
    Editor.moveLineStart(editor, false)
    return true
  }
  if (key === "^") {
    Editor.setCursor(editor, firstNonBlankOnLine(editor.text, editor.cursor), false)
    return true
  }
  if (key === "$" || key === "End") {
    var b = lineBoundsAt(editor.text, editor.cursor)
    var target = vim.mode === "normal" && b.end > b.start ? b.end - 1 : b.end
    Editor.setCursor(editor, target, false)
    return true
  }
  if (key === "G") {
    Editor.moveDocEnd(editor, false)
    return true
  }
  return false
}

// event: { keyName: string, text: string, ctrl: bool, shift: bool, alt: bool }
// Returns { handled: bool, mutated: bool, commitImmediate: bool, yankText: string }
function handleKey(vim, editor, event, Editor) {
  var result = { handled: true, mutated: false, commitImmediate: false, yankText: "" }
  var keyName = String(event.keyName || "")
  var ch = String(event.text || "")
  var ctrl = !!event.ctrl
  var alt = !!event.alt

  // Search mode ('/')
  if (vim.mode === "search") {
    if (keyName === "Escape") {
      resetVimState(vim, "normal")
      return result
    }
    if (keyName === "Return" || keyName === "Enter") {
      Editor.setSearch(editor, vim.searchBuffer)
      Editor.setCursor(editor, editor.anchor, false)
      resetVimState(vim, "normal")
      return result
    }
    if (keyName === "Backspace") {
      vim.searchBuffer = vim.searchBuffer.slice(0, -1)
      return result
    }
    if (!ctrl && !alt && ch.length === 1 && ch.charCodeAt(0) >= 32 && ch.charCodeAt(0) !== 127) {
      vim.searchBuffer += ch
      return result
    }
    return result
  }

  // Insert mode
  if (vim.mode === "insert") {
    if (keyName === "Escape") {
      Editor.commitTransaction(editor)
      if (editor.cursor > 0 && editor.text.charAt(editor.cursor - 1) !== "\n") {
        Editor.moveLeft(editor, false)
      }
      resetVimState(vim, "normal")
      result.commitImmediate = true
      return result
    }
    if (keyName === "Left") { vim.lastInsertChar = ""; Editor.moveLeft(editor, false); return result }
    if (keyName === "Right") { vim.lastInsertChar = ""; Editor.moveRight(editor, false); return result }
    if (keyName === "Up") { vim.lastInsertChar = ""; Editor.moveUp(editor, false); return result }
    if (keyName === "Down") { vim.lastInsertChar = ""; Editor.moveDown(editor, false); return result }
    if (keyName === "Home") { vim.lastInsertChar = ""; Editor.moveLineStart(editor, false); return result }
    if (keyName === "End") { vim.lastInsertChar = ""; Editor.moveLineEnd(editor, false); return result }
    if (keyName === "Backspace") {
      vim.lastInsertChar = ""
      Editor.deleteBackward(editor, ctrl, !ctrl)
      result.mutated = true
      return result
    }
    if (keyName === "Delete") {
      vim.lastInsertChar = ""
      Editor.deleteForward(editor, ctrl, !ctrl)
      result.mutated = true
      return result
    }
    if (keyName === "Return" || keyName === "Enter") {
      vim.lastInsertChar = ""
      Editor.insertText(editor, "\n", false)
      result.mutated = true
      return result
    }
    if (!ctrl && !alt && ch.length === 1 && ch.charCodeAt(0) >= 32 && ch.charCodeAt(0) !== 127) {
      if (vim.jkExit && vim.lastInsertChar === "j" && ch === "k") {
        // Revert the 'j' insertion cleanly without polluting the undo stack.
        if (editor.cursor > 0 && editor.text.charAt(editor.cursor - 1) === "j") {
          editor.text = editor.text.slice(0, editor.cursor - 1) + editor.text.slice(editor.cursor)
          editor.cursor = editor.cursor - 1
          editor.anchor = editor.cursor
          editor.dirty = true
        }
        Editor.commitTransaction(editor)
        if (editor.cursor > 0 && editor.text.charAt(editor.cursor - 1) !== "\n") {
          Editor.setCursor(editor, editor.cursor - 1, false)
        }
        resetVimState(vim, "normal")
        result.mutated = true
        result.commitImmediate = true
        return result
      }
      vim.lastInsertChar = ch
      Editor.insertText(editor, ch, true)
      result.mutated = true
      return result
    }
    return result
  }

  // Visual modes
  if (vim.mode === "visual" || vim.mode === "visual_line" || vim.mode === "visual_block") {
    if (keyName === "Escape") {
      Editor.setCursor(editor, editor.cursor, false)
      resetVimState(vim, "normal")
      return result
    }
    if (vim.pending === "g" && ch === "g") {
      vim.pending = ""
      Editor.moveDocStart(editor, false)
      applyVisualSelection(vim, editor, Editor)
      return result
    }
    if (vim.pending === "i" || vim.pending === "a") {
      var vObj = textObjectRange(editor.text, editor.cursor, vim.pending, ch)
      vim.pending = ""
      if (vObj && vObj.end > vObj.start) {
        vim.visualAnchor = vObj.start
        Editor.setCursor(editor, vObj.end - 1, false)
        applyVisualSelection(vim, editor, Editor)
      }
      return result
    }
    if (vim.pending === "f" || vim.pending === "F" || vim.pending === "t" || vim.pending === "T") {
      var vFind = findCharOnLine(editor.text, editor.cursor, ch, vim.pending === "f" || vim.pending === "t", vim.pending === "t" || vim.pending === "T")
      vim.pending = ""
      if (vFind >= 0) {
        Editor.setCursor(editor, vFind, false)
        applyVisualSelection(vim, editor, Editor)
      }
      return result
    }
    if (ch === "g" || ch === "i" || ch === "a" || ch === "f" || ch === "F" || ch === "t" || ch === "T") {
      vim.pending = ch
      return result
    }
    vim.pending = ""

    var motionKey = ch || keyName
    if (runMotion(motionKey, ctrl, vim, editor, Editor)) {
      applyVisualSelection(vim, editor, Editor)
      return result
    }

    if (ch === "y") {
      if (vim.mode === "visual_block") {
        var lcY = Editor.cursorLineCol(editor.text, editor.cursor)
        vim.registerText = extractVisualBlockText(editor.text, vim.blockAnchorLine, lcY.line, vim.blockAnchorCol, lcY.col)
        vim.registerLinewise = false
      } else {
        var rY = visualCharLineRange(vim, editor)
        vim.registerText = editor.text.slice(rY.start, rY.end)
        vim.registerLinewise = (vim.mode === "visual_line")
      }
      result.yankText = vim.registerText
      Editor.setCursor(editor, Math.min(editor.anchor, editor.cursor), false)
      resetVimState(vim, "normal")
      return result
    }

    if (ch === "d" || ch === "x" || ch === "c") {
      if (vim.mode === "visual_block") {
        var lcD = Editor.cursorLineCol(editor.text, editor.cursor)
        vim.registerText = deleteVisualBlock(editor, Editor, vim.blockAnchorLine, lcD.line, vim.blockAnchorCol, lcD.col)
        vim.registerLinewise = false
      } else {
        var rD = visualCharLineRange(vim, editor)
        Editor.setSelection(editor, rD.start, rD.end)
        vim.registerText = Editor.selectedText(editor)
        vim.registerLinewise = (vim.mode === "visual_line")
        Editor.deleteBackward(editor, false, false)
      }
      result.mutated = true
      result.commitImmediate = true
      resetVimState(vim, ch === "c" ? "insert" : "normal")
      return result
    }
    return result
  }

  // Normal mode
  if (keyName === "Escape") {
    vim.pending = ""
    Editor.setCursor(editor, editor.cursor, false)
    return result
  }

  // Multi-key sequences: operators (d, c, y), g, r, f/F/t/T
  if (vim.pending === "r") {
    vim.pending = ""
    if (!ctrl && !alt && ch.length === 1 && ch.charCodeAt(0) >= 32 && ch.charCodeAt(0) !== 127) {
      var lbR = lineBoundsAt(editor.text, editor.cursor)
      if (editor.cursor < lbR.end) {
        Editor.setSelection(editor, editor.cursor, editor.cursor + 1)
        Editor.insertText(editor, ch, false)
        Editor.setCursor(editor, Math.max(lbR.start, editor.cursor - 1), false)
        result.mutated = true
        result.commitImmediate = true
      }
    }
    return result
  }
  if (vim.pending === "f" || vim.pending === "F" || vim.pending === "t" || vim.pending === "T") {
    var fPos = findCharOnLine(editor.text, editor.cursor, ch, vim.pending === "f" || vim.pending === "t", vim.pending === "t" || vim.pending === "T")
    vim.pending = ""
    if (fPos >= 0) Editor.setCursor(editor, fPos, false)
    return result
  }
  if (vim.pending === "g") {
    vim.pending = ""
    if (ch === "g") {
      Editor.moveDocStart(editor, false)
      return result
    }
  } else if (vim.pending.length === 2 && (vim.pending.charAt(0) === "d" || vim.pending.charAt(0) === "c" || vim.pending.charAt(0) === "y")) {
    var op2 = vim.pending.charAt(0)
    var sub2 = vim.pending.charAt(1)
    vim.pending = ""
    if (sub2 === "i" || sub2 === "a") {
      var objR = textObjectRange(editor.text, editor.cursor, sub2, ch)
      if (objR) applyOperatorOnRange(op2, objR.start, objR.end, false, vim, editor, Editor, result)
      return result
    }
    if (sub2 === "f" || sub2 === "F" || sub2 === "t" || sub2 === "T") {
      var fwd2 = (sub2 === "f" || sub2 === "t")
      var till2 = (sub2 === "t" || sub2 === "T")
      var hit2 = findCharOnLine(editor.text, editor.cursor, ch, fwd2, till2)
      if (hit2 >= 0) {
        var rS = fwd2 ? editor.cursor : hit2
        var rE = fwd2 ? hit2 + 1 : editor.cursor
        applyOperatorOnRange(op2, rS, rE, false, vim, editor, Editor, result)
      }
      return result
    }
    if (sub2 === "g" && ch === "g") {
      applyOperatorOnRange(op2, 0, editor.cursor, false, vim, editor, Editor, result)
      return result
    }
    return result
  } else if (vim.pending === "d" || vim.pending === "c" || vim.pending === "y") {
    var op1 = vim.pending
    if (ch === "i" || ch === "a" || ch === "f" || ch === "F" || ch === "t" || ch === "T" || ch === "g") {
      vim.pending = op1 + ch
      return result
    }
    vim.pending = ""
    if (ch === op1) {
      var bLine = lineBoundsAt(editor.text, editor.cursor)
      if (op1 === "c") {
        applyOperatorOnRange("c", bLine.start, bLine.end, false, vim, editor, Editor, result)
      } else if (op1 === "y") {
        vim.registerText = editor.text.slice(bLine.start, bLine.end) + "\n"
        vim.registerLinewise = true
        result.yankText = vim.registerText
      } else {
        var endD = bLine.end < editor.text.length ? bLine.end + 1 : bLine.end
        var startD = bLine.start > 0 && endD === editor.text.length && bLine.end === editor.text.length ? bLine.start - 1 : bLine.start
        vim.registerText = editor.text.slice(bLine.start, bLine.end) + "\n"
        vim.registerLinewise = true
        Editor.setSelection(editor, startD, endD)
        Editor.deleteBackward(editor, false, false)
        result.mutated = true
        result.commitImmediate = true
      }
      return result
    }
    if (ch === "w") {
      var wEnd = op1 === "c"
        ? (isWordChar(editor.text.charAt(editor.cursor)) || !/\s/.test(editor.text.charAt(editor.cursor)) ? wordObjectRange(editor.text, editor.cursor, false).end : nextWordStartPos(editor.text, editor.cursor))
        : nextWordStartPos(editor.text, editor.cursor)
      applyOperatorOnRange(op1, editor.cursor, wEnd, false, vim, editor, Editor, result)
      return result
    }
    if (ch === "e") {
      var ePos = wordEndPos(editor.text, editor.cursor)
      applyOperatorOnRange(op1, editor.cursor, Math.min(editor.text.length, ePos + 1), false, vim, editor, Editor, result)
      return result
    }
    if (ch === "b") {
      var bPos = prevWordStartPos(editor.text, editor.cursor)
      applyOperatorOnRange(op1, bPos, editor.cursor, false, vim, editor, Editor, result)
      return result
    }
    if (ch === "$") {
      var bDol = lineBoundsAt(editor.text, editor.cursor)
      applyOperatorOnRange(op1, editor.cursor, bDol.end, false, vim, editor, Editor, result)
      return result
    }
    if (ch === "0") {
      var bZero = lineBoundsAt(editor.text, editor.cursor)
      applyOperatorOnRange(op1, bZero.start, editor.cursor, false, vim, editor, Editor, result)
      return result
    }
    if (ch === "^") {
      var fnb = firstNonBlankOnLine(editor.text, editor.cursor)
      applyOperatorOnRange(op1, Math.min(fnb, editor.cursor), Math.max(fnb, editor.cursor), false, vim, editor, Editor, result)
      return result
    }
    if (ch === "G") {
      applyOperatorOnRange(op1, editor.cursor, editor.text.length, false, vim, editor, Editor, result)
      return result
    }
    return result
  }

  if (ctrl && (ch === "r" || keyName === "R")) {
    if (Editor.redo(editor)) {
      result.mutated = true
      result.commitImmediate = true
    }
    return result
  }
  if (ctrl && (ch === "v" || keyName === "V")) {
    var lcB = Editor.cursorLineCol(editor.text, editor.cursor)
    vim.mode = "visual_block"
    vim.blockAnchorLine = lcB.line
    vim.blockAnchorCol = lcB.col
    applyVisualSelection(vim, editor, Editor)
    return result
  }

  if (ch === "g" || ch === "d" || ch === "c" || ch === "y" || ch === "r" || ch === "f" || ch === "F" || ch === "t" || ch === "T") {
    vim.pending = ch
    return result
  }

  var nMotion = ch || keyName
  if (runMotion(nMotion, ctrl, vim, editor, Editor)) return result

  if (ch === "u") {
    if (Editor.undo(editor)) {
      result.mutated = true
      result.commitImmediate = true
    }
    return result
  }
  if (ch === "x") {
    var lbX = lineBoundsAt(editor.text, editor.cursor)
    if (editor.cursor < lbX.end) {
      vim.registerText = editor.text.charAt(editor.cursor)
      vim.registerLinewise = false
      Editor.deleteForward(editor, false, false)
      result.mutated = true
      result.commitImmediate = true
    }
    return result
  }
  if (ch === "X") {
    var lbXb = lineBoundsAt(editor.text, editor.cursor)
    if (editor.cursor > lbXb.start) {
      vim.registerText = editor.text.charAt(editor.cursor - 1)
      vim.registerLinewise = false
      Editor.deleteBackward(editor, false, false)
      result.mutated = true
      result.commitImmediate = true
    }
    return result
  }
  if (ch === "s") {
    var lbS = lineBoundsAt(editor.text, editor.cursor)
    applyOperatorOnRange("c", editor.cursor, Math.min(lbS.end, editor.cursor + 1), false, vim, editor, Editor, result)
    return result
  }
  if (ch === "S") {
    var lbSb = lineBoundsAt(editor.text, editor.cursor)
    applyOperatorOnRange("c", lbSb.start, lbSb.end, false, vim, editor, Editor, result)
    return result
  }
  if (ch === "C" || ch === "D") {
    var lbCD = lineBoundsAt(editor.text, editor.cursor)
    applyOperatorOnRange(ch === "C" ? "c" : "d", editor.cursor, lbCD.end, false, vim, editor, Editor, result)
    return result
  }
  if (ch === "Y") {
    var lbY = lineBoundsAt(editor.text, editor.cursor)
    vim.registerText = editor.text.slice(lbY.start, lbY.end) + "\n"
    vim.registerLinewise = true
    result.yankText = vim.registerText
    return result
  }
  if (ch === "J") {
    var lbJ = lineBoundsAt(editor.text, editor.cursor)
    if (lbJ.end < editor.text.length) {
      var nextStart = lbJ.end + 1
      var nextNonBlank = nextStart
      while (nextNonBlank < editor.text.length && (editor.text.charAt(nextNonBlank) === " " || editor.text.charAt(nextNonBlank) === "\t")) nextNonBlank++
      Editor.setSelection(editor, lbJ.end, nextNonBlank)
      Editor.insertText(editor, " ", false)
      Editor.setCursor(editor, lbJ.end, false)
      result.mutated = true
      result.commitImmediate = true
    }
    return result
  }
  if (ch === "o") {
    var lbO = lineBoundsAt(editor.text, editor.cursor)
    Editor.setCursor(editor, lbO.end, false)
    Editor.insertText(editor, "\n", false)
    resetVimState(vim, "insert")
    result.mutated = true
    return result
  }
  if (ch === "O") {
    var lbOb = lineBoundsAt(editor.text, editor.cursor)
    Editor.setCursor(editor, lbOb.start, false)
    Editor.insertText(editor, "\n", false)
    Editor.setCursor(editor, lbOb.start, false)
    resetVimState(vim, "insert")
    result.mutated = true
    return result
  }
  if (ch === "p" || ch === "P") {
    if (vim.registerText) {
      if (vim.registerLinewise) {
        var bP = lineBoundsAt(editor.text, editor.cursor)
        var lineContent = vim.registerText.replace(/\n$/, "")
        if (ch === "p") {
          Editor.setCursor(editor, bP.end, false)
          Editor.insertText(editor, "\n" + lineContent, false)
          Editor.setCursor(editor, bP.end + 1, false)
        } else {
          Editor.setCursor(editor, bP.start, false)
          Editor.insertText(editor, lineContent + "\n", false)
          Editor.setCursor(editor, bP.start, false)
        }
      } else {
        if (ch === "p") {
          var lbP = lineBoundsAt(editor.text, editor.cursor)
          if (editor.cursor < lbP.end) Editor.moveRight(editor, false)
        }
        Editor.insertText(editor, vim.registerText, false)
      }
      result.mutated = true
      result.commitImmediate = true
    }
    return result
  }
  if (ch === "i") { resetVimState(vim, "insert"); return result }
  if (ch === "I") { Editor.moveLineStart(editor, false); resetVimState(vim, "insert"); return result }
  if (ch === "a") {
    var lbA = lineBoundsAt(editor.text, editor.cursor)
    if (editor.cursor < lbA.end) Editor.moveRight(editor, false)
    resetVimState(vim, "insert")
    return result
  }
  if (ch === "A") { Editor.moveLineEnd(editor, false); resetVimState(vim, "insert"); return result }
  if (ch === "v") {
    vim.mode = "visual"
    vim.visualAnchor = editor.cursor
    applyVisualSelection(vim, editor, Editor)
    return result
  }
  if (ch === "V") {
    vim.mode = "visual_line"
    vim.visualAnchor = editor.cursor
    applyVisualSelection(vim, editor, Editor)
    return result
  }
  if (ch === "/") {
    vim.mode = "search"
    vim.searchBuffer = ""
    return result
  }
  if (ch === "n" || ch === "N") {
    if (editor.searchQuery) {
      Editor.nextMatch(editor, ch === "N" ? -1 : 1)
      Editor.setCursor(editor, editor.anchor, false)
    }
    return result
  }

  return result
}

if (typeof module !== "undefined") {
  module.exports = {
    createVimState: createVimState,
    resetVimState: resetVimState,
    handleKey: handleKey
  }
}
