const Path = require('path')
const {Point, Range} = require('atom')

function getAdjacentPane (basePane, which) {
  const parent = basePane.getParent()
  if (parent && parent.getChildren) {
    const children = parent.getChildren()
    const index = children.indexOf(basePane) + (which === 'next' ? +1 : -1)
    const pane = children[index]
    if (pane && pane.constructor.name === 'Pane') {
      // Don't return PaneAxis, just Pane
      return pane
    }
  }
}

function getNextAdjacentPaneForPane (basePane) {
  return getAdjacentPane(basePane, 'next')
}

function getPreviousAdjacentPaneForPane (basePane) {
  return getAdjacentPane(basePane, 'previous')
}

function splitPane (basePane, {split}) {
  const paneWasActive = basePane.isActive()
  if (!['right', 'down'].includes(split)) {
    throw new Error('split must either of `right` or `down`')
  }
  const pane = split === 'right' ? basePane.splitRight() : basePane.splitDown()
  // Atom doesn't allow 'split' pane without activating it.
  // So re-activte basePane if it originally was active.
  if (paneWasActive && !basePane.isActive()) basePane.activate()
  return pane
}

function saveVmpPaneMaximizedState () {
  const classList = atom.workspace.getElement().classList

  if (!classList.contains('vim-mode-plus--pane-maximized')) {
    return
  }
  let command
  if (classList.contains('vim-mode-plus--pane-centered')) {
    command = 'vim-mode-plus:maximize-pane'
  } else {
    command = 'vim-mode-plus:maximize-pane-without-center'
  }
  return () => {
    atom.commands.dispatch(atom.workspace.getElement(), command)
  }
}

function saveEditorState (editor) {
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
      if (!editor.isFoldedAtBufferRow(row)) {
        editor.foldBufferRow(row)
      }
    }
    editor.element.setScrollTop(oldScrollTop)
  }
}

function requireFrom (pack, path) {
  const packPath = atom.packages.resolvePackagePath(pack)
  return require(`${packPath}/lib/${path}`)
}

function limitNumber (number, {max, min} = {}) {
  if (max != null) number = Math.min(number, max)
  if (min != null) number = Math.max(number, min)
  return number
}

function getCurrentWord (editor) {
  const selection = editor.getLastSelection()
  if (!selection.isEmpty()) {
    return selection.getText()
  } else {
    const point = selection.cursor.getBufferPosition()
    selection.selectWord()
    const text = selection.getText()
    selection.cursor.setBufferPosition(point)
    return text
  }
}

function getActiveEditor () {
  const item = atom.workspace
    .getActivePaneContainer()
    .getActivePane()
    .getActiveItem()
  if (atom.workspace.isTextEditor(item)) {
    return item
  }
}

function isActiveEditor (editor) {
  return getActiveEditor() === editor
}

function getValidIndexForList (list, index) {
  const length = list.length
  if (length === 0) return -1

  index = index % length
  return index >= 0 ? index : length + index
}

// Respect goalColumn when moving cursor.
function setBufferRow (cursor, row) {
  if (cursor.goalColumn == null) {
    cursor.goalColumn = cursor.getBufferColumn()
  }
  cursor.setBufferPosition([row, cursor.goalColumn])
}

function isTextEditor (item) {
  return atom.workspace.isTextEditor(item)
}

function paneForItem (item) {
  return atom.workspace.paneForItem(item)
}

function getVisibleEditors () {
  return atom.workspace
    .getPanes()
    .map(pane => pane.getActiveEditor())
    .filter(editor => editor)
}

function getFirstCharacterPositionForBufferRow (editor, row) {
  let point
  editor.scanInBufferRange(/\S/, editor.bufferRangeForBufferRow(row), event => {
    point = event.range.start
  })
  return point || new Point(row, 0)
}

function cloneRegExp (regExp) {
  return new RegExp(regExp.source, regExp.flags)
}

// Utils used in Ui
// =========================

// item utils
// -------------------------
function getPrefixedTextLengthInfo (item) {
  const lineHeaderLength = item._lineHeader ? item._lineHeader.length : 0
  const truncationIndicatorLength = item._truncationIndicator ? item._truncationIndicator.length : 0
  const totalLength = lineHeaderLength + truncationIndicatorLength

  return {lineHeaderLength, truncationIndicatorLength, totalLength}
}

function compareByPoint (a, b) {
  return a.point.compare(b.point)
}

function toMB (num) {
  return Math.floor(num / (1024 * 1024))
}

