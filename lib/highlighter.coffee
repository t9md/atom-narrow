{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'
{
  getVisibleEditors
  isTextEditor
  isNarrowEditor
  updateDecoration
} = require './utils'

module.exports =
class Highlighter
  regexp: null
  lineMarker: null

  constructor: (@ui) ->
    @provider = @ui.provider
    @needHighlight = @provider.supportRangeHighlight
    @markerLayerByEditor = new Map()
    @decorationByItem = new Map()
    @subscriptions = new CompositeDisposable

    if @needHighlight
      @subscriptions.add @observeUiStopRefreshing()

    @subscriptions.add(
      @observeUiPreview()
      @observeUiConfirm()
      @observeStopChangingActivePaneItem()
    )

  setRegExp: (@regexp) ->

  destroy: ->
    @clear()
    @clearLineMarker()
    @subscriptions.dispose()

  # Highlight items
  # -------------------------
  clear: ->
    @markerLayerByEditor.forEach (markerLayer) ->
      markerLayer.clear()
    @markerLayerByEditor.clear()
    @decorationByItem.clear()

  decorationOptions = {type: 'highlight', class: 'narrow-match'}
  highlight: (editor) ->
    return unless @regexp
    return unless @needHighlight
    return if isNarrowEditor(editor)
    return if @provider.boundToSingleFile and editor isnt @provider.editor
    return if @markerLayerByEditor.has(editor)

    # Get items shown on narrow-editor and also matching editor's filePath
    if @provider.boundToSingleFile
      items = @ui.getNormalItems()
    else
      items = @ui.getNormalItemsForFilePath(editor.getPath())
    return unless items.length

    @markerLayerByEditor.set(editor, markerLayer = editor.addMarkerLayer())
    for item in items when range = item.range
      marker = markerLayer.markBufferRange(range, invalidate: 'inside')
      # FIXME: BUG decorationByItem should managed by per editor.
      @decorationByItem.set(item, editor.decorateMarker(marker, decorationOptions))

  # modify current item decoration
  # -------------------------
  resetCurrent: ->
    return unless @needHighlight
    @clearCurrent()
    return unless @ui.isActive()

    if decoration = @decorationByItem.get(@ui.getSelectedItem())
      updateDecoration(decoration, (cssClass) -> cssClass + ' current')

  clearCurrent: ->
    return unless @needHighlight
    items = [@ui.getPreviouslySelectedItem(), @ui.getSelectedItem()]
    for item in items when item?
      if decoration = @decorationByItem.get(item)
        updateDecoration(decoration, (cssClass) -> cssClass.replace(' current', ''))

  # lineMarker
  # -------------------------
  hasLineMarker: ->
    @lineMarker?

  drawLineMarker: (editor, item) ->
    @clearLineMarker()
    @lineMarker = editor.markBufferPosition(item.point)
    editor.decorateMarker(@lineMarker, type: 'line', class: 'narrow-line-marker')

  clearLineMarker: ->
    @lineMarker?.destroy()
    @lineMarker = null

  # flash
  # -------------------------
  flashItem: (editor, item) ->
    return unless @needHighlight

    @flashMarker?.destroy()
    clearTimeout(@clearFlashTimeout) if @clearFlashTimeout?

    clearFlashMarker = =>
      @clearFlashTimeout = null
      @flashMarker?.destroy()
      @flashMarker = null

    @flashMarker = editor.markBufferRange(item.range)
    editor.decorateMarker(@flashMarker, type: 'highlight', class: 'narrow-match flash')
    @clearFlashTimeout = setTimeout(clearFlashMarker, 1000)

  # Event observation
  # -------------------------
  observeUiStopRefreshing: ->
    @ui.onDidStopRefreshing =>
      @clear()
      @highlight(editor) for editor in getVisibleEditors()
      @resetCurrent()

  observeUiPreview: ->
    @ui.onDidPreview ({editor, item}) =>
      @drawLineMarker(editor, item)
      @highlight(editor)
      @resetCurrent()

  observeUiConfirm: ->
    @ui.onDidConfirm ({editor, item}) =>
      @clearLineMarker()
      @clearCurrent()

  observeStopChangingActivePaneItem: ->
    atom.workspace.onDidStopChangingActivePaneItem (item) =>
      return unless isTextEditor(item)
      if item isnt @ui.editor
        @clearLineMarker()
        @clearCurrent()

      @highlight(item)
