_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{Disposable} = require 'atom'
{
  getCurrentWordAndBoundary
  getVisibleEditors
  isTextEditor
  isNarrowEditor
  updateDecoration
} = require '../utils'

module.exports =
class SearchBase extends ProviderBase
  ignoreSideMovementOnSyncToEditor: false

  includeHeaderGrammar: true
  supportDirectEdit: true
  showLineHeader: true
  showColumnOnLineHeader: true
  regExpForSearchTerm: null

  checkReady: ->
    if @options.currentWord
      {word, boundary} = getCurrentWordAndBoundary(@editor)
      @options.wordOnly = boundary
      @options.search = word

    if @options.search
      Promise.resolve(true)
    else
      @readInput().then (input) =>
        @options.search = input
        true

  getRegExpForSearchTerm: ->
    searchTerm = @options.search
    source = _.escapeRegExp(searchTerm)
    if @options.wordOnly
      source = "\\b#{source}\\b"

    sensitivity = @getConfig('caseSensitivityForSearchTerm')
    if (sensitivity is 'sensitive') or (sensitivity is 'smartcase' and /[A-Z]/.test(searchTerm))
      new RegExp(source, 'g')
    else
      new RegExp(source, 'gi')

  clearHighlight: ->
    @markerLayerByEditor.forEach (markerLayer) ->
      marker.destroy() for marker in markerLayer.getMarkers()
    @markerLayerByEditor.clear()
    @decorationByItem.clear()

  decorationOptions = {type: 'highlight', class: 'narrow-search-match'}
  highlightEditor: (editor) ->
    # Get items shown on narrow-editor and also matching editor's filePath
    items = @ui.getNormalItemsForPath(editor.getPath())
    return unless items.length
    markerLayer = editor.addMarkerLayer()
    @markerLayerByEditor.set(editor, markerLayer)
    editor.scan @regExpForSearchTerm, ({range}) =>
      if item = _.detect(items, ({point}) -> point.isEqual(range.start))
        marker = markerLayer.markBufferRange(range, invalidate: 'inside')
        decoration = editor.decorateMarker(marker, decorationOptions)
        @decorationByItem.set(item, decoration)

  updateCurrentHighlight: ->
    if decoration = @decorationByItem.get(@ui.getPreviouslySelectedItem())
      updateDecoration decoration, (cssClass) -> cssClass.replace(' current', '')

    if decoration = @decorationByItem.get(@ui.getSelectedItem())
      updateDecoration decoration, (cssClass) -> cssClass.replace(' current', '') + ' current'

  initialize: ->
    @markerLayerByEditor = new Map()
    @decorationByItem = new Map()
    @subscriptions.add new Disposable => @clearHighlight()

    @subscriptions.add @ui.onDidStopRefreshing =>
      @clearHighlight()
      @highlightEditor(editor) for editor in getVisibleEditors()
      @updateCurrentHighlight()

    @subscriptions.add @ui.onDidChangeSelectedItem =>
      @updateCurrentHighlight()

    @subscriptions.add @ui.onDidPreview ({editor}) =>
      unless @markerLayerByEditor.has(editor)
        @highlightEditor(editor)
        @updateCurrentHighlight()

    @subscriptions.add atom.workspace.onDidStopChangingActivePaneItem (item) =>
      if isTextEditor(item) and not isNarrowEditor(item)
        unless @markerLayerByEditor.has(item)
          @highlightEditor(item)
          @updateCurrentHighlight()

    @regExpForSearchTerm = @getRegExpForSearchTerm()
    source = @regExpForSearchTerm.source
    if @regExpForSearchTerm.ignoreCase
      searchTerm = "(?i:#{source})"
    else
      searchTerm = source
    @ui.grammar.setSearchTerm(searchTerm)
