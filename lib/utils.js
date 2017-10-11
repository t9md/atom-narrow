const path = require("path")
const {Point, Range, TextBuffer} = require("atom")
const _ = require("underscore-plus")

function getAdjacentPane(basePane, which) {
  const parent = basePane.getParent()
  let children = null
  if (parent && parent.getChildren) {
    children = parent.getChildren()
  }
  if (!children) return

  let index = children.indexOf(basePane)
  if (which === "next") {
    index += 1
  } else if (which === "previous") {
    index -= 1
  }
  const pane = children[index]
  // console.log(pane);
  if (pane && pane.constructor && pane.constructor.name === "Pane") {
    return pane
  }
}

function getNextAdjacentPaneForPane(basePane) {
  return getAdjacentPane(basePane, "next")
}

function getPreviousAdjacentPaneForPane(basePane) {
  return getAdjacentPane(basePane, "previous")
}

function splitPane(basePane, {split}) {
  const wasActive = basePane.isActive()
  let pane = null
  if (split === "right") {
    pane = basePane.splitRight()
  } else if (split === "down") {
    pane = basePane.splitDown()
  }
  // Can not 'split' without activating new pane
  // re-activte basePane if it was active.
  if (wasActive && !basePane.isActive()) basePane.activate()
  return pane
}

function saveEditorState(editor) {
  const oldScrollTop = editor.element.getScrollTop()
  const oldCursorPosition = editor.getCursorBufferPosition()
  const oldFoldStartRows = editor.displayLayer.foldsMarkerLayer.findMarkers({}).map(m => m.getStartPosition().row)

  return ({activatePane = true} = {}) => {
    const pane = paneForItem(editor)
    if (!pane) return

    if (activatePane) pane.activate()
    pane.activateItem(editor)

    if (!editor.getCursorBufferPosition().isEqual(oldCursorPosition)) {
      editor.setCursorBufferPosition(oldCursorPosition)
    }
    for (const row of oldFoldStartRows.reverse()) {
      if (!editor.isFoldedAtBufferRow(row)) editor.foldBufferRow(row)
    }
    editor.element.setScrollTop(oldScrollTop)
  }
}

function requireFrom(pack, path) {
  const packPath = atom.packages.resolvePackagePath(pack)
  return require(`${packPath}/lib/${path}`)
}

function limitNumber(number, {max, min} = {}) {
  if (max != null) number = Math.min(number, max)
  if (min != null) number = Math.max(number, min)
  return number
}

function getCurrentWord(editor) {
  const selection = editor.getLastSelection()
  if (selection.isEmpty()) {
    const point = selection.cursor.getBufferPosition()
    selection.selectWord()
    const text = selection.getText()
    selection.cursor.setBufferPosition(point)
    return text
  } else {
    return selection.getText()
  }
}

function isActiveEditor(editor) {
  return editor === atom.workspace.getActiveTextEditor()
}

function getValidIndexForList(list, index) {
  const length = list.length
  if (length === 0) return -1

  index = index % length
  return index >= 0 ? index : length + index
}

// Respect goalColumn when moving cursor.
function setBufferRow(cursor, row) {
  if (cursor.goalColumn == null) {
    cursor.goalColumn = cursor.getBufferColumn()
  }
  cursor.setBufferPosition([row, cursor.goalColumn])
}

function isTextEditor(item) {
  return atom.workspace.isTextEditor(item)
}

function paneForItem(item) {
  return atom.workspace.paneForItem(item)
}

function isNarrowEditor(editor) {
  return isTextEditor(editor) && editor.element.classList.contains("narrow-editor")
}

function getVisibleEditors() {
  return atom.workspace.getPanes().map(pane => pane.getActiveEditor()).filter(editor => editor)
}

function getFirstCharacterPositionForBufferRow(editor, row) {
  let point = null
  const scanRange = editor.scanInBufferRange(
    /\S/,
    editor.bufferRangeForBufferRow(row),
    ({range}) => (point = range.start)
  )
  return point ? point : new Point(row, 0)
}

function isDefinedAndEqual(a, b) {
  return a != null && b != null && a === b
}

function cloneRegExp(regExp) {
  return new RegExp(regExp.source, regExp.flags)
}

function addToolTips({element, commandName, keyBindingTarget}) {
  return atom.tooltips.add(element, {
    title: _.humanizeEventName(commandName.split(":")[1]),
    keyBindingCommand: commandName,
    keyBindingTarget: keyBindingTarget,
  })
}

