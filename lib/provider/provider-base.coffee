WorkspaceOpenAcceptPaneOption = atom.workspace.getCenter?

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
  getCurrentWord
} = require '../utils'
Ui = require '../ui'
settings = require '../settings'

module.exports =
class ProviderBase
  @destroyedProviderStates: []
  @reopenableMax: 10
  reopened: false

  @reopen: ->
    if stateAtDestroyed = @destroyedProviderStates.shift()
      {name, options, state} = stateAtDestroyed
      @start(name, options, state)

  @start: (name, options, state) ->
    klass = require("./#{name}")
    editor = atom.workspace.getActiveTextEditor()
    new klass(editor, options, state).start()

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
  queryWordBoundaryOnByCurrentWordInvocation: false
  initiallySearchedRegexp: null

  getConfig: (name) ->
    value = settings.get("#{@name}.#{name}")
    if value is 'inherit' or not value?
      settings.get(name)
    else
      value

  getOnStartConditionValueFor: (name) ->
    switch @getConfig(name)
      when 'never' then false
      when 'always' then true
      when 'on-input' then @query?.length
      when 'no-input' then not @query?.length

  needRevealOnStart: ->
    @getOnStartConditionValueFor('revealOnStartCondition')

  needActivateOnStart: ->
    @getOnStartConditionValueFor('focusOnStartCondition')

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

  mergeState: (stateA, stateB) ->
    Object.assign(stateA, stateB)

  getState: ->
    {
      @searchWholeWord
      @searchWholeWordChangedManually
      @searchIgnoreCase
      @searchIgnoreCaseChangedManually
      @searchTerm
    }

  saveState: ->
    {
      name: @dashName
      options: {query: @ui.lastQuery}
      state:
        provider: @getState()
        ui: @ui.getState()
    }

  constructor: (editor, @options={}, @restoredState=null) ->
    if @restoredState?
      @reopened = true
      @mergeState(this, @restoredState.provider)

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
          @ui = new Ui(this, {@query}, @restoredState?.ui)
          @initialize()
          @ui.open(pending: @options.pending).then =>
            resolve(@ui)

  getInitialQuery: (editor) ->
    query = @options.query

    if not query and @querySelectedText
      query = editor.getSelectedText()

    if not query and @options.queryCurrentWord
      query = getCurrentWord(editor)
      if @queryWordBoundaryOnByCurrentWordInvocation
        query = ">" + query + "<"
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

    itemToOpen = null
    if @boundToSingleFile and @editor.isAlive() and (pane is paneForItem(@editor))
      itemToOpen = @editor

    filePath ?= @editor.getPath()
    itemToOpen ?= pane.itemForURI(filePath)
    if itemToOpen?
      pane.activate() if activatePane
      pane.activateItem(itemToOpen)
      return Promise.resolve(itemToOpen)

    openOptions = {pending: true, activatePane: activatePane, activateItem: true}
    if WorkspaceOpenAcceptPaneOption
      openOptions.pane = pane
      atom.workspace.open(filePath, openOptions)

    else
      # NOTE: See #107
      # In Atom v1.16.0 or older, `workspace.open` doesn't allow to specify target pane to open file.
      # So need to activate target pane first.
      # Otherwise, when original pane have item for same path(URI), it opens on CURRENT pane.
      originalActivePane = atom.workspace.getActivePane() unless activatePane
      pane.activate()
      atom.workspace.open(filePath, openOptions).then (editor) ->
        originalActivePane?.activate()
        return editor

  confirmed: (item) ->
    @needRestoreEditorState = false
    @openFileForItem(item, activatePane: true).then (editor) ->
      {point} = item
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      return editor

  # View
  # -------------------------
  viewForItem: (item) ->
    if item.header?
      item.header
    else
      (item._lineHeader ? '') + item.text

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
