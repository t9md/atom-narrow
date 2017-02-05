_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{Disposable} = require 'atom'
{getCurrentWordAndBoundary, getVisibleEditors, isTextEditor, isNarrowEditor} = require '../utils'

module.exports =
class SearchBase extends ProviderBase
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
      for marker in markerLayer.getMarkers()
        marker.destroy()
    @markerLayerByEditor.clear()

  highlightEditor: (editor) ->
    items = @ui.getNormalItemsForPath(editor.getPath())
    return unless items.length

    @markerLayerByEditor.set(editor, markerLayer = editor.addMarkerLayer())
    editor.decorateMarkerLayer(markerLayer, type: 'highlight', class: 'narrow-search-match')
    editor.scan @regExpForSearchTerm, ({range}) ->
      if items.some(({point}) -> point.isEqual(range.start))
        markerLayer.markBufferRange(range, invalidate: 'inside')

  initialize: ->
    @markerLayerByEditor = new Map()
    @subscriptions.add new Disposable => @clearHighlight()

    @subscriptions.add @ui.onDidStopRefreshing =>
      console.log 'stop refreshing'
      @clearHighlight()
      @highlightEditor(editor) for editor in getVisibleEditors()

    @subscriptions.add @ui.onDidPreview ({editor}) =>
      unless @markerLayerByEditor.has(editor)
        console.log 'did preview'
        @highlightEditor(editor)

    @subscriptions.add atom.workspace.onDidStopChangingActivePaneItem (item) =>
      if isTextEditor(item) and not isNarrowEditor(item) and not @markerLayerByEditor.has(item)
        console.log 'active item changed'
        @highlightEditor(item)

    @regExpForSearchTerm = @getRegExpForSearchTerm()
    source = @regExpForSearchTerm.source
    if @regExpForSearchTerm.ignoreCase
      searchTerm = "(?i:#{source})"
    else
      searchTerm = source
    @ui.grammar.setSearchTerm(searchTerm)
