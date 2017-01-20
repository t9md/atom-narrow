_ = require 'underscore-plus'
{Point, CompositeDisposable} = require 'atom'
{
  saveEditorState
  padStringLeft
} = require '../utils'
UI = require '../ui'

module.exports =
class ProviderBase
  wasConfirmed: false
  textWidthForLastRow: null

  getName: ->
    @constructor.name

  getTitle: ->
    _.dasherize(@getName())

  constructor: (uiOptions, @options={}) ->
    @subscriptions = new CompositeDisposable
    @editor = atom.workspace.getActiveTextEditor()

    @subscribe @editor.onDidStopChanging(@invalidateState)

    @editorElement = @editor.element
    @pane = atom.workspace.getActivePane()
    @restoreEditorState = saveEditorState(@editor)

    @ui = new UI(uiOptions)
    @initialize?()
    @ui.start(this)

  invalidateState: =>
    @textWidthForLastRow = null

  subscribe: (args...) ->
    @subscriptions.add(args...)

  getFilterKey: ->
    "text"

  filterItems: (items, words) ->
    filterKey = @getFilterKey()

    matchPattern = (item) ->
      text = item[filterKey]
      if text?
        text.match(///#{pattern}///i)
      else
        true # When without filterKey is always displayed.

    for pattern, i in words.map(_.escapeRegExp)
      items = items.filter(matchPattern)
    items

  highlightRow: (editor, row) ->
    point = [row, 0]
    marker = editor.markBufferRange([point, point])
    editor.decorateMarker(marker, type: 'line', class: 'narrow-result')
    marker

  destroy: ->
    @marker?.destroy()
    @subscriptions.dispose()
    @restoreEditorState() unless @wasConfirmed
    {@editor, @editorElement, @marker, @subscriptions} = {}

  confirmed: ({point}, options={}) ->
    unless options.preview
      @wasConfirmed = true
    @marker?.destroy()
    return unless point?
    point = Point.fromObject(point)

    if options.preview?
      @pane.activateItem(@editor)
      @marker = @highlightRow(@editor, point.row)
    else
      @editor.setCursorBufferPosition(point, autoscroll: false)
      @editor.moveToFirstCharacterOfLine()
      @pane.activate()
      @pane.activateItem(@editor)

    @editor.scrollToBufferPosition(point, center: true)
    @editorElement.component.updateSync()

  getLineNumberText: (row) ->
    @textWidthForLastRow ?= String(@editor.getLastBufferRow()).length
    padStringLeft(String(row + 1), @textWidthForLastRow)
