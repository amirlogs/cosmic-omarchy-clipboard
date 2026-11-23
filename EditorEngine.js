// Pure-JS document, cursor, selection, search, and transaction undo/redo engine.
// Used by Clipboard.qml for the right-panel lightweight editor and tested
// directly under Node.

function clampPos(text, pos) {
  var len = String(text || "").length
  var n = Number(pos)
  if (!isFinite(n) || n < 0) return 0
  if (n > len) return len
  return Math.floor(n)
}

function createState(text, entryId) {
  var content = String(text || "")
  return {
    entryId: String(entryId || ""),
    text: content,
    cursor: 0,
    anchor: 0,
    preferredCol: -1,
    undoStack: [],
    redoStack: [],
    dirty: false,
    searchQuery: "",
    searchMatches: [],
    searchIndex: -1
  }
}

function hasSelection(state) {
  return !!state && state.anchor !== state.cursor
}

function selectionRange(state) {
  if (!state) return { start: 0, end: 0, text: "" }
  var a = clampPos(state.text, state.anchor)
  var c = clampPos(state.text, state.cursor)
  var start = Math.min(a, c)
  var end = Math.max(a, c)
  return {
    start: start,
    end: end,
    text: state.text.slice(start, end)
  }
}

function selectedText(state) {
  return selectionRange(state).text
}

function cursorLineCol(text, pos) {
  var s = String(text || "")
  var p = clampPos(s, pos)
  var before = s.slice(0, p)
  var lines = before.split("\n")
  var allLines = s.split("\n")
  return {
    line: lines.length - 1,
    col: lines[lines.length - 1].length,
    totalLines: allLines.length
  }
}

function lineBounds(text, pos) {
  var s = String(text || "")
  var p = clampPos(s, pos)
  var start = s.lastIndexOf("\n", p - 1)
  start = start < 0 ? 0 : start + 1
  var end = s.indexOf("\n", p)
  if (end < 0) end = s.length
  return { start: start, end: end }
}

function isWordChar(ch) {
  return /[A-Za-z0-9_]/.test(ch)
}

function prevWordPos(text, pos) {
  var s = String(text || "")
  var i = clampPos(s, pos)
  while (i > 0 && /\s/.test(s.charAt(i - 1))) i--
  if (i === 0) return 0
  if (isWordChar(s.charAt(i - 1))) {
    while (i > 0 && isWordChar(s.charAt(i - 1))) i--
  } else {
    while (i > 0 && !/\s/.test(s.charAt(i - 1)) && !isWordChar(s.charAt(i - 1))) i--
  }
  return i
}

function nextWordPos(text, pos) {
  var s = String(text || "")
  var len = s.length
  var i = clampPos(s, pos)
  if (i >= len) return len
  if (isWordChar(s.charAt(i))) {
    while (i < len && isWordChar(s.charAt(i))) i++
  } else if (!/\s/.test(s.charAt(i))) {
    while (i < len && !/\s/.test(s.charAt(i)) && !isWordChar(s.charAt(i))) i++
  }
  while (i < len && /\s/.test(s.charAt(i))) i++
  return i
}

function commitTransaction(state) {
  if (!state || !state.undoStack || state.undoStack.length === 0) return state
  state.undoStack[state.undoStack.length - 1].canCoalesce = false
  return state
}

function pushUndo(state, prevText, prevCursor, prevAnchor, kind, coalesce) {
  var stack = state.undoStack.slice()
  var top = stack.length > 0 ? stack[stack.length - 1] : null
  if (!(coalesce && top && top.canCoalesce && top.kind === kind)) {
    stack.push({
      text: prevText,
      cursor: prevCursor,
      anchor: prevAnchor,
      kind: kind,
      canCoalesce: !!coalesce
    })
    if (stack.length > 200) stack.shift()
  }
  state.undoStack = stack
  state.redoStack = []
}

function setCursor(state, pos, extendSelection, keepPreferredCol) {
  var next = clampPos(state.text, pos)
  if (!extendSelection) state.anchor = next
  state.cursor = next
  if (!keepPreferredCol) state.preferredCol = -1
  commitTransaction(state)
  return state
}

function setSelection(state, anchor, cursor) {
  state.anchor = clampPos(state.text, anchor)
  state.cursor = clampPos(state.text, cursor)
  state.preferredCol = -1
  commitTransaction(state)
  return state
}

function moveLeft(state, extendSelection) {
  if (!extendSelection && hasSelection(state)) {
    return setCursor(state, selectionRange(state).start, false)
  }
  return setCursor(state, state.cursor - 1, extendSelection)
}

