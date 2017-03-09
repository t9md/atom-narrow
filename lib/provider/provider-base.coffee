_ = require 'underscore-plus'
{Point, CompositeDisposable} = require 'atom'
{
  saveEditorState
  isActiveEditor
  paneForItem
  getNextAdjacentPaneForPane
  getPreviousAdjacentPaneForPane
  splitPane
  getFirstCharacterPositionForBufferRow
  isNarrowEditor
  isNormalItem
  getCurrentWord
} = require '../utils'
Ui = require '../ui'
settings = require '../settings'
Input = null

module.exports =
class ProviderBase
  @destroyedProviderStates: []
  @reopenableMax: 10
  reopened: false

  @reopen: ->
    if state = @destroyedProviderStates.shift()
      {name, options, properties, uiProperties} = state
      @start(name, options, {properties, uiProperties})

  @start: (name, options, restoredState) ->
    klass = require("./#{name}")
    editor = atom.workspace.getActiveTextEditor()
    new klass(editor, options, restoredState).start()

  @saveState: (provider) ->
    @destroyedProviderStates.unshift(provider.saveState())
    @destroyedProviderStates.splice(@reopenableMax)

  needRestoreEditorState: true
  boundToSingleFile: false

  showLineHeader: true
  showColumnOnLineHeader: false
  updateGrammarOnQueryChange: true
  itemHaveRange: false

  supportDirectEdit: false
  supportCacheItems: false
  supportReopen: true
  editor: null

  # used by scan, search, atom-scan
  searchWholeWord: null
  searchWholeWordChangedManually: false
  searchIgnoreCase: null
  searchIgnoreCaseChangedManually: false
  showSearchOption: false
  querySelectedText: true

  getConfig: (name) ->
    value = settings.get("#{@name}.#{name}")
    if value is 'inherit' or not value?
      settings.get(name)
    else
      value

  needAutoReveal: ->
    switch @getConfig('revealOnStartCondition')
      when 'never'
        false
      when 'always'
        true
      when 'on-input'
        @query?.length

  initialize: ->
    # to override

  # Event is object contains {newEditor, oldEditor}
  onBindEditor: (event) ->
    # to override

  checkReady: ->
    Promise.resolve(true)

  bindEditor: (editor) ->
    return if editor is @editor

    @editorSubscriptions?.dispose()
    @editorSubscriptions = new CompositeDisposable
    event = {
      newEditor: editor
      oldEditor: @editor
    }
    @editor = editor
    @onBindEditor(event)

  getPane: ->
    # If editor was pending item, it will destroyed on next pending-item opened
    if (pane = paneForItem(@editor)) and pane?.isAlive()
      @lastPane = pane

    if @lastPane?.isAlive()
      @lastPane
    else
      null

  isActive: ->
    isActiveEditor(@editor)

  saveState: ->
    properties = {
      @searchWholeWord
      @searchWholeWordChangedManually
      @searchIgnoreCase
      @searchIgnoreCaseChangedManually
      @searchTerm
    }
    for property in @propertiesToRestoreOnReopen ? []
      properties[property] = this[property]

    {
      name: @dashName
      options: {query: @ui.lastQuery}
      properties: properties
      uiProperties: {
        excludedFiles: @ui.excludedFiles
        queryForSelectFiles: @ui.queryForSelectFiles
        needRebuildExcludedFiles: @ui.needRebuildExcludedFiles
      }
    }

  constructor: (editor, @options={}, @restoredState=null) ->
    if @restoredState?
      @reopened = true
      _.extend(this, @restoredState.properties)

    @name = @constructor.name
    @dashName = _.dasherize(@name)
    @subscriptions = new CompositeDisposable

    if isNarrowEditor(editor)
      # Invoked from another Ui( narrow-editor ).
      # Bind to original Ui.provider.editor to behaves like it invoked from normal-editor.
      editorToBind = Ui.get(editor).provider.editor
    else
      editorToBind = editor

    @bindEditor(editorToBind)
    @restoreEditorState = saveEditorState(@editor)
    @query = @getInitialQuery(editor)

  start: ->
    new Promise (resolve) =>
      @checkReady().then (ready) =>
        if ready
          @ui = new Ui(this, {@query}, @restoredState?.uiProperties)
          @initialize()
          @ui.open(pending: @options.pending).then =>
            resolve(@ui)

  getInitialQuery: (editor) ->
    query = @options.query
    query or= editor.getSelectedText() if @querySelectedText
    query or= getCurrentWord(editor) if @options.queryCurrentWord
    query

  subscribeEditor: (args...) ->
    @editorSubscriptions.add(args...)

  filterItems: (items, {include, exclude}) ->
    for regexp in exclude
      items = items.filter (item) -> item.skip or not regexp.test(item.text)

    for regexp in include
      items = items.filter (item) -> item.skip or regexp.test(item.text)

    items

  destroy: ->
    if @supportReopen
      ProviderBase.saveState(this)
    @subscriptions.dispose()
    @editorSubscriptions.dispose()
    @restoreEditorState() if @needRestoreEditorState
    {@editor, @editorSubscriptions} = {}

  # When narrow was invoked from existing narrow-editor.
  #  ( e.g. `narrow:search-by-current-word` on narrow-editor. )
  # ui is opened at same pane of provider.editor( editor invoked narrow )
  # In this case item should be opened on adjacent pane, not on provider.pane.
  getPaneToOpenItem: ->
    pane = @getPane()
    paneForUi = @ui.getPane()

    if pane? and pane isnt paneForUi
      pane
    else
      getPreviousAdjacentPaneForPane(paneForUi) or
        getNextAdjacentPaneForPane(paneForUi) or
        splitPane(paneForUi, split: @getConfig('directionToOpen').split(':')[0])

  openFileForItem: ({filePath}, {activatePane}={}) ->
    pane = @getPaneToOpenItem()
    if @boundToSingleFile and @editor.isAlive() and (pane? and pane is paneForItem(@editor))
      pane.activate() if activatePane
      pane.activateItem(@editor, pending: true)
      return Promise.resolve(@editor)

    filePath ?= @editor.getPath()
    pane = @getPaneToOpenItem()
    # NOTE: See #107
    # Explicitly specify which-pane-to-open is super important to avoid
    #  'workspace can only contain one instance of item exception'
    options = {activatePane: activatePane, activateItem: true, pending: true}
    atom.workspace.openURIInPane(filePath, pane, options)

  confirmed: (item) ->
    @needRestoreEditorState = false
    {point} = item
    @openFileForItem(item, activatePane: true).then (editor) ->
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      return editor

  # View
  # -------------------------
  viewForItem: (item) ->
    if item.header?
      item.header
    else
      if item._lineHeader?
        item._lineHeader + item.text
      else
        item.text

  # Direct Edit
  # -------------------------
  updateRealFile: (changes) ->
    if @boundToSingleFile
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
          # To allow re-edit if not saved and non-boundToSingleFile provider
          item.text = newText

      editor.save()

  toggleSearchWholeWord: ->
    @searchWholeWordChangedManually = true
    @searchWholeWord = not @searchWholeWord

  toggleSearchIgnoreCase: ->
    @searchIgnoreCaseChangedManually = true
    @searchIgnoreCase = not @searchIgnoreCase

  # Helpers
  # -------------------------
  readInput: ->
    Input ?= require '../input'
    new Input().readInput()

  getFirstCharacterPointOfRow: (row) ->
    getFirstCharacterPositionForBufferRow(@editor, row)

  getIgnoreCaseValueForSearchTerm: (term) ->
    sensitivity = @getConfig('caseSensitivityForSearchTerm')
    (sensitivity is 'insensitive') or (sensitivity is 'smartcase' and not /[A-Z]/.test(term))

  getRegExpForSearchTerm: (term, {searchWholeWord, searchIgnoreCase}) ->
    source = _.escapeRegExp(term)
    if searchWholeWord
      startBoundary = /^\w/.test(term)
      endBoundary = /\w$/.test(term)
      if not startBoundary and not endBoundary
        # Go strict
        source = "\\b" + source + "\\b"
      else
        # Relaxed if I can set end or start boundary
        startBoundaryString = if startBoundary then "\\b" else ''
        endBoundaryString = if endBoundary then "\\b" else ''
        source = startBoundaryString + source + endBoundaryString

    flags = 'g'
    flags += 'i' if searchIgnoreCase
    new RegExp(source, flags)
