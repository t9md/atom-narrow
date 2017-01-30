_ = require 'underscore-plus'
{Point, CompositeDisposable} = require 'atom'
{saveEditorState, getAdjacentPaneForPane, isActiveEditor} = require '../utils'
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
  editor: null

  getName: ->
    @constructor.name

  getDashName: ->
    _.dasherize(@getName())

  getConfig: (name) ->
    settings.get("#{@getName()}.#{name}")

  initialize: ->
    # to override

  checkReady: ->
    Promise.resolve(true)

  bindEditor: (editor) ->
    if @editor isnt editor
      @editorSubscriptions?.dispose()
      @editorSubscriptions = new CompositeDisposable
      @editor = editor
      @restoreEditorState = saveEditorState(@editor)

  getPane: ->
    atom.workspace.paneForItem(@editor)

  isActive: ->
    isActiveEditor(@editor)

  constructor: (editor, @options={}) ->
    @bindEditor(editor)
    @ui = new UI(this, {input: @options.uiInput})

    @checkReady().then (ready) =>
      if ready
        @initialize()
        @ui.start()

  subscribeEditor: (args...) ->
    @editorSubscriptions.add(args...)

  filterItems: (items, {include, exclude}) ->
    for regexp in exclude
      items = items.filter (item) -> item.skip or not regexp.test(item.text)

    for regexp in include
      items = items.filter (item) -> item.skip or regexp.test(item.text)

    items

  destroy: ->
    @editorSubscriptions.dispose()
    if @editor.isAlive() and not @wasConfirmed
      @restoreEditorState()
      @getPane().activateItem(@editor)

    {@editor, @editorSubscriptions} = {}

  confirmed: (item, {preview}={}) ->
    @wasConfirmed = true unless preview
    {point, filePath} = item

    if filePath?
      options = {pending: true}
      if pane = @getPane() ? getAdjacentPaneForPane(@ui.getPane())
        pane.activate()
      else
        options.split = settings.get('directionToOpen')

      atom.workspace.open(filePath, options).then (editor) ->
        editor.setCursorBufferPosition(point, autoscroll: false)
        editor.scrollToBufferPosition(point, center: true)
        return {editor, point}
    else
      pane = @getPane()
      pane.activate()
      newPoint = @adjustPoint?(point)
      if newPoint?
        point = newPoint
        @editor.setCursorBufferPosition(point, autoscroll: false)
      else
        @editor.setCursorBufferPosition(point, autoscroll: false)
        @editor.moveToFirstCharacterOfLine()

      pane.activateItem(@editor)
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

  # Return intems which are injected maxLineTextWidth(used to align lineHeader)
  injectMaxLineTextWidthForItems: (items) ->
    rows = _.reject(items, (item) -> item.skip).map(({point}) -> point.row)
    maxLineTextWidth = String(Math.max(rows...) + 1).length
    for item in items when not item.skip
      item.maxLineTextWidth = maxLineTextWidth
    items