function moveRight(state, extendSelection) {
  if (!extendSelection && hasSelection(state)) {
    return setCursor(state, selectionRange(state).end, false)
  }
  return setCursor(state, state.cursor + 1, extendSelection)
}

function moveWordLeft(state, extendSelection) {
  return setCursor(state, prevWordPos(state.text, state.cursor), extendSelection)
}

function moveWordRight(state, extendSelection) {
  return setCursor(state, nextWordPos(state.text, state.cursor), extendSelection)
}

function moveLineStart(state, extendSelection) {
  var bounds = lineBounds(state.text, state.cursor)
  return setCursor(state, bounds.start, extendSelection)
}

function moveLineEnd(state, extendSelection) {
  var bounds = lineBounds(state.text, state.cursor)
  return setCursor(state, bounds.end, extendSelection)
}

function moveUp(state, extendSelection) {
  var s = state.text
  var bounds = lineBounds(s, state.cursor)
  if (bounds.start === 0) return setCursor(state, 0, extendSelection)
  var col = state.preferredCol >= 0 ? state.preferredCol : (state.cursor - bounds.start)
  var prevEnd = bounds.start - 1
  var prevBounds = lineBounds(s, prevEnd)
  var target = Math.min(prevBounds.end, prevBounds.start + col)
  state.preferredCol = col
  return setCursor(state, target, extendSelection, true)
}

function moveDown(state, extendSelection) {
  var s = state.text
  var bounds = lineBounds(s, state.cursor)
  if (bounds.end >= s.length) return setCursor(state, s.length, extendSelection)
  var col = state.preferredCol >= 0 ? state.preferredCol : (state.cursor - bounds.start)
  var nextStart = bounds.end + 1
  var nextBounds = lineBounds(s, nextStart)
  var target = Math.min(nextBounds.end, nextBounds.start + col)
  state.preferredCol = col
  return setCursor(state, target, extendSelection, true)
}

function moveDocStart(state, extendSelection) {
  return setCursor(state, 0, extendSelection)
}

function moveDocEnd(state, extendSelection) {
  return setCursor(state, state.text.length, extendSelection)
}

function selectAll(state) {
  state.anchor = 0
  state.cursor = state.text.length
  state.preferredCol = -1
  commitTransaction(state)
  return state
}

function updateSearchMatches(state) {
  state.searchMatches = findMatches(state.text, state.searchQuery)
  if (state.searchMatches.length === 0) state.searchIndex = -1
  else if (state.searchIndex >= state.searchMatches.length) state.searchIndex = 0
}

function insertText(state, str, coalesce) {
  var textToInsert = String(str || "")
  if (!textToInsert) return state

  var prevText = state.text
  var prevCursor = state.cursor
  var prevAnchor = state.anchor
  var range = selectionRange(state)
  var hadSel = range.start !== range.end
  var isSingleWordChar = textToInsert.length === 1 && !/\s/.test(textToInsert)
  var canCoalesce = !!coalesce && !hadSel && isSingleWordChar

  pushUndo(state, prevText, prevCursor, prevAnchor, "insert", canCoalesce)

  state.text = prevText.slice(0, range.start) + textToInsert + prevText.slice(range.end)
  state.cursor = range.start + textToInsert.length
  state.anchor = state.cursor
  state.preferredCol = -1
  state.dirty = true
  if (!canCoalesce) commitTransaction(state)
  if (state.searchQuery) updateSearchMatches(state)
  return state
}

function deleteBackward(state, byWord, coalesce) {
  var prevText = state.text
  var prevCursor = state.cursor
  var prevAnchor = state.anchor
  var range = selectionRange(state)

  if (range.start !== range.end) {
    pushUndo(state, prevText, prevCursor, prevAnchor, "delete", false)
    state.text = prevText.slice(0, range.start) + prevText.slice(range.end)
    state.cursor = range.start
    state.anchor = range.start
    state.preferredCol = -1
    state.dirty = true
    if (state.searchQuery) updateSearchMatches(state)
    return state
  }

  if (state.cursor === 0) return state
  var delStart = byWord ? prevWordPos(prevText, state.cursor) : state.cursor - 1
  var canCoalesce = !!coalesce && !byWord

  pushUndo(state, prevText, prevCursor, prevAnchor, "delete", canCoalesce)
  state.text = prevText.slice(0, delStart) + prevText.slice(state.cursor)
  state.cursor = delStart
  state.anchor = delStart
  state.preferredCol = -1
  state.dirty = true
  if (state.searchQuery) updateSearchMatches(state)
  return state
}

