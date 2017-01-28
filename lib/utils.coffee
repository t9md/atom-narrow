{Disposable} = require 'atom'
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
activatePaneItemInAdjacentPane = (item, {split}={}) ->
  currentPane = atom.workspace.getActivePane()
  pane = getAdjacentPaneForPane(currentPane)

  if pane?
    pane.activate()
    pane.activateItem(item)
    return pane
  else
    return switch split
      when 'right'
        currentPane.splitRight(items: [item])
      when 'down'
        currentPane.splitDown(items: [item])

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

  foldStartRows = editor.displayLayer.foldsMarkerLayer.findMarkers({}).map (m) -> m.getStartPosition().row
  ->
    for row in foldStartRows.reverse() when not editor.isFoldedAtBufferRow(row)
      editor.foldBufferRow(row)
    editorElement.setScrollTop(scrollTop)

requireFrom = (pack, path) ->
  packPath = atom.packages.resolvePackagePath(pack)
  require "#{packPath}/lib/#{path}"

limitNumber = (number, {max, min}={}) ->
  number = Math.min(number, max) if max?
  number = Math.max(number, min) if min?
  number

getCurrentWord = (editor) ->
  getCurrentWordAndBoundary(editor).word

getCurrentWordAndBoundary = (editor) ->
  editor = atom.workspace.getActiveTextEditor()
  selection = editor.getLastSelection()
  {cursor} = selection

  if selection.isEmpty()
    point = cursor.getBufferPosition()
    selection.selectWord()
    text = selection.getText()
    cursor.setBufferPosition(point)
    {word: text, boundary: true}
  else
    text = selection.getText()
    {word: text, boundary: false}

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

module.exports = {
  getAdjacentPaneForPane
  activatePaneItemInAdjacentPane
  smartScrollToBufferPosition
  registerElement
  saveEditorState
  requireFrom
  limitNumber
  getCurrentWord
  getCurrentWordAndBoundary
  isActiveEditor
  getValidIndexForList
}
