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

  constructor: (@provider) ->
    @ui = @provider.ui
    @markerLayerByEditor = new Map()
    @decorationByItem = new Map()
    @subscriptions = new CompositeDisposable
    @subscriptions.add(
      @observeUiStopRefreshing()
      @observeUiChangeSelectedItem()
      @observeUiPreview()
      @observeStopChangingActivePaneItem()
    )

  setRegExp: (@regexp) ->

  destroy: ->
    @clearHighlight()
    @subscriptions.dispose()

  # Highlight items
  # -------------------------
  clearHighlight: ->
    @markerLayerByEditor.forEach (markerLayer) ->
      marker.destroy() for marker in markerLayer.getMarkers()
    @markerLayerByEditor.clear()
    @decorationByItem.clear()

  decorationOptions = {type: 'highlight', class: 'narrow-match'}
  highlightEditor: (editor) ->
    return unless @regexp
    return if @provider.boundToEditor and editor isnt @provider.editor
    # Get items shown on narrow-editor and also matching editor's filePath
    if @provider.boundToEditor
      items = @ui.getNormalItems()
    else
      items = @ui.getNormalItemsForFilePath(editor.getPath())
    return unless items.length

    @markerLayerByEditor.set(editor, markerLayer = editor.addMarkerLayer())
    editor.scan @regexp, ({range}) =>
      if item = _.detect(items, ({point}) -> point.isEqual(range.start))
        marker = markerLayer.markBufferRange(range, invalidate: 'inside')
        decoration = editor.decorateMarker(marker, decorationOptions)
        @decorationByItem.set(item, decoration)

  updateCurrentHighlight: ->
    if decoration = @decorationByItem.get(@ui.getPreviouslySelectedItem())
      updateDecoration(decoration, (cssClass) -> cssClass.replace(' current', ''))

    if decoration = @decorationByItem.get(@ui.getSelectedItem())
      updateDecoration(decoration, (cssClass) -> cssClass.replace(' current', '') + ' current')

  observeUiStopRefreshing: ->
    @ui.onDidStopRefreshing =>
      @clearHighlight()
      for editor in getVisibleEditors() when not isNarrowEditor(editor)
        @highlightEditor(editor)
      @updateCurrentHighlight()

  observeUiPreview: ->
    @ui.onDidPreview ({editor}) =>
      unless @markerLayerByEditor.has(editor)
        @highlightEditor(editor)
        @updateCurrentHighlight()

  observeStopChangingActivePaneItem: ->
    atom.workspace.onDidStopChangingActivePaneItem (item) =>
      if isTextEditor(item) and not isNarrowEditor(item)
        unless @markerLayerByEditor.has(item)
          @highlightEditor(item)
          @updateCurrentHighlight()

  observeUiChangeSelectedItem: ->
    @ui.onDidChangeSelectedItem =>
      @updateCurrentHighlight()
