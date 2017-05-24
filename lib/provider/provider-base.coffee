WorkspaceOpenAcceptPaneOption = atom.workspace.getCenter?

_ = require 'underscore-plus'
{Point, CompositeDisposable, Range} = require 'atom'
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
  cloneRegExp
} = require '../utils'
Ui = require '../ui'
settings = require '../settings'
FilterSpec = require '../filter-spec'
SearchOptions = require '../search-options'

module.exports =
class ProviderBase
  @destroyedProviderStates: []
  @providersByName: {}
  @reopenableMax: 10
  reopened: false

  @reopen: ->
    if stateAtDestroyed = @destroyedProviderStates.shift()
      {name, options, state} = stateAtDestroyed
      @start(name, options, state)

  @start: (name, options={}, state) ->
    klass = @providersByName[name] ?= require("./#{name}")
    editor = atom.workspace.getActiveTextEditor()
    new klass(editor, options, state).start()

  @registerProvider: (name, klass) ->
    @providersByName[name] = klass

  @saveState: (provider) ->
    @destroyedProviderStates.unshift(provider.saveState())
    @destroyedProviderStates.splice(@reopenableMax)

  needRestoreEditorState: true
  boundToSingleFile: false

  showLineHeader: true
  showColumnOnLineHeader: false
  itemHaveRange: false

  supportDirectEdit: false
  supportCacheItems: false
  supportReopen: true
  supportFilePathOnlyItemsUpdate: false
  editor: null
  refreshOnDidStopChanging: false
  refreshOnDidSave: false

  # used by scan, search, atom-scan
  showSearchOption: false

  queryWordBoundaryOnByCurrentWordInvocation: false
  useFirstQueryAsSearchTerm: false

  @getConfig: (name) ->
    value = settings.get("#{@name}.#{name}")
    if value is 'inherit'
      settings.get(name)
    else
      value

  getConfig: (name) ->
    @constructor.getConfig(name)

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

  initializeSearchOptions: (restoredState) ->
    editor = atom.workspace.getActiveTextEditor()
    initialState = restoredState ? {}

    if @options.queryCurrentWord and editor.getSelectedBufferRange().isEmpty()
      initialState.searchWholeWord ?= true
    else
      initialState.searchWholeWord ?= @getConfig('searchWholeWord')
    initialState.searchUseRegex ?= @getConfig('searchUseRegex')
    @searchOptions = new SearchOptions(this, initialState)

  # Event is object contains {newEditor, oldEditor}
  onBindEditor: (event) ->
    # to override

  checkReady: ->
    true

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
      searchOptionState: @searchOptions?.getState()
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
      {searchOptionState} = @restoredState
      delete @restoredState.searchOptionState
      @mergeState(this, @restoredState.provider)

    @name = @constructor.name
    @dashName = _.dasherize(@name)
    @subscriptions = new CompositeDisposable

    if @showSearchOption
      @initializeSearchOptions(searchOptionState)

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
    checkReady = Promise.resolve(@checkReady())
    checkReady.then (ready) =>
      if ready
        @ui = new Ui(this, {@query}, @restoredState?.ui)
        @initialize()
        @ui.open(pending: @options.pending, focus: @options.focus).then =>
          return @ui

  updateItems: (items) =>
    @ui.emitDidUpdateItems(items)

  finishUpdateItems: (items) =>
    @updateItems(items) if items?
    @ui.emitFinishUpdateItems()

  getInitialQuery: (editor) ->
    query = @options.query or editor.getSelectedText()
    if not query and @options.queryCurrentWord
      query = getCurrentWord(editor)
      if @queryWordBoundaryOnByCurrentWordInvocation
        query = ">" + query + "<"
    query

  subscribeEditor: (args...) ->
    @editorSubscriptions.add(args...)

  filterItems: (items, filterSpec) ->
    filterSpec.filterItems(items, 'text')

  restoreEditorStateIfNecessary: ->
    if @needRestoreEditorState
      @restoreEditorState()

  destroy: ->
    if @supportReopen
      ProviderBase.saveState(this)
    @subscriptions.dispose()
    @editorSubscriptions.dispose()
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
      point = item.point
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.unfoldBufferRow(point.row)
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
    @searchOptions.toggle('searchWholeWord')

  toggleSearchIgnoreCase: ->
    @searchOptions.toggle('searchIgnoreCase')

  toggleSearchUseRegex: ->
    @searchOptions.toggle('searchUseRegex')

  # Helpers
  # -------------------------
  getFirstCharacterPointOfRow: (row) ->
    getFirstCharacterPositionForBufferRow(@editor, row)

  getFilterSpec: (filterQuery) ->
    if filterQuery
      new FilterSpec filterQuery,
        negateByEndingExclamation: @getConfig('negateNarrowQueryByEndingExclamation')
        sensitivity: @getConfig('caseSensitivityForNarrowQuery')

  updateSearchState: ->
    @searchOptions.setSearchTerm(@ui.getSearchTermFromQuery())

    if @searchOptions.grammarCanHighlight
      @ui.grammar.setSearchRegex(@searchOptions.searchRegex)
    else
      @ui.grammar.setSearchRegex(null)

    @ui.highlighter.setRegExp(@searchOptions.searchRegex)
    states = @searchOptions.pick('searchRegex', 'searchWholeWord', 'searchIgnoreCase', 'searchTerm', 'searchUseRegex')
    @ui.controlBar.updateElements(states)

  scanItemsForBuffer: (buffer, regExp) ->
    items = []
    filePath = buffer.getPath()
    regExp = cloneRegExp(regExp)
    for lineText, row in buffer.getLines()
      regExp.lastIndex = 0
      while match = regExp.exec(lineText)
        range = new Range([row, match.index], [row, match.index + match[0].length])
        items.push(text: lineText, point: range.start, range: range, filePath: filePath)
        # Avoid infinite loop in zero length match when regExp is /^/
        break unless match[0]
    items

  scanItemsForFilePath: (filePath, regExp) ->
    atom.workspace.open(filePath, activateItem: false).then (editor) =>
      return @scanItemsForBuffer(editor.buffer, regExp)
