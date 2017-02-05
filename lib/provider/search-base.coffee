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

  highlightMatches: (editor) ->
    normalItems = @ui.items.filter (item) -> not item.skip
    itemsByFilePath =  _.groupBy(normalItems, (item) -> item.filePath)
    visibleEditors = getVisibleEditors()

    if editor? and (editor in visibleEditors) and (items = itemsByFilePath[editor.getPath()])
      @clearHighlightForEditor(editor)
      @highlightEditor(editor, items)
    else
      @clearHighlight()
      for editor in visibleEditors when (items = itemsByFilePath[editor.getPath()])
        @highlightEditor(editor, items)

  clearHighlightForEditor: (editor) ->
    if @markerLayerByEditor.has(editor)
      markerLayer = @markerLayerByEditor.get(editor)
      for marker in markerLayer.getMarkers()
        marker.destroy()
      @markerLayerByEditor.delete(editor)

  highlightEditor: (editor, items) ->
    decorationOptions = {type: 'highlight', class: 'narrow-search-match'}
    markerLayer = editor.addMarkerLayer()
    @markerLayerByEditor.set(editor, markerLayer)
    editor.decorateMarkerLayer(markerLayer, decorationOptions)
    editor.scan @regExpForSearchTerm, ({range}) ->
      if items.some(({point}) -> point.isEqual(range.start))
        markerLayer.markBufferRange(range, invalidate: 'inside')

  initialize: ->
    @markerLayerByEditor = new Map()
    @subscriptions.add new Disposable => @clearHighlight()

    @subscriptions.add @ui.onDidStopRefreshing =>
      console.log 'stop refreshing'
      @highlightMatches()

    @subscriptions.add @getPane().onDidChangeActiveItem (editor) =>
      console.log 'change active item'
      @highlightMatches(editor)

    @subscriptions.add atom.workspace.onDidStopChangingActivePaneItem (item) =>
      console.log 'active item changed'
      if isTextEditor(item) and not isNarrowEditor(item)
        @highlightMatches(item)

    @regExpForSearchTerm = @getRegExpForSearchTerm()
    source = @regExpForSearchTerm.source
    if @regExpForSearchTerm.ignoreCase
      searchTerm = "(?i:#{source})"
    else
      searchTerm = source
    @ui.grammar.setSearchTerm(searchTerm)
