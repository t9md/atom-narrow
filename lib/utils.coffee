{Range, Disposable, CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'

getAdjacentPaneForPane = (pane) ->
  return unless children = pane.getParent().getChildren?()
  index = children.indexOf(pane)
  options = {split: 'left', activatePane: false}

  _.chain([children[index-1], children[index+1]])
    .filter (pane) ->
      pane?.constructor?.name is 'Pane'
    .last()
    .value()

openItemInAdjacentPane = (item, direction) ->
  activePane = atom.workspace.getActivePane()
  if direction is 'here'
    activePane.activateItem(item)
    return

  if pane = getAdjacentPaneForPane(activePane)
    pane.activateItem(item)
    pane.activate()
  else
    pane = switch direction
      when 'right' then activePane.splitRight(items: [item])
      when 'down' then activePane.splitDown(items: [item])
  pane

# options is object with following keys
#  timeout: number (msec)
#  class: css class
flashDisposable = null
decorateRange = (editor, range, options) ->
  flashDisposable?.dispose()
  marker = editor.markBufferRange range,
    invalidate: options.invalidate ? 'never'
    persistent: options.persistent ? false

  editor.decorateMarker marker,
    type: options.type ? 'highlight'
    class: options.class

  if options.timeout?
    timeoutID = setTimeout ->
      marker.destroy()
    , options.timeout

    flashDisposable = new Disposable ->
      clearTimeout(timeoutID)
      marker?.destroy()
      flashDisposable = null
  marker

getView = (model) ->
  atom.views.getView(model)

getVisibleBufferRange = (editor) ->
  [startRow, endRow] = getView(editor).getVisibleRowRange()
  return null unless (startRow? and endRow?)
  startRow = editor.bufferRowForScreenRow(startRow)
  endRow = editor.bufferRowForScreenRow(endRow)
  new Range([startRow, 0], [endRow, Infinity])

smartScrollToBufferPosition = (editor, point) ->
  editorElement = atom.views.getView(editor)
  editorAreaHeight = editor.getLineHeightInPixels() * (editor.getRowsPerPage() - 1)
  onePageUp = editorElement.getScrollTop() - editorAreaHeight # No need to limit to min=0
  onePageDown = editorElement.getScrollBottom() + editorAreaHeight
  target = editorElement.pixelPositionForBufferPosition(point).top

  center = (onePageDown < target) or (target < onePageUp)
  editor.scrollToBufferPosition(point, {center})

padStringLeft = (string, targetLength) ->
  padding = " ".repeat(targetLength - string.length)
  padding + string

module.exports = {
  getView
  getAdjacentPaneForPane
  getVisibleBufferRange
  openItemInAdjacentPane
  decorateRange
  smartScrollToBufferPosition
  padStringLeft
}
