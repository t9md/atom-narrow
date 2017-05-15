path = require 'path'
{Point} = require 'atom'
_ = require 'underscore-plus'
{inspect} = require 'util'

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

toMB = (num) ->
  Math.floor(num / (1024 * 1024))

ignoreSubject = ['refresh']
startMeasureMemory = (subject, simple=false) ->
  return (->) if subject in ignoreSubject

  v8 = require('v8')
  before = v8.getHeapStatistics()
  console.time(subject)
  ->
    after = v8.getHeapStatistics()
    diff = {}
    for key in Object.keys(before)
      diff[key] = after[key] - before[key]

    console.info "= #{subject}"
    if simple
      console.time(subject)
      console.log "diff.used_heap_size", toMB(diff.used_heap_size)
    else
      table = [before, after, diff]
      for result in table
        result[key] = toMB(value) for key, value of result
      console.timeEnd(subject)
      console.table(table)

# Replace old items for filePath or append if items are new filePath.
replaceOrAppendItemsForFilePath = (filePath, oldItems, newItems) ->
  amountOfRemove = 0
  indexToInsert = oldItems.length - 1

  [firstIndex, lastIndex] = findFirstAndLastIndexBy(oldItems, (item) -> item.filePath is filePath)
  if firstIndex? and lastIndex?
    indexToInsert = firstIndex
    amountOfRemove = lastIndex - firstIndex + 1

  oldItems.splice(indexToInsert, amountOfRemove, newItems...)
  oldItems

getProjectPaths = (editor) ->
  paths = null
  if editor?
    if filePath = editor.getPath()
      for dir in atom.project.getDirectories() when dir.contains(filePath)
        paths = [dir.getPath()]
        break
    unless paths
      message = "This file is not belonging to any project"
      atom.notifications.addInfo(message, dismissable: true)
  else
    paths = atom.project.getPaths()
  paths

suppressEvent = (event) ->
  if event?
    event.preventDefault()
    event.stopPropagation()

relativizeFilePath = (filePath) ->
  [projectPath, relativeFilePath] = atom.project.relativizePath(filePath)
  path.join(path.basename(projectPath), relativeFilePath)

getMemoizedRelativizeFilePath = ->
  cache = {}
  return (filePath) ->
    cache[filePath] ?= relativizeFilePath(filePath)

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

  ensureNoConflictForChanges
  ensureNoModifiedFileForChanges
  isNormalItem
  compareByPoint
  findEqualLocationItem
  findFirstAndLastIndexBy
  replaceOrAppendItemsForFilePath
  getProjectPaths
  suppressEvent
  startMeasureMemory
  relativizeFilePath
  getMemoizedRelativizeFilePath
}
