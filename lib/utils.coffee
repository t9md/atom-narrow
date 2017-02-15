{Disposable, Point} = require 'atom'
_ = require 'underscore-plus'

getAdjacentPaneForPane = (pane) ->
  return unless children = pane.getParent().getChildren?()
  index = children.indexOf(pane)

  _.chain([children[index-1], children[index+1]])
    .filter (pane) ->
      pane?.constructor?.name is 'Pane'
    .last()
    .value()

splitPane = (basePane, {split}) ->
  wasActive = basePane.isActive()
  pane = switch split
    when 'right' then basePane.splitRight()
    when 'down' then basePane.splitDown()
  # Can not 'split' without activating new pane
  # re-activte basePane if it was active.
  if wasActive and not basePane.isActive()
    basePane.activate()
  pane

# Reloadable registerElement
registerElement = (name, options) ->
  element = document.createElement(name)
  # if constructor is HTMLElement, we haven't registerd yet
  if element.constructor is HTMLElement
    Element = document.registerElement(name, options)
  else
    Element = element.constructor
    Element.prototype = options.prototype if options.prototype?
  Element

saveEditorState = (editor) ->
  editorElement = editor.element
  scrollTop = editorElement.getScrollTop()
  cursorPosition = editor.getCursorBufferPosition()

  foldStartRows = editor.displayLayer.foldsMarkerLayer.findMarkers({}).map (m) -> m.getStartPosition().row
  ->
    unless editor.getCursorBufferPosition().isEqual(cursorPosition)
      editor.setCursorBufferPosition(cursorPosition)
    for row in foldStartRows.reverse() when not editor.isFoldedAtBufferRow(row)
      editor.foldBufferRow(row)
    editor.element.setScrollTop(scrollTop)

requireFrom = (pack, path) ->
  packPath = atom.packages.resolvePackagePath(pack)
  require "#{packPath}/lib/#{path}"

limitNumber = (number, {max, min}={}) ->
  number = Math.min(number, max) if max?
  number = Math.max(number, min) if min?
  number

getCurrentWord = (editor) ->
  selection = editor.getLastSelection()
  if selection.isEmpty()
    point = selection.cursor.getBufferPosition()
    selection.selectWord()
    text = selection.getText()
    selection.cursor.setBufferPosition(point)
    text
  else
    selection.getText()

isActiveEditor = (editor) ->
  editor is atom.workspace.getActiveTextEditor()

getValidIndexForList = (list, index) ->
  length = list.length
  if length is 0
    -1
  else
    index = index % length
    if index >= 0
      index
    else
      length + index

# Respect goalColumn when moving cursor.
setBufferRow = (cursor, row, options={}) ->
  column = cursor.goalColumn ? cursor.getBufferColumn()
  if options.ensureCursorIsOneColumnLeftFromEOL
    oneColumLeft = cursor.editor.bufferRangeForBufferRow(row).end.column - 1
    if oneColumLeft >= 0
      columnAdjusted = Math.min(column, oneColumLeft)
  cursor.setBufferPosition([row, columnAdjusted ? column])
  cursor.goalColumn ?= column

isTextEditor = (item) ->
  atom.workspace.isTextEditor(item)

paneForItem = (item) ->
  atom.workspace.paneForItem(item)

isNarrowEditor = (editor) ->
  isTextEditor(editor) and editor.element.classList.contains('narrow-editor')

getVisibleEditors = ->
  atom.workspace.getPanes()
    .map (pane) -> pane.getActiveEditor()
    .filter (editor) -> editor?

getFirstCharacterPositionForBufferRow = (editor, row) ->
  range = null
  scanRange = editor.bufferRangeForBufferRow(row)
  editor.scanInBufferRange /\S/, scanRange, (event) -> range = event.range
  range?.start ? new Point(row, 0)

updateDecoration = (decoration, fn) ->
  {type, class: klass} = decoration.getProperties()
  klass = decoration.getProperties().class
  decoration.setProperties(type: type, class: fn(klass))

