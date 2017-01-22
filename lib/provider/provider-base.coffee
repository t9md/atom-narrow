_ = require 'underscore-plus'
{Point, CompositeDisposable, Emitter} = require 'atom'
{
  saveEditorState
  padStringLeft
} = require '../utils'
UI = require '../ui'
settings = require '../settings'
Input = null

module.exports =
class ProviderBase
  wasConfirmed: false
  textWidthForLastRow: null
  boundToEditor: false
  includeHeaderGrammarRules: false
  supportDirectEdit: false

  getName: ->
    @constructor.name

  invalidateCachedItem: ->
    @items = null

  getDashName: ->
    _.dasherize(@getName())

  refresh: ->
    @items = null
    @ui.refresh().then =>
      @ui.syncToProviderEditor()

  initialize: ->
    # to override

  checkReady: ->
    Promise.resolve(true)

  constructor: (@options={}) ->
    @subscriptions = new CompositeDisposable
    @editor = atom.workspace.getActiveTextEditor()
    @editorElement = @editor.element
    @pane = atom.workspace.paneForItem(@editor)
    @restoreEditorState = saveEditorState(@editor)
    @emitter = new Emitter

    @subscribe @editor.onDidStopChanging(@invalidateState)
    @ui = new UI(this, {input: @options.uiInput})

    if @boundToEditor
      @subscribe @editor.onDidStopChanging(@refresh.bind(this))

    @checkReady().then (ready) =>
      if ready
        @initialize()
        @ui.start()

  invalidateState: =>
    @textWidthForLastRow = null

  subscribe: (args...) ->
    @subscriptions.add(args...)

  getFilterKey: ->
    "text"

  filterItems: (items, regexps) ->
    filterKey = @getFilterKey()
    for regexp in regexps
      items = items.filter (item) =>
        if (text = item[filterKey])?
          regexp.test(text)
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

    return {@editor, point}

  getLineNumberText: (row) ->
    @textWidthForLastRow ?= String(@editor.getLastBufferRow()).length
    padStringLeft(String(row + 1), @textWidthForLastRow)

  readInput: ->
    Input ?= require '../input'
    new Input().readInput()