// Utils used in Ui
// =========================
// direct-edit related
// -------------------------
function getModifiedFilePathsInChanges(changes) {
  const toFilePath = change => change.item.filePath
  const isModified = atom.project.isPathModified(filePath)

  return changes.map(toFilePath).filter(isModified)
}

// item utils
// -------------------------
function isNormalItem(item) {
  return item != null && !item.skip
}

function getPrefixedTextLengthInfo(item) {
  const lineHeaderLength = item._lineHeader ? item._lineHeader.length : 0
  const truncationIndicatorLength = item._truncationIndicator ? item._truncationIndicator.length : 0
  const totalLength = lineHeaderLength + truncationIndicatorLength

  return {lineHeaderLength, truncationIndicatorLength, totalLength}
}

function compareByPoint(a, b) {
  return a.point.compare(b.point)
}

function toMB(num) {
  return Math.floor(num / (1024 * 1024))
}

const ignoreSubject = ["refresh"]
function startMeasureMemory(subject, simple = true) {
  if (ignoreSubject.includes(subject)) {
    return () => {}
  }
  console.time(subject)

  const v8 = require("v8")
  const before = v8.getHeapStatistics()
  console.time(subject)
  return function() {
    const after = v8.getHeapStatistics()
    const diff = {}
    for (let key of Object.keys(before)) {
      diff[key] = after[key] - before[key]
    }

    console.info(`= ${subject}`)
    if (simple) {
      console.timeEnd(subject)
      // console.log("diff.used_heap_size", toMB(diff.used_heap_size))
    } else {
      const table = [before, after, diff]
      for (let result of table) {
        for (key in result) {
          const value = result[key]
          result[key] = toMB(value)
        }
      }
      console.timeEnd(subject)
      console.table(table)
    }
  }
}

function getProjectPaths(editor) {
  if (editor == null) return atom.project.getPaths()

  let paths = null
  if ((filePath = editor.getPath())) {
    for (const dir of atom.project.getDirectories()) {
      if (dir.contains(filePath)) {
        paths = [dir.getPath()]
        break
      }
    }
  }
  if (!paths) {
    const message = "This file is not belonging to any project"
    atom.notifications.addInfo(message, {dismissable: true})
  }
  return paths
}

function suppressEvent(event) {
  if (event != null) {
    event.preventDefault()
    event.stopPropagation()
  }
}

function relativizeFilePath(filePath) {
  const [projectPath, relativeFilePath] = atom.project.relativizePath(filePath)
  return path.join(path.basename(projectPath), relativeFilePath)
}

function getMemoizedRelativizeFilePath() {
  const cache = {}
  return filePath => (cache[filePath] != null ? cache[filePath] : (cache[filePath] = relativizeFilePath(filePath)))
}

function getList(start, end) {
  if (end == null) [start, end] = [0, start]
  const range = []
  while (start <= end) range.push(start++)
  return range
}

function isExcludeFilter(text, negateByEndingExclamation) {
  return (text.length > 1 && text.startsWith("!")) || (negateByEndingExclamation && text.endsWith("!"))
}

function scanItemsForBuffer(buffer, regex) {
  const items = []
  const filePath = buffer.getPath()
  regex = cloneRegExp(regex)
  const lines = buffer.getLines()
  for (let row = 0; row < lines.length; row++) {
    let match
    const lineText = lines[row]
    regex.lastIndex = 0
    while ((match = regex.exec(lineText))) {
      const point = new Point(row, match.index)
      const range = new Range(point, [row, regex.lastIndex])
      items.push({text: lineText, point, range, filePath})
      // Avoid infinite loop in zero length match when regex is /^/
      if (!match[0]) break
    }
  }
  return items
}

function scanItemsForFilePath(filePath, regex) {
  return atom.workspace.open(filePath, {activateItem: false}).then(editor => scanItemsForBuffer(editor.buffer, regex))
}

module.exports = {
  getAdjacentPane,
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  saveEditorState,
  requireFrom,
  limitNumber,
  getCurrentWord,
  isActiveEditor,
  getValidIndexForList,
  setBufferRow,

  isTextEditor,
  isNarrowEditor,
  paneForItem,
  getVisibleEditors,
  getFirstCharacterPositionForBufferRow,
  isDefinedAndEqual,
  cloneRegExp,
  addToolTips,

  isNormalItem,
  getPrefixedTextLengthInfo,
  compareByPoint,
  getProjectPaths,
  suppressEvent,
  startMeasureMemory,
  relativizeFilePath,
  getMemoizedRelativizeFilePath,
  getList,
  isExcludeFilter,
  scanItemsForBuffer,
  scanItemsForFilePath,
}
