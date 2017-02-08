_ = require 'underscore-plus'
{Point, CompositeDisposable} = require 'atom'
{
  saveEditorState
  isActiveEditor
  paneForItem
  getAdjacentPaneOrSplit
  getFirstCharacterPositionForBufferRow
} = require '../utils'
UI = require '../ui'
settings = require '../settings'
Input = null

module.exports =
class ProviderBase
  wasConfirmed: false
  boundToEditor: false
  includeHeaderGrammar: false

  indentTextForLineHeader: ""
  ignoreSideMovementOnSyncToEditor: true
  showLineHeader: false
  showColumnOnLineHeader: false
  updateGrammarOnQueryChange: true
  useHighlighter: false

  supportDirectEdit: false
  supportCacheItems: false
  editor: null

  # used by search, atom-scan, scan
  searchWholeWord: null
  searchIgnoreCase: null
  showSearchOption: false

  getName: ->
    @constructor.name

  getDashName: ->
    _.dasherize(@getName())

  getConfig: (name) ->
    settings.get("#{@getName()}.#{name}")

  initialize: ->
    # to override

  # Event is object contains {newEditor, oldEditor}
  onBindEditor: (event) ->
    # to override

  checkReady: ->
    Promise.resolve(true)

  bindEditor: (editor) ->
    @editorSubscriptions?.dispose()
    @editorSubscriptions = new CompositeDisposable
    oldEditor = @editor
    @editor = newEditor = editor
    @restoreEditorState = saveEditorState(@editor)
    @onBindEditor({oldEditor, newEditor})

  getPane: ->
    # If editor was pending item, it will destroyed on next pending open
    pane = paneForItem(@editor)
    if pane?.isAlive()
      @lastPane = pane
    else if @lastPane?.isAlive()
      @lastPane
    else
      null

  isActive: ->
    isActiveEditor(@editor)

  constructor: (editor, @options={}) ->
    @subscriptions = new CompositeDisposable
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
    @subscriptions.dispose()
    @editorSubscriptions.dispose()
    pane = paneForItem(@editor)
    if @editor.isAlive() and pane.isAlive() and not @wasConfirmed
      @restoreEditorState()
      pane.activateItem(@editor)

    {@editor, @editorSubscriptions} = {}

  # When narrow was invoked from existing narrow-editor.
  #  ( e.g. `narrow:search-by-current-word` on narrow-editor. )
  # ui is opened at same pane of provider.editor( editor invoked narrow )
  # In this case item should be opened on adjacent pane, not on provider.pane.
  getPaneForOpenItem: ->
    pane = @getPane()
    if pane? and pane isnt @ui.getPane()
      pane
    else
      getAdjacentPaneOrSplit(@ui.getPane(), split: settings.get('directionToOpen'))

  openFileForItem: ({filePath}, {activatePane}={}) ->
    filePath ?= @editor.getPath()
    pane = @getPaneForOpenItem()
    if item = pane.itemForURI(filePath)
      pane.activate() if activatePane
      pane.activateItem(item, pending: true)
      return Promise.resolve(item)

    # NOTE: See #107
    # Activate target pane to open, before workspace.open is super important to avoid
    #  'workspace can only contain one instance of item exception'
    # There are two approaches to open item at target pane.
    #  A. Not work: Open item then activate that item on target-pane.
    #  B. Work: Activate target-pane first then open item at target-pane
    # Why? if current active pane have item for that path, `workspace.open` return that item.
    # then trying to activate returned item on target-pane result in, one item activated on multiple-pane.
    # this situation cause exception.
    pane.activate()
    atom.workspace.open(filePath, pending: true).then (editor) =>
      @ui.getPane().activate() unless activatePane
      editor

  confirmed: (item) ->
    @wasConfirmed = true
    {point} = item
    @openFileForItem(item, activatePane: true).then (editor) ->
      newPoint = @adjustPoint?(point)
      point = newPoint if newPoint?
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)

  # View
  # -------------------------
  viewForItem: (item) ->
    if item.header?
      item.header
    else
      if @showLineHeader
        item._lineHeader + item.text
      else
        item.text

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

  toggleSearchWholeWord: ->
    @searchWholeWord = not @searchWholeWord

  toggleSearchIgnoreCase: ->
    @searchIgnoreCase = not @searchIgnoreCase

  # Helpers
  # -------------------------
  readInput: ->
    Input ?= require '../input'
    new Input().readInput()

  getFirstCharacterPointOfRow: (row) ->
    getFirstCharacterPositionForBufferRow(@editor, row)

  getRegExpForSearchSource: (source, ignoreCase) ->
    if @searchWholeWord
      source = "\\b#{source}\\b"

    ignoreCase ?= do =>
      # only when explict ignoreCase value are NOT provided.
      # determine it from config and search term
      sensitivity = @getConfig('caseSensitivityForSearchTerm')
      (sensitivity is 'insensitive') or (sensitivity is 'smartcase' and not /[A-Z]/.test(source))

    flags = 'g'
    flags += 'i' if ignoreCase
    new RegExp(source, flags)
