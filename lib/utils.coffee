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

openItemInAdjacentPaneForPane = (basePane, item, direction) ->
  if pane = getAdjacentPaneForPane(basePane)
    pane.activateItem(item)
    pane.activate()
  else
    pane = switch direction
      when 'right' then basePane.splitRight(items: [item])
      when 'down' then basePane.splitDown(items: [item])
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

smartScrollToBufferPosition = (editor, point) ->
  editorElement = editor.element
  editorAreaHeight = editor.getLineHeightInPixels() * (editor.getRowsPerPage() - 1)
  onePageUp = editorElement.getScrollTop() - editorAreaHeight # No need to limit to min=0
  onePageDown = editorElement.getScrollBottom() + editorAreaHeight
  target = editorElement.pixelPositionForBufferPosition(point).top

  center = (onePageDown < target) or (target < onePageUp)
  editor.scrollToBufferPosition(point, {center})

padStringLeft = (string, targetLength) ->
  padding = " ".repeat(targetLength - string.length)
  padding + string

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

module.exports = {
  getAdjacentPaneForPane
  openItemInAdjacentPaneForPane
  decorateRange
  smartScrollToBufferPosition
  padStringLeft
  registerElement
  saveEditorState
  requireFrom
}
