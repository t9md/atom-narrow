_ = require 'underscore-plus'
{Point, CompositeDisposable, Emitter} = require 'atom'
{
  saveEditorState
  padStringLeft
} = require '../utils'
UI = require '../ui'

module.exports =
class ProviderBase
  wasConfirmed: false
  textWidthForLastRow: null
  syncToEditor: false

  getName: ->
    @constructor.name

  getDashName: ->
    _.dasherize(@getName())

  constructor: (uiOptions, @options={}) ->
    @subscriptions = new CompositeDisposable
    @editor = atom.workspace.getActiveTextEditor()
    @editorElement = @editor.element
    @pane = atom.workspace.paneForItem(@editor)
    @restoreEditorState = saveEditorState(@editor)
    @emitter = new Emitter

    @subscribe @editor.onDidStopChanging(@invalidateState)

    @ui = new UI(this, uiOptions)
    @initialize?()
    @ui.start()

  invalidateState: =>
    @textWidthForLastRow = null

  subscribe: (args...) ->
    @subscriptions.add(args...)

  getFilterKey: ->
    "text"

  filterItems: (items, words) ->
    filterKey = @getFilterKey()

    for pattern, i in words.map(_.escapeRegExp)
      items = items.filter (item) ->
        if (text = item[filterKey])?
          text.match(///#{pattern}///i)
        else
          true # items without filterKey is always displayed.
    items

  destroy: ->
    @subscriptions.dispose()
    if @editor.isAlive() and not @wasConfirmed
      @restoreEditorState()
    {@editor, @editorElement, @subscriptions} = {}

  confirmed: ({point}) ->
    @wasConfirmed = true
    return unless point?
    point = Point.fromObject(point)

    @editor.setCursorBufferPosition(point, autoscroll: false)
    @editor.moveToFirstCharacterOfLine()
    @pane.activate()
    @pane.activateItem(@editor)

    @editor.scrollToBufferPosition(point, center: true)
    @editorElement.component.updateSync()

  getLineNumberText: (row) ->
    @textWidthForLastRow ?= String(@editor.getLastBufferRow()).length
    padStringLeft(String(row + 1), @textWidthForLastRow)