const ignoreSubject = ['refresh']
function startMeasureMemory (subject, simple = true) {
  if (ignoreSubject.includes(subject)) {
    return () => {}
  }
  console.time(subject)

  const v8 = require('v8')
  const before = v8.getHeapStatistics()
  console.time(subject)
  return function () {
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
        for (const key in result) {
          const value = result[key]
          result[key] = toMB(value)
        }
      }
      console.timeEnd(subject)
      console.table(table)
    }
  }
}

// If editor was given, return first project path which editor's path is contained.
function getProjectPaths (editor) {
  if (!editor) return atom.project.getPaths()

  const filePath = editor.getPath()
  if (filePath) {
    const dir = atom.project.getDirectories().find(dir => dir.contains(filePath))
    if (dir) return [dir.getPath()]
  }
  atom.notifications.addInfo('This file is not belonging to any project', {dismissable: true})
}

function suppressEvent (event) {
  if (event != null) {
    event.preventDefault()
    event.stopPropagation()
  }
}

function relativizeFilePath (filePath) {
  const [projectPath, relativeFilePath] = atom.project.relativizePath(filePath)
  return Path.join(Path.basename(projectPath), relativeFilePath)
}

function getMemoizedRelativizeFilePath () {
  const cache = {}
  return filePath => (cache[filePath] = cache[filePath] || relativizeFilePath(filePath))
}

function isExcludeFilter (text, negateByEndingExclamation) {
  return (text.length > 1 && text.startsWith('!')) || (negateByEndingExclamation && text.endsWith('!'))
}

function scanItemsForBuffer (buffer, regex) {
  const items = []
  const filePath = buffer.getPath()
  regex = cloneRegExp(regex)

  const lines = buffer.getLines()
  for (let row = 0; row < lines.length; row++) {
    let match
    const text = lines[row]
    regex.lastIndex = 0
    while ((match = regex.exec(text))) {
      const point = new Point(row, match.index)
      const range = new Range(point, [row, regex.lastIndex])
      items.push({text, point, range, filePath})
      // Avoid infinite loop in zero length match when regex is /^/
      if (!match[0]) break
    }
  }
  return items
}

function scanItemsForFilePath (filePath, regex) {
  return atom.workspace.open(filePath, {activateItem: false}).then(editor => {
    return scanItemsForBuffer(editor.buffer, regex)
  })
}

function parsePromptLine (promptLineText, {useFirstQueryAsSearchTerm, negateByEndingExclamation}) {
  let searchTerm, match

  const includeFilters = []
  const excludeFilters = []

  const regex = /\S+/g

  if (useFirstQueryAsSearchTerm) {
    regex.exec(promptLineText)
    searchTerm = new Range([0, 0], [0, regex.lastIndex])
  }

  while ((match = regex.exec(promptLineText))) {
    const range = new Range([0, match.index], [0, regex.lastIndex])
    const text = promptLineText.slice(match.index, regex.lastIndex)
    if (isExcludeFilter(text, negateByEndingExclamation)) {
      excludeFilters.push(range)
    } else {
      includeFilters.push(range)
    }
  }

  return {searchTerm, includeFilters, excludeFilters}
}

function redrawPoint (editor, point, where) {
  let coefficient
  if (where === 'upper-middle') {
    coefficient = 0.25
  } else if (where === 'center') {
    coefficient = 0.5
  } else {
    throw new Error(`where must be 'center' or 'upper-middle' but got ${where}`)
  }
  const {top} = editor.element.pixelPositionForBufferPosition(point)
  const editorHeight = editor.element.getHeight()
  const lineHeightInPixel = editor.getLineHeightInPixels()

  const scrollTop = limitNumber(top - editorHeight * coefficient, {
    min: top - editorHeight + lineHeightInPixel * 3,
    max: top - lineHeightInPixel * 2
  })
  editor.element.setScrollTop(Math.round(scrollTop))
}

module.exports = {
  getAdjacentPane,
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  saveEditorState,
  saveVmpPaneMaximizedState,
  requireFrom,
  limitNumber,
  getCurrentWord,
  getActiveEditor,
  isActiveEditor,
  getValidIndexForList,
  setBufferRow,

  isTextEditor,
  paneForItem,
  getVisibleEditors,
  getFirstCharacterPositionForBufferRow,
  cloneRegExp,

  getPrefixedTextLengthInfo,
  compareByPoint,
  getProjectPaths,
  suppressEvent,
  startMeasureMemory,
  relativizeFilePath,
  getMemoizedRelativizeFilePath,
  isExcludeFilter,
  scanItemsForBuffer,
  scanItemsForFilePath,
  parsePromptLine,
  redrawPoint
}
