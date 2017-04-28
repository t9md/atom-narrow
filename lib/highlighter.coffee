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
    @needHighlight = @provider.itemHaveRange
    @markerLayerByEditor = new Map()
    @decorationByItem = new Map()
    @subscriptions = new CompositeDisposable

    if @needHighlight
      if @provider.boundToSingleFile
        @subscriptions.add @ui.onDidRefresh(@refreshAll.bind(this))
      else
        @subscriptions.add @ui.onDidStopRefreshing(@refreshAll.bind(this))

    @subscriptions.add @ui.onDidConfirm(@clearCurrentAndLineMarker.bind(this))

    @subscriptions.add @ui.onDidPreview ({editor, item}) =>
      @clearCurrentAndLineMarker()
      @drawLineMarker(editor, item)
      if @needHighlight
        @highlight(editor)
        @highlightCurrent() if @ui.isActive()

  setRegExp: (@regexp) ->

  destroy: ->
    @clear()
    @clearCurrentAndLineMarker()
    @subscriptions.dispose()

  # Highlight items
  # -------------------------
  refreshAll: ->
    @clear()
    @highlight(editor) for editor in getVisibleEditors()
    @highlightCurrent() if @ui.isActive()

  clear: ->
    @markerLayerByEditor.forEach (markerLayer) ->
      markerLayer.clear()
    @markerLayerByEditor.clear()
    @decorationByItem.clear()

  decorationOptions = {type: 'highlight', class: 'narrow-match'}
  highlight: (editor) ->
    return unless @regexp
    return if isNarrowEditor(editor)

    # FIXME: highlight called multiple time uselessly
    # console.log "called for", editor.getPath()
    
    return if @provider.boundToSingleFile and editor isnt @provider.editor
    return if @markerLayerByEditor.has(editor)

    items = @ui.getNormalItemsForEditor(editor)
    return unless items.length

    @markerLayerByEditor.set(editor, markerLayer = editor.addMarkerLayer())
    for item in items when range = item.range
      marker = markerLayer.markBufferRange(range, invalidate: 'inside')
      # FIXME: BUG decorationByItem should managed by per editor.
      @decorationByItem.set(item, editor.decorateMarker(marker, decorationOptions))

  clearCurrentAndLineMarker: ->
    @clearLineMarker()
    @clearCurrent()

  # modify current item decoration
  # -------------------------
  highlightCurrent: ->
    if decoration = @decorationByItem.get(@ui.items.getSelectedItem())
      updateDecoration(decoration, (cssClass) -> cssClass + ' current')

  clearCurrent: ->
    return unless @needHighlight
    return unless @decorationByItem.size
    items = [@ui.items.getPreviouslySelectedItem(), @ui.items.getSelectedItem()]
    for item in items when item?
      if decoration = @decorationByItem.get(item)
        updateDecoration(decoration, (cssClass) -> cssClass.replace(' current', ''))

  # line marker
  # -------------------------
  hasLineMarker: ->
    @lineMarker?

  drawLineMarker: (editor, item) ->
    @lineMarker = editor.markBufferPosition(item.point)
    editor.decorateMarker(@lineMarker, type: 'line', class: 'narrow-line-marker')

  clearLineMarker: ->
    @lineMarker?.destroy()
    @lineMarker = null

  # flash
  # -------------------------
  clearFlashMarker: ->
    clearTimeout(@clearFlashTimeoutID) if @clearFlashTimeoutID?
    @clearFlashTimeoutID = null
    @flashMarker?.destroy()
    @flashMarker = null

  flashItem: (editor, item) ->
    return unless @needHighlight
    @clearFlashMarker()
    @flashMarker = editor.markBufferRange(item.range)
    editor.decorateMarker(@flashMarker, type: 'highlight', class: 'narrow-match flash')
    @clearFlashTimeoutID = setTimeout(@clearFlashMarker.bind(this), 1000)
