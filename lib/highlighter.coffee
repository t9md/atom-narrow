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

  constructor: (@ui) ->
    @provider = @ui.provider
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
    @clear()
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
    return if @provider.boundToEditor and editor isnt @provider.editor
    # Get items shown on narrow-editor and also matching editor's filePath
    if @provider.boundToEditor
      items = @ui.getNormalItems()
    else
      items = @ui.getNormalItemsForFilePath(editor.getPath())
    return unless items.length

    @markerLayerByEditor.set(editor, markerLayer = editor.addMarkerLayer())
    for item in items when range = item.range
      marker = markerLayer.markBufferRange(range, invalidate: 'inside')
      # FIXME: BUG decorationByItem should managed by per editor.
      @decorationByItem.set(item, editor.decorateMarker(marker, decorationOptions))

  updateCurrent: ->
    if decoration = @decorationByItem.get(@ui.getPreviouslySelectedItem())
      updateDecoration(decoration, (cssClass) -> cssClass.replace(' current', ''))

    if @ui.isActive()
      if decoration = @decorationByItem.get(@ui.getSelectedItem())
        updateDecoration(decoration, (cssClass) -> cssClass.replace(' current', '') + ' current')

  observeUiStopRefreshing: ->
    @ui.onDidStopRefreshing =>
      @clear()
      for editor in getVisibleEditors() when not isNarrowEditor(editor)
        @highlight(editor)
      @updateCurrent()

  observeUiPreview: ->
    @ui.onDidPreview ({editor}) =>
      unless @markerLayerByEditor.has(editor)
        @highlight(editor)
        @updateCurrent()

  observeStopChangingActivePaneItem: ->
    atom.workspace.onDidStopChangingActivePaneItem (item) =>
      if isTextEditor(item) and not isNarrowEditor(item)
        unless @markerLayerByEditor.has(item)
          @highlight(item)
          @updateCurrent()

  observeUiChangeSelectedItem: ->
    @ui.onDidChangeSelectedItem =>
      @updateCurrent()
