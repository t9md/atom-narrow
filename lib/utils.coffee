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

# Split is used when fail to find adjacent pane.
# return pane
getAdjacentPaneOrSplit = (basePane, {split}) ->
  pane = getAdjacentPaneForPane(basePane) ? switch split
    when 'right' then basePane.splitRight()
    when 'down' then basePane.splitDown()

  # Can not 'split' without activating new pane so rever it here
  basePane.activate() if pane.isActive()
  pane

smartScrollToBufferPosition = (editor, point) ->
  editorElement = editor.element
  editorAreaHeight = editor.getLineHeightInPixels() * (editor.getRowsPerPage() - 1)
  onePageUp = editorElement.getScrollTop() - editorAreaHeight # No need to limit to min=0
  onePageDown = editorElement.getScrollBottom() + editorAreaHeight
  target = editorElement.pixelPositionForBufferPosition(point).top

  center = (onePageDown < target) or (target < onePageUp)
  editor.scrollToBufferPosition(point, {center})

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

module.exports = {
  getAdjacentPaneForPane
  getAdjacentPaneOrSplit
  smartScrollToBufferPosition
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
}
