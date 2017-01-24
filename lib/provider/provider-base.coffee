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
  includeHeaderGrammarRules: false

  supportDirectEdit: false

  indentTextForLineHeader: ""
  showLineHeader: true

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

    @ui = new UI(this, {input: @options.uiInput})

    if @boundToEditor
      @subscribe @editor.onDidStopChanging =>
        # Skip is not activeEditor
        # This is for skip auto-refresh on direct-edit.
        if atom.workspace.getActiveTextEditor() is @editor
          @refresh()

    @checkReady().then (ready) =>
      if ready
        @initialize()
        @ui.start()

  subscribe: (args...) ->
    @subscriptions.add(args...)

  getFilterKey: ->
    "text"

  filterItems: (items, regexps) ->
    filterKey = @getFilterKey()
    for regexp in regexps
      items = items.filter (item) ->
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
    saveAfterEdit = settings.get(@getName() + 'SaveAfterDirectEdit')

    atom.workspace.open(filePath, activateItem: false).then (editor) ->
      editor.transact ->
        for {newText, item} in changes
          range = editor.bufferRangeForBufferRow(item.point.row)
          editor.setTextInBufferRange(range, newText)

          # Sync item's text state
          # To allow re-edit if not saved and non-boundToEditor provider
          item.text = newText

      if saveAfterEdit
        editor.save()

  # Helpers
  # -------------------------
  readInput: ->
    Input ?= require '../input'
    new Input().readInput()
