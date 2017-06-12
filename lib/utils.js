const path = require("path")
const {Point} = require("atom")
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
  const editorElement = editor.element
  const scrollTop = editorElement.getScrollTop()
  const cursorPosition = editor.getCursorBufferPosition()
  const foldStartRows = editor.displayLayer.foldsMarkerLayer
    .findMarkers({})
    .map(m => m.getStartPosition().row)

  return restoreEditorState

  function restoreEditorState() {
    let pane = paneForItem(editor)
    if (!pane) return
    pane.activate()
    pane.activateItem(editor)
    if (editorElement.component.getScrollTop() == null) {
      let disposable = editorElement.onDidChangeScrollTop(() => {
        disposable.dispose()
        restoreCursorAndScrollTop()
      })
    } else {
      restoreCursorAndScrollTop()
    }
  }

  function restoreCursorAndScrollTop() {
    if (!editor.getCursorBufferPosition().isEqual(cursorPosition)) {
      editor.setCursorBufferPosition(cursorPosition)
    }
    foldStartRows.reverse().forEach(row => {
      if (!editor.isFoldedAtBufferRow(row)) editor.foldBufferRow(row)
    })
    editorElement.setScrollTop(scrollTop)
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
  return (
    isTextEditor(editor) && editor.element.classList.contains("narrow-editor")
  )
}

function getVisibleEditors() {
  return atom.workspace
    .getPanes()
    .map(pane => pane.getActiveEditor())
    .filter(editor => editor)
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

function itemForGitDiff(diff, {editor, filePath}) {
  const row = limitNumber(diff.newStart - 1, {min: 0})
  return {
    point: getFirstCharacterPositionForBufferRow(editor, row),
    text: editor.lineTextForBufferRow(row),
    filePath: filePath,
  }
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

// detect conflicting change
function ensureNoConflictForChanges(changes) {
  const message = []
  const conflictChanges = detectConflictForChanges(changes)
  const success = _.isEmpty(conflictChanges)
  if (!success) {
    message.push("Cancelled `update-real-file`.")
    message.push("Detected **conflicting change to same line**.")
    for (const filePath in conflictChanges) {
      const changesInFile = conflictChanges[filePath]
      message.push(`- ${filePath}`)
      for (let {newText, item} of changesInFile) {
        message.push(
          `  - ${item.point.translate([1, 1]).toString()}, ${newText}`
        )
      }
    }
  }

  return {success, message: message.join("\n")}
}

function detectConflictForChanges(changes) {
  const conflictChanges = {}
  const changesByFilePath = _.groupBy(changes, ({item}) => item.filePath)
  for (let filePath in changesByFilePath) {
    const changesInFile = changesByFilePath[filePath]
    const changesByRow = _.groupBy(changesInFile, ({item}) => item.point.row)
    for (let row in changesByRow) {
      const changesInRow = changesByRow[row]
      const newTexts = _.pluck(changesInRow, "newText")
      if (_.uniq(newTexts).length > 1) {
        if (conflictChanges[filePath] == null) {
          conflictChanges[filePath] = []
        }
        conflictChanges[filePath].push(...Array.from(changesInRow || []))
      }
    }
  }
  return conflictChanges
}

//
// item utils
// -------------------------
function isNormalItem(item) {
  return item != null && !item.skip
}

function compareByPoint(a, b) {
  return a.point.compare(b.point)
}

function toMB(num) {
  return Math.floor(num / (1024 * 1024))
}

const ignoreSubject = ["refresh"]
function startMeasureMemory(subject, simple = false) {
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
      console.time(subject)
      console.log("diff.used_heap_size", toMB(diff.used_heap_size))
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
    for (const dir in atom.project.getDirectories()) {
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
  return filePath =>
    cache[filePath] != null
      ? cache[filePath]
      : (cache[filePath] = relativizeFilePath(filePath))
}

function arrayForRange(start, end) {
  if (end == null) [start, end] = [0, start]
  const range = []
  while (start <= end) range.push(start++)
  return range
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
  itemForGitDiff,
  isDefinedAndEqual,
  cloneRegExp,
  addToolTips,

  ensureNoConflictForChanges,
  isNormalItem,
  compareByPoint,
  getProjectPaths,
  suppressEvent,
  startMeasureMemory,
  relativizeFilePath,
  getMemoizedRelativizeFilePath,
  arrayForRange,
}
