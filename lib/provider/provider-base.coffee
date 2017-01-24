_ = require 'underscore-plus'
{Point, CompositeDisposable, Emitter} = require 'atom'
{saveEditorState} = require '../utils'
UI = require '../ui'
settings = require '../settings'
Input = null

module.exports =
class ProviderBase
  wasConfirmed: false
  boundToEditor: false
  includeHeaderGrammar: false

  indentTextForLineHeader: ""
  showLineHeader: true

  supportDirectEdit: false
  supportCacheItems: false

  getName: ->
    @constructor.name

  getDashName: ->
    _.dasherize(@getName())

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

    @ui = new UI(this, {input: @options.uiInput})

    @checkReady().then (ready) =>
      if ready
        @initialize()
        @ui.start()

  subscribe: (args...) ->
    @subscriptions.add(args...)

  filterItems: (items, regexps) ->
    filterKey = "text"
    for regexp in regexps
      items = items.filter (item) ->
        item.skip or regexp.test(item[filterKey])
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

    newPoint = @adjustPoint?(point)
    if newPoint?
      @editor.setCursorBufferPosition(newPoint, autoscroll: false)
    else
      @editor.setCursorBufferPosition(point, autoscroll: false)
      @editor.moveToFirstCharacterOfLine()

    @pane.activate()
    @pane.activateItem(@editor)

    @editor.scrollToBufferPosition(point, center: true)

    return {@editor, point}

  # View
  # -------------------------
  viewForItem: (item) ->
    if item.header?
      item.header
    else
      if @showLineHeader
        item._lineHeader = @getLineHeaderForItem(item) # Inject
        item._lineHeader + item.text
      else
        item.text

  # Unless items didn't have maxLineTextWidth field, detect last line from editor.
  getLineHeaderForItem: ({point, maxLineTextWidth}, editor=@editor) ->
    maxLineTextWidth ?= String(editor.getLastBufferRow() + 1).length
    lineNumberText = String(point.row + 1)
    padding = " ".repeat(maxLineTextWidth - lineNumberText.length)
    @indentTextForLineHeader + padding + lineNumberText + ": "

  # Direct Edit
  # -------------------------
  updateRealFile: (changes) ->
    if @boundToEditor
      # Intentionally avoid direct use of @editor to skip observation event
      # subscribed to @editor.
      # This prevent auto refresh, so undoable narrow-editor to last state.
      @applyChanges(@editor.getPath(), changes)
    else
      changesByFilePath =  _.groupBy(changes, ({item}) -> item.filePath)
      for filePath, changes of changesByFilePath
        @applyChanges(filePath, changes)

  applyChanges: (filePath, changes) ->
    atom.workspace.open(filePath, activateItem: false).then (editor) ->
      editor.transact ->
        for {newText, item} in changes
          range = editor.bufferRangeForBufferRow(item.point.row)
          editor.setTextInBufferRange(range, newText)

          # Sync item's text state
          # To allow re-edit if not saved and non-boundToEditor provider
          item.text = newText

      editor.save()

  # Helpers
  # -------------------------
  readInput: ->
    Input ?= require '../input'
    new Input().readInput()
