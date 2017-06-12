{CompositeDisposable, Point, Range} = require 'atom'

{
  getVisibleEditors
  isNarrowEditor
  cloneRegExp
  isNormalItem
} = require './utils'

decorationOptions = {type: 'highlight', class: 'narrow-match'}
module.exports =
class Highlighter
  regExp: null
  lineMarker: null

  highlightNarrowEditor: ->
    return unless @regExp

    editor = @ui.editor

    if @markerLayerForUi?
      @markerLayerForUi.clear()
    else
      @markerLayerForUi = editor.addMarkerLayer()
      decorationOptions = {type: 'highlight', class: 'narrow-match-ui'}
      @decorationLayerForUi = editor.decorateMarkerLayer(@markerLayerForUi, decorationOptions)

    for line, row in editor.buffer.getLines() when isNormalItem(item = @ui.items.getItemForRow(row))
      if item._lineHeader?.length
        {start, end} = item.range.translate([0, item._lineHeader.length])
      else
        {start, end} = item.range
      range = [[row, start.column], [row, end.column]]
      @markerLayerForUi.markBufferRange(range, invalidate: 'inside')
    return

  constructor: (@ui) ->
    {@boundToSingleFile, @itemHaveRange, @itemHaveRange, @provider} = @ui

    @markerLayerByEditor = new Map()
    @decorationLayerByEditor = new Map()

    @subscriptions = new CompositeDisposable

    if @itemHaveRange
      @subscriptions.add @ui.onDidRefresh =>
        @highlightNarrowEditor() unless @ui.grammar.searchRegex?
        @refreshAll()

    @subscriptions.add @ui.onDidConfirm =>
      @clearCurrentAndLineMarker()

    @subscriptions.add @ui.onDidPreview ({editor, item}) =>
      @clearCurrentAndLineMarker()
      @drawLineMarker(editor, item)
      if @itemHaveRange
        @highlightEditor(editor)
        @highlightCurrentItem(editor, item)

  setRegExp: (@regExp) ->

  destroy: ->
    @markerLayerForUi?.destroy()
    @decorationLayerForUi?.destroy()
    @clear()
    @clearCurrentAndLineMarker()
    @subscriptions.dispose()
    return

  # Highlight items
  # -------------------------
  refreshAll: ->
    @clear()
    for editor in getVisibleEditors() when not isNarrowEditor(editor)
      @highlightEditor(editor)
    return

  clear: ->
    @markerLayerByEditor.forEach (markerLayer) -> markerLayer.destroy()
    @markerLayerByEditor.clear()

    @decorationLayerByEditor.forEach (decorationLayer) -> decorationLayer.destroy()
    @decorationLayerByEditor.clear()
    return

  highlightEditor: (editor) ->
    return unless @regExp
    return if @regExp.source is '.' # Avoid uselessly highlight all character in buffer.
    return if @markerLayerByEditor.has(editor)
    return if @boundToSingleFile and editor isnt @provider.editor

    markerLayer = editor.addMarkerLayer()
    decorationLayer = editor.decorateMarkerLayer(markerLayer, decorationOptions)
    @markerLayerByEditor.set(editor, markerLayer)
    @decorationLayerByEditor.set(editor, decorationLayer)
    items = @ui.getNormalItemsForEditor(editor)
    for item in items when range = item.range
      markerLayer.markBufferRange(range, invalidate: 'inside')
    return

  clearCurrentAndLineMarker: ->
    @clearLineMarker()
    @clearCurrentItemHiglight()
    return

  # modify current item decoration
  # -------------------------
  highlightCurrentItem: (editor, {range}) ->
    # console.trace()
    startBufferRow = range.start.row
    if decorationLayer = @decorationLayerByEditor.get(editor)
      for marker in decorationLayer.getMarkerLayer().findMarkers({startBufferRow})
        if marker.getBufferRange().isEqual(range)
          newProperties = {type: 'highlight', class: 'narrow-match current'}
          decorationLayer.setPropertiesForMarker(marker, newProperties)
          @currentItemEditor = editor
          @currentItemMarker = marker
    return

  clearCurrentItemHiglight: ->
    if @currentItemEditor?
      if decorationLayer = @decorationLayerByEditor.get(@currentItemEditor)
        decorationLayer.setPropertiesForMarker(@currentItemMarker, null)
      @currentItemEditor = null
      @currentItemMarker = null
    return

  # line marker
  # -------------------------
  hasLineMarker: ->
    @lineMarker?

  drawLineMarker: (editor, item) ->
    @lineMarker = editor.markBufferPosition(item.point)
    editor.decorateMarker(@lineMarker, type: 'line', class: 'narrow-line-marker')
    return

  clearLineMarker: ->
    @lineMarker?.destroy()
    @lineMarker = null
    return

  # flash
  # -------------------------
  clearFlashMarker: ->
    clearTimeout(@clearFlashTimeoutID) if @clearFlashTimeoutID?
    @clearFlashTimeoutID = null
    @flashMarker?.destroy()
    @flashMarker = null
    return

  flashItem: (editor, item) ->
    return unless @itemHaveRange
    @clearFlashMarker()
    @flashMarker = editor.markBufferRange(item.range)
    editor.decorateMarker(@flashMarker, type: 'highlight', class: 'narrow-match flash')
    @clearFlashTimeoutID = setTimeout(@clearFlashMarker.bind(this), 1000)
    return
