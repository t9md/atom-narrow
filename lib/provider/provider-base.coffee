_ = require 'underscore-plus'
{Point, CompositeDisposable} = require 'atom'
{
  decorateRange
  saveEditorState
  padStringLeft
} = require '../utils'

module.exports =
class ProviderBase
  wasConfirmed: false
  lastRowNumberTextLength: null

  getName: ->
    @constructor.name

  getTitle: ->
    _.dasherize(@getName())

  constructor: (@ui, @options={}) ->
    @subscriptions = new CompositeDisposable
    @editor = atom.workspace.getActiveTextEditor()

    @subscribe @editor.onDidStopChanging(@invalidateState)

    @editorElement = atom.views.getView(@editor)
    @pane = atom.workspace.getActivePane()
    @restoreEditorState = saveEditorState(@editor)

    @initialize?()
    @ui.start(this)

  invalidateState: =>
    @lastRowNumberTextLength = null

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
    range = [[row, 0], [row, 0]]
    decorateRange(editor, range, type: 'line', class: 'narrow-result')

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
      @pane.activate()
      @pane.activateItem(@editor)

    @editor.scrollToBufferPosition(point, center: true)
    @editorElement.component.updateSync()

  getTextForRow: (row) ->
    @lastRowNumberTextLength ?= String(@editor.getLastBufferRow()).length
    padStringLeft(String(row + 1), @lastRowNumberTextLength)