function deleteForward(state, byWord, coalesce) {
  var prevText = state.text
  var prevCursor = state.cursor
  var prevAnchor = state.anchor
  var range = selectionRange(state)

  if (range.start !== range.end) {
    pushUndo(state, prevText, prevCursor, prevAnchor, "delete", false)
    state.text = prevText.slice(0, range.start) + prevText.slice(range.end)
    state.cursor = range.start
    state.anchor = range.start
    state.preferredCol = -1
    state.dirty = true
    if (state.searchQuery) updateSearchMatches(state)
    return state
  }

  if (state.cursor >= prevText.length) return state
  var delEnd = byWord ? nextWordPos(prevText, state.cursor) : state.cursor + 1
  var canCoalesce = !!coalesce && !byWord

  pushUndo(state, prevText, prevCursor, prevAnchor, "delete", canCoalesce)
  state.text = prevText.slice(0, state.cursor) + prevText.slice(delEnd)
  state.anchor = state.cursor
  state.preferredCol = -1
  state.dirty = true
  if (state.searchQuery) updateSearchMatches(state)
  return state
}

function canUndo(state) {
  return !!state && state.undoStack.length > 0
}

function canRedo(state) {
  return !!state && state.redoStack.length > 0
}

function undo(state) {
  if (!canUndo(state)) return false
  var snapshot = state.undoStack.pop()
  state.redoStack.push({
    text: state.text,
    cursor: state.cursor,
    anchor: state.anchor,
    kind: snapshot.kind,
    canCoalesce: false
  })
  state.text = snapshot.text
  state.cursor = clampPos(snapshot.text, snapshot.cursor)
  state.anchor = clampPos(snapshot.text, snapshot.anchor)
  state.preferredCol = -1
  state.dirty = true
  if (state.searchQuery) updateSearchMatches(state)
  return true
}

function redo(state) {
  if (!canRedo(state)) return false
  var snapshot = state.redoStack.pop()
  state.undoStack.push({
    text: state.text,
    cursor: state.cursor,
    anchor: state.anchor,
    kind: snapshot.kind,
    canCoalesce: false
  })
  state.text = snapshot.text
  state.cursor = clampPos(snapshot.text, snapshot.cursor)
  state.anchor = clampPos(snapshot.text, snapshot.anchor)
  state.preferredCol = -1
  state.dirty = true
  if (state.searchQuery) updateSearchMatches(state)
  return true
}

function findMatches(text, query) {
  var needle = String(query || "")
  if (!needle) return []
  var hay = String(text || "").toLowerCase()
  var q = needle.toLowerCase()
  var matches = []
  var idx = 0
  while (idx <= hay.length - q.length) {
    var found = hay.indexOf(q, idx)
    if (found < 0) break
    matches.push({ start: found, end: found + q.length })
    idx = found + Math.max(1, q.length)
  }
  return matches
}

function setSearch(state, query) {
  state.searchQuery = String(query || "")
  state.searchMatches = findMatches(state.text, state.searchQuery)
  if (state.searchMatches.length === 0) {
    state.searchIndex = -1
    return state
  }

  var pos = state.cursor
  var chosen = 0
  for (var i = 0; i < state.searchMatches.length; i++) {
    if (state.searchMatches[i].start >= pos) {
      chosen = i
      break
    }
  }
  state.searchIndex = chosen
  var m = state.searchMatches[chosen]
  state.anchor = m.start
  state.cursor = m.end
  state.preferredCol = -1
  return state
}

function nextMatch(state, delta) {
  var matches = state.searchMatches
  if (!matches || matches.length === 0) return state
  var step = delta < 0 ? -1 : 1
  var idx = state.searchIndex < 0 ? 0 : (state.searchIndex + step + matches.length) % matches.length
  state.searchIndex = idx
  var m = matches[idx]
  state.anchor = m.start
  state.cursor = m.end
  state.preferredCol = -1
  return state
}

if (typeof module !== "undefined") {
  module.exports = {
    createState: createState,
    hasSelection: hasSelection,
    selectionRange: selectionRange,
    selectedText: selectedText,
    cursorLineCol: cursorLineCol,
    commitTransaction: commitTransaction,
    setCursor: setCursor,
    setSelection: setSelection,
    moveLeft: moveLeft,
    moveRight: moveRight,
    moveWordLeft: moveWordLeft,
    moveWordRight: moveWordRight,
    moveLineStart: moveLineStart,
    moveLineEnd: moveLineEnd,
    moveUp: moveUp,
    moveDown: moveDown,
    moveDocStart: moveDocStart,
    moveDocEnd: moveDocEnd,
    selectAll: selectAll,
    insertText: insertText,
    deleteBackward: deleteBackward,
    deleteForward: deleteForward,
    canUndo: canUndo,
    canRedo: canRedo,
    undo: undo,
    redo: redo,
    findMatches: findMatches,
    setSearch: setSearch,
    nextMatch: nextMatch
  }
}
