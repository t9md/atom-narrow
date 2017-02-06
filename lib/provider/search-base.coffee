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
    if @options.currentFile
      @options.filePath = @editor.getPath()

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

  initialize: ->
    @markerLayerByEditor = new Map()
    @decorationByItem = new Map()
    clearHighlight = new Disposable => @clearHighlight()
    @subscriptions.add(
      clearHighlight
      @observeUiStopRefreshing()
      @observeUiChangeSelectedItem()
      @observeUiPreview()
      @observeStopChangingActivePaneItem()
    )

    @regExpForSearchTerm = @getRegExpForSearchTerm()
    source = @regExpForSearchTerm.source
    if @regExpForSearchTerm.ignoreCase
      searchTerm = "(?i:#{source})"
    else
      searchTerm = source
    @ui.grammar.setSearchTerm(searchTerm)

  filterItems: (items, filterSpec) ->
    items = super
    normalItems = _.reject(items, (item) -> item.skip)
    filePaths = _.uniq(_.pluck(normalItems, "filePath"))
    projectNames = _.uniq(_.pluck(normalItems, "projectName"))

    items.filter (item) ->
      if item.header?
        if item.projectHeader?
          item.projectName in projectNames
        else
          item.filePath in filePaths
      else
        true

  # Highlight items
  # -------------------------
  clearHighlight: ->
    @markerLayerByEditor.forEach (markerLayer) ->
      marker.destroy() for marker in markerLayer.getMarkers()
    @markerLayerByEditor.clear()
    @decorationByItem.clear()

  decorationOptions = {type: 'highlight', class: 'narrow-search-match'}
  highlightEditor: (editor) ->
    # Get items shown on narrow-editor and also matching editor's filePath
    items = @ui.getNormalItemsForFilePath(editor.getPath())
    return unless items.length

    @markerLayerByEditor.set(editor, markerLayer = editor.addMarkerLayer())
    editor.scan @regExpForSearchTerm, ({range}) =>
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
      @highlightEditor(editor) for editor in getVisibleEditors()
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
