{inspect} = require 'util'
p = (args...) -> console.log inspect(args...)
_ = require 'underscore-plus'
path = require 'path'
{Point, Range, CompositeDisposable, Disposable, Emitter} = require 'atom'
{
  getNextAdjacentPaneForPane
  getPreviousAdjacentPaneForPane
  splitPane
  isActiveEditor
  setBufferRow
  paneForItem
  isDefinedAndEqual
  ensureNoModifiedFileForChanges
  ensureNoConflictForChanges
  isNormalItem
  findEqualLocationItem
  cloneRegExp
  suppressEvent
  startMeasureMemory
  getCurrentWord
} = require './utils'

itemReducer = require './item-reducer'
settings = require './settings'
Grammar = require './grammar'
Highlighter = require './highlighter'
ControlBar = require './control-bar'
Items = require './items'
ItemIndicator = require './item-indicator'
SelectFiles = null

module.exports =
class Ui
  @uiByEditor: new Map()
  @unregister: (ui) ->
    @uiByEditor.delete(ui.editor)
    @updateWorkspaceClassList()

  @register: (ui) ->
    @uiByEditor.set(ui.editor, ui)
    @updateWorkspaceClassList()

  @get: (editor) ->
    @uiByEditor.get(editor)

  @getSize: ->
    @uiByEditor.size

  @forEach: (fn) ->
    @uiByEditor.forEach(fn)

  @updateWorkspaceClassList: ->
    atom.views.getView(atom.workspace).classList.toggle('has-narrow', @uiByEditor.size)

  @getNextTitleNumber: ->
    numbers = [0]
    @uiByEditor.forEach (ui) ->
      numbers.push(ui.titleNumber)
    Math.max(numbers...) + 1

  autoPreview: null
  autoPreviewOnQueryChange: null

  inPreview: false
  suppressPreview: false
  ignoreChange: false
  ignoreCursorMove: false
  destroyed: false
  lastQuery: ''
  lastSearchTerm: ''
  modifiedState: null
  readOnly: false
  protected: false
  excludedFiles: null
  queryForSelectFiles: null
  delayedRefreshTimeout: null

  onDidMoveToPrompt: (fn) -> @emitter.on('did-move-to-prompt', fn)
  emitDidMoveToPrompt: -> @emitter.emit('did-move-to-prompt')

  onDidUpdateItems: (fn) -> @emitter.on('did-update-items', fn)
  emitDidUpdateItems: (event) -> @emitter.emit('did-update-items', event)

  onFinishUpdateItems: (fn) -> @emitter.on('finish-update-items', fn)
  emitFinishUpdateItems: -> @emitter.emit('finish-update-items')

  onDidMoveToItemArea: (fn) -> @emitter.on('did-move-to-item-area', fn)
  emitDidMoveToItemArea: -> @emitter.emit('did-move-to-item-area')

  onDidDestroy: (fn) -> @emitter.on('did-destroy', fn)
  emitDidDestroy: -> @emitter.emit('did-destroy')

  onDidRefresh: (fn) -> @emitter.on('did-refresh', fn)
  emitDidRefresh: -> @emitter.emit('did-refresh')
  onWillRefresh: (fn) -> @emitter.on('will-refresh', fn)
  emitWillRefresh: -> @emitter.emit('will-refresh')

  onWillRefreshManually: (fn) -> @emitter.on('will-refresh-manually', fn)
  emitWillRefreshManually: -> @emitter.emit('will-refresh-manually')

  onDidStopRefreshing: (fn) -> @emitter.on('did-stop-refreshing', fn)
  emitDidStopRefreshing: ->
    # Debounced, fired after 100ms delay
    @_emitDidStopRefreshing ?= _.debounce((=> @emitter.emit('did-stop-refreshing')), 100)
    @_emitDidStopRefreshing()

  onDidPreview: (fn) -> @emitter.on('did-preview', fn)
  emitDidPreview: (event) -> @emitter.emit('did-preview', event)

  onDidConfirm: (fn) -> @emitter.on('did-confirm', fn)
  emitDidConfirm: (event) -> @emitter.emit('did-confirm', event)

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'core:move-up': (event) => @moveUpOrDownWrap(event, 'up')
      'core:move-down': (event) => @moveUpOrDownWrap(event, 'down')

      # HACK: PreserveGoalColumn when skipping header row.
      # Following command is earlily invoked than original move-up(down)-wrap,
      # because it's directly defined on @editorElement.
      # Actual movement is still done by original command since command event is propagated.
      'vim-mode-plus:move-up-wrap': => @preserveGoalColumn()
      'vim-mode-plus:move-down-wrap': => @preserveGoalColumn()

      'narrow:close': (event) => @narrowClose(event)

      'narrow-ui:confirm-keep-open': => @confirm(keepOpen: true)
      'narrow-ui:protect': => @toggleProtected()
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:preview-next-item': => @previewItemForDirection('next')
      'narrow-ui:preview-previous-item': => @previewItemForDirection('previous')
      'narrow-ui:toggle-auto-preview': @toggleAutoPreview
      'narrow-ui:move-to-prompt-or-selected-item': => @moveToPromptOrSelectedItem()
      'narrow-ui:move-to-prompt': => @moveToPrompt()
      'narrow-ui:start-insert': => @setReadOnly(false)
      'narrow-ui:stop-insert': => @setReadOnly(true)
      'narrow-ui:update-real-file': => @updateRealFile()
      'narrow-ui:exclude-file': => @excludeFile()
      'narrow-ui:select-files': @selectFiles
      'narrow-ui:clear-excluded-files': => @clearExcludedFiles()
      'narrow-ui:move-to-next-file-item': => @moveToDifferentFileItem('next')
      'narrow-ui:move-to-previous-file-item': => @moveToDifferentFileItem('previous')
      'narrow-ui:toggle-search-whole-word': @toggleSearchWholeWord
      'narrow-ui:toggle-search-ignore-case': @toggleSearchIgnoreCase
      'narrow-ui:toggle-search-use-regex': @toggleSearchUseRegex
      'narrow-ui:delete-to-beginning-of-query': => @deleteToBeginningOfQuery()

  withIgnoreCursorMove: (fn) ->
    @ignoreCursorMove = true
    fn()
    @ignoreCursorMove = false

  withIgnoreChange: (fn) ->
    @ignoreChange = true
    fn()
    @ignoreChange = false

  isModified: ->
    @modifiedState

  getState: ->
    {
      @excludedFiles
      @queryForSelectFiles
    }

  getSearchTermFromQuery: ->
    if @useFirstQueryAsSearchTerm
      @getQuery().split(/\s+/)[0]

  deleteToBeginningOfQuery: ->
    if @isAtPrompt()
      if searchTerm = @getSearchTermFromQuery()
        if searchTerm.length
          selection = @editor.getLastSelection()
          cursorPosition = selection.cursor.getBufferPosition()

          column = searchTerm.length# + 1
          if cursorPosition.column <= column
            column = 0

          range = new Range([0, column], cursorPosition)
          unless range.isEmpty()
            selection.setBufferRange(range)
            selection.delete()
        else
          @editor.deleteToBeginningOfLine()
      else
        @editor.deleteToBeginningOfLine()

  queryCurrentWord: ->
    if word = getCurrentWord(atom.workspace.getActiveTextEditor()).trim()
      @withIgnoreChange => @setQuery(word)
      @refresh(force: true).then =>
        @moveToSearchedWordOrBeginningOfSelectedItem()
        @flashCursorLine()

  setModifiedState: (state) ->
    return if state is @modifiedState

    # HACK: overwrite TextBuffer:isModified to return static state.
    # This state is used by tabs package to show modified icon on tab.
    @modifiedState = state
    @editor.buffer.isModified = -> state
    @editor.buffer.emitModifiedStatusChanged(state)

  toggleSearchWholeWord: (event) =>
    suppressEvent(event)
    @provider.toggleSearchWholeWord()
    @refresh(force: true)

  toggleSearchIgnoreCase: (event) =>
    suppressEvent(event)
    @provider.toggleSearchIgnoreCase()
    @refresh(force: true)

  toggleSearchUseRegex: (event) =>
    suppressEvent(event)
    @provider.toggleSearchUseRegex()
    @refresh(force: true)

  toggleProtected: (event) =>
    suppressEvent(event)
    @protected = not @protected
    @itemIndicator.update({@protected})
    @controlBar.updateElements({@protected})

  toggleAutoPreview: (event) =>
    suppressEvent(event)
    @autoPreview = not @autoPreview
    @controlBar.updateElements({@autoPreview})
    @highlighter.clearCurrentAndLineMarker()
    @preview() if @autoPreview

  setReadOnly: (readOnly) ->
    @readOnly = readOnly
    if @readOnly
      @editorElement.component?.setInputEnabled(false)
      @editorElement.classList.add('read-only')
      @vmpActivateNormalMode() if @vmpIsInsertMode()
    else
      @editorElement.component?.setInputEnabled(true)
      @editorElement.classList.remove('read-only')
      @vmpActivateInsertMode() if @vmpIsNormalMode()

  constructor: (@provider, {@query}={}, restoredState) ->
    if restoredState?
      # This is `narrow:reopen`, to restore STATE properties.
      Object.assign(this, restoredState)

    SelectFiles ?= require "./provider/select-files"
    # Pull never changing info-only-properties from provider.
    {
      @showSearchOption
      @showLineHeader
      @showColumnOnLineHeader
      @boundToSingleFile
      @itemHaveRange
      @supportDirectEdit
      @supportCacheItems
      @supportFilePathOnlyItemsUpdate
      @useFirstQueryAsSearchTerm
    } = @provider

    # Initial state asignment: start
    # -------------------------
    # NOTE: These state is restored when `narrow:reopen`
    # So assign initial value unless assigned.
    @queryForSelectFiles ?= SelectFiles.getLastQuery(@provider.name)

    @excludedFiles ?= []
    @filePathsForAllItems = []
    @query ?= ''
    # Initial state asignment: end

    @disposables = new CompositeDisposable
    @emitter = new Emitter
    @autoPreview = @provider.getConfig('autoPreview')
    @autoPreviewOnQueryChange = @provider.getConfig('autoPreviewOnQueryChange')
    @highlighter = new Highlighter(this)
    @itemAreaStart = Object.freeze(new Point(1, 0))

    @reducers = [
      itemReducer.spliceItemsForFilePath
      itemReducer.injectLineHeader
      itemReducer.collectAllItems
      itemReducer.filterFilePath
      @filterItems
      itemReducer.insertHeader
      @addItems
      @renderItems
    ]

    # Setup narrow-editor
    # -------------------------
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @titleNumber = @constructor.getNextTitleNumber()
    title = @provider.dashName + '-' + @titleNumber
    @editor.getTitle = -> title
    @editor.onDidDestroy(@destroy.bind(this))
    @editorElement = @editor.element
    @editorElement.classList.add('narrow', 'narrow-editor', @provider.dashName)
    @setModifiedState(false)

    @grammar = new Grammar(@editor, includeHeaderRules: not @boundToSingleFile)

    @items = new Items(this)
    @itemIndicator = new ItemIndicator(@editor)

    @items.onDidChangeSelectedItem ({row}) => @itemIndicator.update({row})

    if settings.get('autoShiftReadOnlyOnMoveToItemArea')
      @disposables.add @onDidMoveToItemArea =>
        @setReadOnly(true)

    # Depends on ui.grammar and commands bound to @editorElement, so have to come last
    @controlBar = new ControlBar(this)
    @constructor.register(this)

  getPaneToOpen: ->
    basePane = @provider.getPane()

    [direction, adjacentPanePreference] = @provider.getConfig('directionToOpen').split(':')

    pane = switch adjacentPanePreference
      when 'always-new-pane'
        null
      when 'never-use-previous-adjacent-pane'
        getNextAdjacentPaneForPane(basePane)
      else
        getNextAdjacentPaneForPane(basePane) ? getPreviousAdjacentPaneForPane(basePane)

    pane ? splitPane(basePane, split: direction)

  open: ({pending, focus}={}) ->
    pending ?= false
    focus ?= true
    # [NOTE] When new item is activated, existing PENDING item is destroyed.
    # So existing PENDING narrow-editor is destroyed at this timing.
    # And PENDING narrow-editor's provider's editor have foucsed.
    # So pane.activate must be called AFTER activateItem
    pane = @getPaneToOpen()
    pane.activateItem(@editor, {pending})

    if focus and @provider.needActivateOnStart()
      pane.activate()

    @grammar.activate()
    @setQuery(@query)
    @controlBar.show()
    @moveToPrompt()

    @disposables.add(
      @registerCommands()
      @observeChange()
      @observeCursorMove()
    )

    @refresh().then =>
      if @provider.needRevealOnStart()
        @syncToEditor(@provider.editor)
        if @items.hasSelectedItem()
          @suppressPreview = true
          @moveToSearchedWordOrBeginningOfSelectedItem()
          @suppressPreview = false
          @preview()?.then? => @flashCursorLine()
      else if @query and @autoPreviewOnQueryChange
        @preview()

  flashCursorLine: ->
    itemCount = @items.getCount()
    return if itemCount <= 5

    flashSpec =
      if itemCount < 10
        duration: 1000
        class: 'narrow-cursor-line-flash-medium'
      else
        duration: 2000
        class: 'narrow-cursor-line-flash-long'

    @cursorLineFlashMarker?.destroy()
    point = @editor.getCursorBufferPosition()
    @cursorLineFlashMarker = @editor.markBufferPosition(point)
    decorationOptions = {type: 'line', class: flashSpec.class}
    @editor.decorateMarker(@cursorLineFlashMarker, decorationOptions)

    destroyMarker = =>
      @cursorLineFlashMarker?.destroy()
      @cursorLineFlashMarker = null
    setTimeout(destroyMarker, flashSpec.duration)

  getPane: ->
    paneForItem(@editor)

  isSamePaneItem: (item) ->
    paneForItem(item) is @getPane()

  isActive: ->
    isActiveEditor(@editor)

  focus: ({autoPreview}={}) ->
    pane = @getPane()
    pane.activate()
    pane.activateItem(@editor)
    if autoPreview ? @autoPreview
      @preview()

  focusPrompt: ->
    if @isActive() and @isAtPrompt()
      @activateProviderPane()
    else
      @focus() unless @isActive()
      @moveToPrompt()

  toggleFocus: ->
    if @isActive()
      @activateProviderPane()
    else
      @focus()

  activateProviderPane: ->
    if pane = @provider.getPane()
      # [BUG?] maybe upstream Atom-core bug?
      # In rare situation( I observed only in test-spec ), there is the situation
      # where pane.isAlive but paneContainer.getPanes() in pane return `false`
      # Without folowing guard "Setting active pane that is not present in pane container"
      # exception thrown.
      if pane in pane.getContainer().getPanes()
        pane.activate()
        if editor = pane.getActiveEditor()
          editor.scrollToCursorPosition()

  isAlive: ->
    not @destroyed

  destroy: ->
    return if @destroyed

    @destroyed = true

    # NOTE: Prevent delayed-refresh on destroyed editor.
    @cancelDelayedRefresh()
    @refreshDisposables?.dispose()

    @constructor.unregister(this)
    @highlighter.destroy()
    @syncSubcriptions?.dispose()
    @disposables.dispose()
    @editor.destroy()
    unless @provider.name is 'SelectFiles'
      @activateProviderPane()

    @controlBar.destroy()
    @provider?.destroy?()
    @items.destroy()
    @itemIndicator.destroy()
    @emitDidDestroy()

  # This function is mapped from `narrow:close`
  # To differentiate `narrow:close` for protected narrow-editor.
  # * Two purpose.
  # 1. So that don't close non-protected narrow-editor when narrow:close is
  #   invoked from protected narrow-editor
  # 2. To re-focus to caller editor for not interfering regular preview-then-close-by-ctrl-g flow.
  narrowClose: (event) ->
    if @protected
      event.stopImmediatePropagation()
      @resetQuery()
      @activateProviderPane()

  resetQuery: ->
    @setQuery() # clear query
    @moveToPrompt()
    @controlBar.show()

  preserveGoalColumn: ->
    # HACK: In narrow-editor, header row is skipped onDidChangeCursorPosition event
    # But at this point, cursor.goalColumn is explicitly cleared by atom-core
    # I want use original goalColumn info within onDidChangeCursorPosition event
    # to keep original column when header item was auto-skipped.
    cursor = @editor.getLastCursor()
    @goalColumn = cursor.goalColumn ? cursor.getBufferColumn()

  # Line-wrapped version of 'core:move-up' override default behavior
  moveUpOrDownWrap: (event, direction) ->
    @preserveGoalColumn()

    cursor = @editor.getLastCursor()
    cursorRow = cursor.getBufferRow()
    lastRow = @editor.getLastBufferRow()

    if direction is 'up' and cursorRow is 0
      setBufferRow(cursor, lastRow)
      event.stopImmediatePropagation()
    else if direction is 'down' and cursorRow is lastRow
      setBufferRow(cursor, 0)
      event.stopImmediatePropagation()

  # Even in movemnt not happens, it should confirm current item
  # This ensure next-item/previous-item always move to selected item.
  confirmItemForDirection: (direction) ->
    point = @provider.editor.getCursorBufferPosition()
    @items.selectItemInDirection(point, direction)
    @confirm(keepOpen: true, flash: true)

  previewItemForDirection: (direction) ->
    rowForSelectedItem = @items.getRowForSelectedItem()
    if not @highlighter.hasLineMarker() and direction is 'next'
      # When initial invocation not cause preview(since initial query input was empty).
      # Don't want `tab` skip first seleted item.
      row = rowForSelectedItem
    else
      row = @items.findRowForNormalItem(rowForSelectedItem, direction)

    if row?
      @items.selectItemForRow(row)
      @preview()

  getQuery: ->
    @editor.getTextInBufferRange(@getPromptRange())

  getFilterQuery: ->
    if @useFirstQueryAsSearchTerm
      # Extracet filterQuery by removing searchTerm part from query
      @getQuery().replace(/^.*?\S+\s*/, '')
    else
      @getQuery()

  excludeFile: ->
    return if @boundToSingleFile

    filePath = @items.getSelectedItem()?.filePath
    if filePath? and (filePath not in @excludedFiles)
      @excludedFiles.push(filePath)
      @moveToDifferentFileItem('next')
      @refresh()

  selectFiles: (event) =>
    suppressEvent(event)
    return if @boundToSingleFile
    options =
      query: @queryForSelectFiles
      clientUi: this
    new SelectFiles(@editor, options).start()

  resetQueryForSelectFiles: (@queryForSelectFiles) ->
    @excludedFiles = []
    @focus(autoPreview: false)
    @refresh()

  clearExcludedFiles: ->
    return if @boundToSingleFile
    @excludedFiles = []
    @queryForSelectFiles = ''
    @refresh()

  requestItems: (event) ->
    if @items.cachedItems?
      @emitDidUpdateItems(@items.cachedItems)
      @emitFinishUpdateItems()
    else
      @provider.getItems(event.filePath)

  # reducer
  filterItems: (state) =>
    if state.filterSpec?
      items = @provider.filterItems(state.items, state.filterSpec)
      return {items}
    else
      return null

  # reducer
  addItems: (state) =>
    @items.addItems(state.items)
    return null

  reduceItems: (items, state) ->
    @reducers.reduce (state, reducer) ->
      Object.assign(state, reducer(state))
    , Object.assign(state, {items, reduced: true})

  createStateToReduce: ->
    {
      reduced: false
      hasCachedItems: @items.cachedItems?
      showLineHeader: @showLineHeader
      showColumn: @showColumnOnLineHeader
      maxRow: @provider.editor.getLastBufferRow() if @boundToSingleFile
      boundToSingleFile: @boundToSingleFile
      projectHeadersInserted: {}
      fileHeadersInserted: {}
      allItems: []
      filterSpec: @provider.getFilterSpec(@getFilterQuery())
      filterSpecForSelectFiles: SelectFiles::getFilterSpec(@queryForSelectFiles)
      fileExcluded: false
      excludedFiles: @excludedFiles
      renderStartPosition: @itemAreaStart
    }

  startUpdateItemCount: ->
    updateItemCount = => @controlBar.updateElements(itemCount: @items.getCount())
    intervalID = setInterval(updateItemCount, 500)
    new Disposable ->
      clearInterval(intervalID)
      intervalID = null

  getFilePathsForAllItems: ->
    @filePathsForAllItems

  updateRefreshRunningElement: =>
    @controlBar.updateElements(refresh: true)

  updateControlBarRefreshElement: ->
    if @query?
      @editor.getLastCursor().setVisible?(false)
      timeoutID = setTimeout(@updateRefreshRunningElement, 300)
      new Disposable =>
        @editor.getLastCursor().setVisible?(true)
        clearTimeout(timeoutID)
    else
      @updateRefreshRunningElement()
      return new Disposable()

  cancelRefresh: ->
    if @refreshDisposables?
      @refreshDisposables.dispose()
      @refreshDisposables = null

  # Return promise
  refresh: ({force, selectFirstItem, filePath}={}) ->
    @cancelRefresh()
    @refreshDisposables = new CompositeDisposable
    @filePathsForAllItems = []
    @highlighter.clearCurrentAndLineMarker()
    @emitWillRefresh()

    @refreshDisposables.add(
      @updateControlBarRefreshElement()
      @startUpdateItemCount()
    )

    @lastQuery = @getQuery()
    if @useFirstQueryAsSearchTerm
      if @lastSearchTerm isnt (searchTerm = @getSearchTermFromQuery())
        @lastSearchTerm = searchTerm
        force = true

    if @supportFilePathOnlyItemsUpdate and filePath?
      cachedNormalItems = @items.cachedItems?.filter(isNormalItem)

    if force
      @items.clearCachedItems()

    [resolveGetItem, oldSelectedItem, oldColumn] = []
    grammarUpdated = false
    getItemPromise = new Promise (resolve) -> resolveGetItem = resolve

    state = @createStateToReduce()
    Object.assign(state, {cachedNormalItems, spliceFilePath: filePath})

    @refreshDisposables.add @onDidUpdateItems (items) =>
      unless grammarUpdated
        @grammar.update(state.filterSpec?.include) # No need to highlight excluded items
        grammarUpdated = true
      @reduceItems(items, state)

    @refreshDisposables.add @onFinishUpdateItems =>
      # After requestItems, no items sent via @onDidUpdateItems.
      # manually update with empty items.
      # e.g.
      #   1. search `editor` found 100 items
      #   2. search `editorX` found 0 items (clear items via emitDidUpdateItems([]))
      @emitDidUpdateItems([]) unless state.reduced
      @cancelRefresh()

      unless @boundToSingleFile
        @filePathsForAllItems = _.chain(state.allItems).pluck('filePath').uniq().value()

      if @supportCacheItems
        @items.setCachedItems(state.allItems)

      if (not selectFirstItem) and oldSelectedItem?
        @items.selectEqualLocationItem(oldSelectedItem)
        @moveToSelectedItem(ignoreCursorMove: not @isActive(), column: oldColumn) unless @isAtPrompt()
      else
        # when originally selected item cannot be selected because of excluded.
        @items.selectFirstNormalItem()
        @moveToPrompt() unless @isAtPrompt()

      @controlBar.updateElements(
        selectFiles: state.fileExcluded
        itemCount: @items.getCount()
        refresh: false
      )
      resolveGetItem()

    # Preserve oldSelectedItem before calling @items.reset()
    oldSelectedItem = @items.getSelectedItem()
    oldColumn = @editor.getCursorBufferPosition().column

    @items.reset()
    @requestItems({filePath})

    getItemPromise.then =>
      @emitDidRefresh()
      @emitDidStopRefreshing()
      return null

  refreshManually: (event) =>
    suppressEvent(event)
    @emitWillRefreshManually()
    @refresh(force: true)

  # reducer
  # -------------------------
  renderItems: (state) =>
    {renderStartPosition} = state
    renderStartFromItemAreaStart = renderStartPosition.isEqual(@itemAreaStart)
    if not state.items.length and not renderStartFromItemAreaStart
      return null

    texts = state.items.map (item) => @provider.viewForItem(item)
    @withIgnoreChange =>
      if @editor.getLastBufferRow() is 0
        @resetQuery()

      eof = @editor.getEofBufferPosition()
      text = ""
      text += "\n" unless renderStartFromItemAreaStart
      text += texts.join("\n")
      range = [renderStartPosition, eof]
      renderStartPosition = @editor.setTextInBufferRange(range, text, undo: 'skip').end
      @editorLastRow = renderStartPosition.row
      @setModifiedState(false)

    return {renderStartPosition}

  observeChange: ->
    onPrompt = (range) =>
      range.intersectsWith(@getPromptRange())
    isQueryModified = (newRange, oldRange) ->
      (not newRange.isEmpty() and onPrompt(newRange)) or
        (not oldRange.isEmpty() and onPrompt(oldRange))

    destroyPromptSelection = =>
      selectionDestroyed = false
      for selection in @editor.getSelections() when onPrompt(selection.getBufferRange())
        selectionDestroyed = true
        selection.destroy()
      @controlBar.show() if selectionDestroyed
      @withIgnoreChange => @setQuery(@lastQuery) # Recover query

    @editor.buffer.onDidChange (event) =>
      return if @ignoreChange
      if isQueryModified(event.newRange, event.oldRange)
        if @editor.hasMultipleCursors()
          # Destroy cursors on prompt to protect query from mutation on 'find-and-replace:select-all'( cmd-alt-g ).
          destroyPromptSelection()
        else
          return if @lastQuery.trim() is @getQuery().trim()
          @refreshWithDelay()
      else
        # Item area modified, direct editor
        @setModifiedState(true)

  # Delayed-refresh on query-change event, dont use this for other purpose.
  refreshWithDelay: ->
    @cancelDelayedRefresh()
    if @useFirstQueryAsSearchTerm and @getSearchTermFromQuery() isnt @lastSearchTerm
      delay = @provider.getConfig('refreshDelayOnSearchTermChange')
    else
      delay = if @boundToSingleFile then 0 else 100

    refreshThenPreview = =>
      @delayedRefreshTimeout = null
      @refresh(selectFirstItem: true).then =>
        if @autoPreviewOnQueryChange and @isActive()
          @preview()

    @delayedRefreshTimeout = setTimeout(refreshThenPreview, delay)

  cancelDelayedRefresh: ->
    if @delayedRefreshTimeout?
      clearTimeout(@delayedRefreshTimeout)
      @delayedRefreshTimeout = null

  observeCursorMove: ->
    @editor.onDidChangeCursorPosition (event) =>
      return if @ignoreCursorMove

      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event

      # Clear preserved @goalColumn as early as possible to not affect other
      # movement commands.
      goalColumn = @goalColumn ? newBufferPosition.column
      @goalColumn = null

      return if textChanged or
        (not cursor.selection.isEmpty()) or
        (oldBufferPosition.row is newBufferPosition.row)

      newRow = newBufferPosition.row
      oldRow = oldBufferPosition.row

      if isHeaderRow = not @isPromptRow(newRow) and not @items.isNormalItemRow(newRow)
        headerWasSkipped = true
        direction = if newRow > oldRow then 'next' else 'previous'
        newRow = @items.findRowForNormalOrPromptItem(newRow, direction)

      if @isPromptRow(newRow)
        if headerWasSkipped
          @withIgnoreCursorMove =>
            @editor.setCursorBufferPosition([newRow, goalColumn])
        @emitDidMoveToPrompt()
      else
        @items.selectItemForRow(newRow)
        if headerWasSkipped
          @moveToSelectedItem({column: goalColumn})
        @emitDidMoveToItemArea() if @isPromptRow(oldRow)
        if @autoPreview
          @previewWithDelay()

  # itemHaveAlreadyOpened: ->
  selectedItemFileHaveAlreadyOpened: ->
    if @boundToSingleFile
      true
    else
      @provider.getPane()?.itemForURI(@items.getSelectedItem().filePath)

  previewWithDelay: ->
    @cancelDelayedPreview()
    delay = if @selectedItemFileHaveAlreadyOpened() then 0 else 20
    preview = =>
      @delayedPreviewTimeout = null
      @preview()

    @delayedPreviewTimeout = setTimeout(preview, delay)

  cancelDelayedPreview: ->
    if @delayedPreviewTimeout?
      clearTimeout(@delayedPreviewTimeout)
      @delayedPreviewTimeout = null

  syncToEditor: (editor) ->
    return if @inPreview

    point = editor.getCursorBufferPosition()
    if @boundToSingleFile
      item = @items.findClosestItemForBufferPosition(point)
    else
      item = @items.findClosestItemForBufferPosition(point, filePath: editor.getPath())

    if item?
      @items.selectItem(item)
      wasAtPrompt = @isAtPrompt()
      @moveToSelectedItem(scrollToColumnZero: true)
      @emitDidMoveToItemArea() if wasAtPrompt

  isInSyncToProviderEditor: ->
    @boundToSingleFile or @items.getSelectedItem().filePath is @provider.editor.getPath()

  moveToSelectedItem: ({scrollToColumnZero, ignoreCursorMove, column}={}) ->
    return if (row = @items.getRowForSelectedItem()) is -1

    point = scrollPoint = [row, column ? @editor.getCursorBufferPosition().column]
    scrollPoint = [row, 0] if scrollToColumnZero

    moveAndScroll = =>
      # Manually set cursor to center to avoid scrollTop drastically changes
      # when refresh and auto-sync.
      @editor.setCursorBufferPosition(point, autoscroll: false)
      @editor.scrollToBufferPosition(scrollPoint, center: true)

    if ignoreCursorMove ? true
      @withIgnoreCursorMove(moveAndScroll)
    else
      moveAndScroll()

  preview: =>
    return if @suppressPreview
    return unless @isActive()
    return unless item = @items.getSelectedItem()

    @inPreview = true
    @provider.openFileForItem(item, activatePane: false).then (editor) =>
      editor.scrollToBufferPosition(item.point, center: true)
      @inPreview = false
      @emitDidPreview({editor, item})

  confirm: ({keepOpen, flash}={}) ->
    return unless item = @items.getSelectedItem()
    needDestroy = not keepOpen and not @protected and @provider.getConfig('closeOnConfirm')
    @provider.confirmed(item).then (editor) =>
      if needDestroy or not editor?
        # when editor.destroyed here, setScrollTop request done at @provider.confirmed is
        # not correctly respected unless updateSyncing here.
        editor.element.component.updateSync()
        @editor.destroy()
      else
        @highlighter.flashItem(editor, item) if flash
        @emitDidConfirm({editor, item})

  # Cursor move and position status
  # ------------------------------
  isAtSelectedItem: ->
    @editor.getCursorBufferPosition().row is @items.getRowForSelectedItem()

  moveToDifferentFileItem: (direction) ->
    unless @isAtSelectedItem()
      @moveToSelectedItem(ignoreCursorMove: false)
      return

    # Fallback to selected item in case there is only single filePath in all items
    # But want to move to item from query-prompt.
    if item = @items.findDifferentFileItem(direction) ? @items.getSelectedItem()
      @items.selectItem(item)
      @moveToSelectedItem(ignoreCursorMove: false)

  moveToPromptOrSelectedItem: ->
    if @isAtSelectedItem()
      @moveToPrompt()
    else
      @moveToBeginningOfSelectedItem()

  moveToSearchedWordOrBeginningOfSelectedItem: ->
    if @provider.searchRegex?
      @moveToSearchedWordAtSelectedItem(@provider.searchRegex)
    else
      @moveToBeginningOfSelectedItem()

  moveToBeginningOfSelectedItem: ->
    if @items.hasSelectedItem()
      point = @items.getFirstPositionForSelectedItem()
      @editor.setCursorBufferPosition(point)

  moveToSearchedWordAtSelectedItem: (searchRegex) ->
    if item = @items.getSelectedItem()
      cursorPosition = @provider.editor.getCursorBufferPosition()
      {row, column} = @items.getFirstPositionForItem(item)

      if @isInSyncToProviderEditor()
        column += cursorPosition.column
      else
        column += cloneRegExp(searchRegex).exec(item.text).index

      @editor.setCursorBufferPosition([row, column])

  moveToPrompt: ->
    @withIgnoreCursorMove =>
      @editor.setCursorBufferPosition(@getPromptRange().end)
      @setReadOnly(false)
      @emitDidMoveToPrompt()

  isPromptRow: (row) ->
    row is 0

  isAtPrompt: ->
    @isPromptRow(@editor.getCursorBufferPosition().row)

  getNormalItemsForEditor: (editor) ->
    if @boundToSingleFile
      @items.getNormalItems()
    else
      @items.getNormalItems(editor.getPath())

  getPromptRange: ->
    @editor.bufferRangeForBufferRow(0)

  # Return range
  setQuery: (text='') ->
    if @editor.getLastBufferRow() is 0
      @editor.setTextInBufferRange([[0, 0], @itemAreaStart], text + "\n")
    else
      @editor.setTextInBufferRange([[0, 0], [0, Infinity]], text)

  startSyncToEditor: (editor) ->
    @syncSubcriptions?.dispose()
    @syncSubcriptions = new CompositeDisposable

    oldFilePath = @provider.editor.getPath()
    newFilePath = editor.getPath()

    @provider.bindEditor(editor)
    @syncToEditor(editor)

    @syncSubcriptions.add editor.onDidChangeCursorPosition (event) =>
      return if event.textChanged
      return if not @itemHaveRange and (event.oldBufferPosition.row is event.newBufferPosition.row)
      @syncToEditor(editor) if isActiveEditor(editor)

    @syncSubcriptions.add @onDidRefresh =>
      @syncToEditor(editor) if isActiveEditor(editor)

    if @boundToSingleFile
      unless isDefinedAndEqual(oldFilePath, newFilePath)
        @refresh(force: true)
      @syncSubcriptions.add editor.onDidStopChanging =>
        @refresh(force: true) unless @isActive()
    else
      @syncSubcriptions.add editor.onDidSave (event) =>
        unless @isActive()
          setTimeout =>
            @refresh(force: true, filePath: event.path)
          , 0

  # vim-mode-plus integration
  # -------------------------
  vmpActivateNormalMode: ->
    atom.commands.dispatch(@editorElement, 'vim-mode-plus:activate-normal-mode')

  vmpActivateInsertMode: ->
    atom.commands.dispatch(@editorElement, 'vim-mode-plus:activate-insert-mode')

  vmpIsInsertMode: ->
    @vmpIsEnabled() and @editorElement.classList.contains('insert-mode')

  vmpIsNormalMode: ->
    @vmpIsEnabled() and @editorElement.classList.contains('normal-mode')

  vmpIsEnabled: ->
    @editorElement.classList.contains('vim-mode-plus')

  # Direct-edit related
  # -------------------------
  updateRealFile: ->
    return unless @supportDirectEdit
    return unless @isModified()

    if settings.get('confirmOnUpdateRealFile')
      unless atom.confirm(message: 'Update real file?', buttons: ['Update', 'Cancel']) is 0
        return

    return if @editorLastRow isnt @editor.getLastBufferRow()

    # Ensure all item have valid line header
    if @showLineHeader
      itemHaveOriginalLineHeader = (item) =>
        @editor.lineTextForBufferRow(@items.getRowForItem(item)).startsWith(item._lineHeader)
      unless @items.getNormalItems().every(itemHaveOriginalLineHeader)
        return

    changes = []
    lines = @editor.buffer.getLines()
    for line, row in lines when isNormalItem(item = @items.getItemForRow(row))
      if item._lineHeader?
        line = line[item._lineHeader.length...] # Strip lineHeader
      if line isnt item.text
        changes.push({newText: line, item})

    return unless changes.length

    unless @boundToSingleFile
      {success, message} = ensureNoModifiedFileForChanges(changes)
      unless success
        atom.notifications.addWarning(message, dismissable: true)
        return

    {success, message} = ensureNoConflictForChanges(changes)
    unless success
      atom.notifications.addWarning(message, dismissable: true)
      return

    @provider.updateRealFile(changes)
    @setModifiedState(false)
