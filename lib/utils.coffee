path = require 'path'
{Point} = require 'atom'
_ = require 'underscore-plus'

getAdjacentPane = (basePane, which) ->
  return unless children = basePane.getParent().getChildren?()
  index = children.indexOf(basePane)
  index = switch which
    when 'next' then index + 1
    when 'previous' then index - 1

  pane = children[index]
  if pane?.constructor?.name is 'Pane'
    pane
  else
    null

getNextAdjacentPaneForPane = (basePane) ->
  getAdjacentPane(basePane, 'next')

getPreviousAdjacentPaneForPane = (basePane) ->
  getAdjacentPane(basePane, 'previous')

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

saveEditorState = (editor) ->
  editorElement = editor.element
  scrollTop = editorElement.getScrollTop()
  cursorPosition = editor.getCursorBufferPosition()
  foldStartRows = editor.displayLayer.foldsMarkerLayer.findMarkers({}).map (m) -> m.getStartPosition().row

  restoreCursorAndScrollTop = ->
    unless editor.getCursorBufferPosition().isEqual(cursorPosition)
      editor.setCursorBufferPosition(cursorPosition)
    for row in foldStartRows.reverse() when not editor.isFoldedAtBufferRow(row)
      editor.foldBufferRow(row)
    editorElement.setScrollTop(scrollTop)

  ->
    pane = paneForItem(editor)
    return unless pane?
    pane.activate()
    pane.activateItem(editor)

    # [BUG?] atom-narrow#95
    # Immediately calling editorElement.scrollTop after changing active-pane-item cause editor content blank.
    # See detailed condition this happens in atom-narrow#95.
    # In this state, component.getScrollTop() returns `undefined`, need to delaying setScrollTop.
    unless editorElement.component.getScrollTop()?
      disposable = editorElement.onDidChangeScrollTop ->
        disposable.dispose()
        restoreCursorAndScrollTop()
    else
      restoreCursorAndScrollTop()

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
setBufferRow = (cursor, row) ->
  column = cursor.goalColumn ? cursor.getBufferColumn()
  cursor.setBufferPosition([row, column])
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

itemForGitDiff = (diff, {editor, filePath}) ->
  row = limitNumber(diff.newStart - 1, min: 0)
  {
    point: getFirstCharacterPositionForBufferRow(editor, row)
    text: editor.lineTextForBufferRow(row)
    filePath: filePath
  }

isDefinedAndEqual = (a, b) ->
  a? and b? and a is b

cloneRegExp = (regExp) ->
  new RegExp(regExp.source, regExp.flags)

addToolTips = ({element, commandName, keyBindingTarget}) ->
  atom.tooltips.add element,
    title: _.humanizeEventName(commandName.split(':')[1])
    keyBindingCommand: commandName
    keyBindingTarget: keyBindingTarget

# Utils used in Ui
# =========================
# item presenting
# -------------------------
injectLineHeader = (items, {showColumn}={}) ->
  normalItems = items.filter(isNormalItem)
  maxRow = 0
  for item in normalItems when (row = item.point.row) > maxRow
    maxRow = row
  maxLineWidth = String(maxRow + 1).length

  if showColumn
    maxColumn = 0
    for item in normalItems when (column = item.point.column) > maxColumn
      maxColumn = column

    maxColumnWidth = Math.max(String(maxColumn + 1).length, 2)

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

compareByPoint = (a, b) ->
  a.point.compare(b.point)

findEqualLocationItem = (items, itemToFind) ->
  normalItems = items.filter(isNormalItem)
  _.detect normalItems, ({point, filePath}) ->
    point.isEqual(itemToFind.point) and (filePath is itemToFind.filePath)

# Since underscore-plus not support _.findIndex
findIndexBy = (items, fn) ->
  for item, i in items when fn(item)
    return i

findLastIndexBy = (items, fn) ->
  for item, i in items by -1 when fn(item)
    return i

findFirstAndLastIndexBy = (items, fn) ->
  [findIndexBy(items, fn), findLastIndexBy(items, fn)]

getItemsWithoutUnusedHeader = (items) ->
  normalItems = items.filter(isNormalItem)
  filePaths = _.uniq(_.pluck(normalItems, "filePath"))
  projectNames = _.uniq(_.pluck(normalItems, "projectName"))

  items.filter (item) ->
    if item.header?
      if item.projectHeader?
        item.projectName in projectNames
      else if item.filePath?
        item.filePath in filePaths
      else
        true
    else
      true

getItemsWithHeaders = (_items) ->
  items = []

  # Inject projectName from filePath
  for item in _items
    projectPath = atom.project.relativizePath(item.filePath)[0]
    if projectPath?
      item.projectName = path.basename(projectPath)
    else
      item.projectName = "( No project )"

  for projectName, itemsInProject of _.groupBy(_items, (item) -> item.projectName)
    header = "# #{projectName}"
    items.push({header, projectName, projectHeader: true, skip: true})

    for filePath, itemsInFile of _.groupBy(itemsInProject, (item) -> item.filePath)
      header = "## " + atom.project.relativize(filePath)
      items.push({header, projectName, filePath, fileHeader: true, skip: true})
      items.push(itemsInFile...)
  items

module.exports = {
  getNextAdjacentPaneForPane
  getPreviousAdjacentPaneForPane
  splitPane
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
  itemForGitDiff
  isDefinedAndEqual
  cloneRegExp
  addToolTips

  injectLineHeader
  ensureNoConflictForChanges
  ensureNoModifiedFileForChanges
  isNormalItem
  compareByPoint
  findEqualLocationItem
  findFirstAndLastIndexBy
  getItemsWithHeaders
  getItemsWithoutUnusedHeader
}