itemForGitDiff = (diff, {editor, filePath}) ->
  row = limitNumber(diff.newStart - 1, min: 0)
  {
    point: getFirstCharacterPositionForBufferRow(editor, row)
    text: editor.lineTextForBufferRow(row)
    filePath: filePath
  }

isDefinedAndEqual = (a, b) ->
  a? and b? and a is b

# Utils used in UI
# =========================
# item presenting
# -------------------------
injectLineHeader = (items, {showColumn}={}) ->
  normalItems = items.filter(isNormalItem)
  points = _.pluck(normalItems, 'point')
  maxLine = Math.max(_.pluck(points, 'row')...) + 1
  maxLineWidth = String(maxLine).length

  if showColumn
    maxColumn = Math.max(_.pluck(points, 'column')...) + 1
    maxColumnWidth = Math.max(String(maxColumn).length, 2)

  for item in normalItems
    item._lineHeader = getLineHeaderForItem(item.point, maxLineWidth, maxColumnWidth)
  items

getLineHeaderForItem = (point, maxLineWidth, maxColumnWidth) ->
  lineText = String(point.row + 1)
  padding = " ".repeat(maxLineWidth - lineText.length)
  lineHeader = "#{padding}#{lineText}"
  if maxColumnWidth?
    columnText = String(point.column + 1)
    padding = " ".repeat(maxColumnWidth - columnText.length)
    lineHeader = "#{lineHeader}:#{padding}#{columnText}"
  lineHeader + ": "

# direct-edit related
# -------------------------
getModifiedFilePathsInChanges = (changes) ->
  _.uniq(changes.map ({item}) -> item.filePath).filter (filePath) ->
    atom.project.isPathModified(filePath)

ensureNoModifiedFileForChanges = (changes) ->
  message = ''
  modifiedFilePaths = getModifiedFilePathsInChanges(changes)
  success = modifiedFilePaths.length is 0
  unless success
    modifiedFilePathsAsString = modifiedFilePaths.map((filePath) -> " - `#{filePath}`").join("\n")
    message = """
      Cancelled `update-real-file`.
      You are trying to update file which have **unsaved modification**.
      But this provider is not aware of unsaved change.
      To use `update-real-file`, you need to save these files.

      #{modifiedFilePathsAsString}
      """

  return {success, message}

# detect conflicting change
ensureNoConflictForChanges = (changes) ->
  message = []
  conflictChanges = detectConflictForChanges(changes)
  success = _.isEmpty(conflictChanges)
  unless success
    message.push """
      Cancelled `update-real-file`.
      Detected **conflicting change to same line**.
      """
    for filePath, changesInFile of conflictChanges
      message.push("- #{filePath}")
      for {newText, item} in changesInFile
        message.push("  - #{item.point.translate([1, 1]).toString()}, #{newText}")

  return {success, message: message.join("\n")}

detectConflictForChanges = (changes) ->
  conflictChanges = {}
  changesByFilePath =  _.groupBy(changes, ({item}) -> item.filePath)
  for filePath, changesInFile of changesByFilePath
    changesByRow = _.groupBy(changesInFile, ({item}) -> item.point.row)
    for row, changesInRow of changesByRow
      newTexts = _.pluck(changesInRow, 'newText')
      if _.uniq(newTexts).length > 1
        conflictChanges[filePath] ?= []
        conflictChanges[filePath].push(changesInRow...)
  conflictChanges

# item utils
# -------------------------
isNormalItem = (item) ->
  item? and not item.skip

# -------------------------
module.exports = {
  getAdjacentPaneForPane
  splitPane
  registerElement
  saveEditorState
  requireFrom
  limitNumber
  getCurrentWord
  isActiveEditor
  getValidIndexForList
  setBufferRow
  isTextEditor
  isNarrowEditor
  paneForItem
  getVisibleEditors
  getFirstCharacterPositionForBufferRow
  updateDecoration
  itemForGitDiff
  isDefinedAndEqual

  injectLineHeader
  ensureNoConflictForChanges
  ensureNoModifiedFileForChanges
  isNormalItem
}
