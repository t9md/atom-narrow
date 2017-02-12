_ = require 'underscore-plus'
{Point, Range, CompositeDisposable, Emitter, Disposable} = require 'atom'
{
  getAdjacentPaneOrSplit
  isActiveEditor
  getValidIndexForList
  setBufferRow
  isTextEditor
  isNarrowEditor
  paneForItem
} = require './utils'
settings = require './settings'
Grammar = require './grammar'
getFilterSpecForQuery = require './get-filter-spec-for-query'
Highlighter = require './highlighter'
ItemIndicator = require './item-indicator'
ProviderPanel = require './provider-panel'

module.exports =
class UI
  # UI static
  # -------------------------
  @uiByEditor: new Map()
  @unregister: (ui) ->
    @uiByEditor.delete(ui.editor)
    @updateWorkspaceClassList()

  @register: (ui) ->
    @uiByEditor.set(ui.editor, ui)
    @updateWorkspaceClassList()

  @get: (editor) ->
    @uiByEditor.get(editor)

  @updateWorkspaceClassList: ->
    atom.views.getView(atom.workspace).classList.toggle('has-narrow', @uiByEditor.size)

  @getNextTitleNumber: ->
    numbers = [0]
    @uiByEditor.forEach (ui) ->
      numbers.push(ui.titleNumber)
    Math.max(numbers...) + 1

  # UI.prototype
  # -------------------------
  selectedItem: null
  previouslySelectedItem: null

  stopRefreshingDelay: 100
  stopRefreshingTimeout: null
  debouncedPreviewDelay: 100

  autoPreview: null
  autoPreviewOnQueryChange: null

  preventSyncToEditor: false
  ignoreChange: false
  ignoreCursorMove: false
  destroyed: false
  items: []
  cachedItems: null # Used to cache result
  lastQuery: ''
  modifiedState: null
  readOnly: false
  protected: false
  excludedFiles: null

  onDidMoveToPrompt: (fn) -> @emitter.on('did-move-to-prompt', fn)
  emitDidMoveToPrompt: -> @emitter.emit('did-move-to-prompt')

  onDidMoveToItemArea: (fn) -> @emitter.on('did-move-to-item-area', fn)
  emitDidMoveToItemArea: -> @emitter.emit('did-move-to-item-area')

  onDidRefresh: (fn) -> @emitter.on('did-refresh', fn)
  emitDidRefresh: -> @emitter.emit('did-refresh')
  onWillRefresh: (fn) -> @emitter.on('will-refresh', fn)
  emitWillRefresh: -> @emitter.emit('will-refresh')

  onDidChangeSelectedItem: (fn) -> @emitter.on('did-change-selected-item', fn)
  emitDidChangeSelectedItem: (event) -> @emitter.emit('did-change-selected-item', event)

  # 'did-stop-refreshing' event is debounced, fired after stopRefreshingDelay
  onDidStopRefreshing: (fn) -> @emitter.on('did-stop-refreshing', fn)
  emitDidStopRefreshing: ->
    clearTimeout(@stopRefreshingTimeout) if @stopRefreshingTimeout?
    stopRefreshingCallback = =>
      @stopRefreshingTimeout = null
      @emitter.emit('did-stop-refreshing')

    @stopRefreshingTimeout = setTimeout(stopRefreshingCallback, @stopRefreshingDelay)

  onDidPreview: (fn) -> @emitter.on('did-preview', fn)
  emitDidPreview: (event) -> @emitter.emit('did-preview', event)

  onDidConfirm: (fn) -> @emitter.on('did-confirm', fn)
  emitDidConfirm: (event) -> @emitter.emit('did-confirm', event)

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'narrow:close': (event) => @narrowClose(event)
      'narrow-ui:confirm-keep-open': => @confirm(keepOpen: true)
      'narrow-ui:protect': => @toggleProtected()
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:preview-next-item': => @previewNextItem()
      'narrow-ui:preview-previous-item': => @previewPreviousItem()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()
      'narrow-ui:move-to-prompt-or-selected-item': => @moveToPromptOrSelectedItem()
      'narrow-ui:move-to-prompt': => @moveToPrompt()
      'narrow-ui:start-insert': => @setReadOnly(false)
      'narrow-ui:stop-insert': => @setReadOnly(true)
      'core:move-up': (event) => @moveUpOrDown(event, 'previous')
      'core:move-down': (event) => @moveUpOrDown(event, 'next')
      'narrow-ui:update-real-file': => @updateRealFile()
      'narrow-ui:exclude-file': => @excludeFile()
      'narrow-ui:clear-excluded-files': => @clearExcludedFiles()
      'narrow-ui:move-to-next-file-item': => @moveToNextFileItem()
      'narrow-ui:move-to-previous-file-item': => @moveToPreviousFileItem()
      'narrow-ui:toggle-search-whole-word': => @toggleSearchWholeWord()
      'narrow-ui:toggle-search-ignore-case': => @toggleSearchIgnoreCase()

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

  setModifiedState: (state) ->
    if state isnt @modifiedState
      # HACK: overwrite TextBuffer:isModified to return static state.
      # This state is used for tabs package to show modified icon on tab.
      @modifiedState = state
      @editor.buffer.isModified = -> state
      @editor.buffer.emitModifiedStatusChanged(state)

  toggleSearchWholeWord: ->
    @provider.toggleSearchWholeWord()
    @refresh(force: true)
    @updateProviderPanel(wholeWordButton: @provider.searchWholeWord)

  toggleSearchIgnoreCase: ->
    @provider.toggleSearchIgnoreCase()
    @refresh(force: true)
    @updateProviderPanel(ignoreCaseButton: @provider.searchIgnoreCase)

  toggleProtected: ->
    @protected = not @protected
    @itemIndicator.redraw()
    @updateProviderPanel({@protected})

  toggleAutoPreview: ->
    @autoPreview = not @autoPreview
    @updateProviderPanel({@autoPreview})
    if @autoPreview
      @preview()
    else
      @highlighter.clearLineMarker()

  setReadOnly: (readOnly) ->
    @readOnly = readOnly
    if @readOnly
      @editorElement.component?.setInputEnabled(false)
      @editorElement.classList.add('read-only')
      @vmpActivateNormalMode() if @vmpIsInsertMode()
    else
      @editorElement.component.setInputEnabled(true)
      @editorElement.classList.remove('read-only')
      @vmpActivateInsertMode() if @vmpIsNormalMode()

  constructor: (@provider, {@query, @activate, @pending}={}) ->
    @titleNumber = @constructor.getNextTitleNumber()
    @pending ?= false
    @activate ?= true
    @disposables = new CompositeDisposable
    @emitter = new Emitter
    @excludedFiles = []
    @autoPreview = @provider.getConfig('autoPreview')
    @autoPreviewOnQueryChange = @provider.getConfig('autoPreviewOnQueryChange')
    @highlighter = new Highlighter(this)

    # Special place holder item used to translate narrow-editor row to item row without mess.
    @promptItem = Object.freeze({_prompt: true, skip: true})
    @itemAreaStart = Object.freeze(new Point(1, 0))

    # Setup narrow-editor
    # -------------------------
    # Hide line number gutter for empty indent provider
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: @provider.indentTextForLineHeader)

    providerDashName = @provider.getDashName()
    title = providerDashName + '-' + @titleNumber
    @editor.getTitle = -> title
    @editor.onDidDestroy(@destroy.bind(this))
    @editorElement = @editor.element
    @editorElement.classList.add('narrow', 'narrow-editor', providerDashName)

    @grammar = new Grammar(@editor, includeHeaderRules: @provider.includeHeaderGrammar)

    @itemIndicator = new ItemIndicator(this)

    if settings.get('autoShiftReadOnlyOnMoveToItemArea')
      @disposables.add @onDidMoveToItemArea =>
        @setReadOnly(true)

    @disposables.add(
      @registerCommands()
      @observeChange()
      @observeCursorMove()
      @observeStopChangingActivePaneItem()
    )
    # Depends on ui.grammar and commands bound to @editorElement, so have to come last
    @providerPanel = new ProviderPanel(this, showSearchOption: @provider.showSearchOption)

    @constructor.register(this)
    @disposables.add new Disposable =>
      @constructor.unregister(this)

  start: ->
    # When initial getItems() take very long time, it means refresh get delayed.
    # In this case, user see modified icon(mark) on tab.
    # Explicitly setting modified start here prevent this
    @setModifiedState(false)

    providerPane = @provider.getPane()
    if isNarrowEditor(@provider.editor)
      # If narrow is invoked from narrow-editor, open in same pane.
      pane = providerPane
    else
      pane = getAdjacentPaneOrSplit(providerPane, split: settings.get('directionToOpen'))
    pane.activate() unless pane.isActive()
    pane.activateItem(@editor, {@pending})
    @grammar.activate()
    if @query
      @insertQuery(@query)
    else
      @withIgnoreChange => @insertQuery()
    @providerPanel.show()
    @moveToPrompt()
    @refresh().then =>
      @activateProviderPane() unless @activate

  observeStopChangingActivePaneItem: ->
    needToSync = (item) =>
      isTextEditor(item) and not isNarrowEditor(item) and paneForItem(item) isnt @getPane()

    atom.workspace.onDidStopChangingActivePaneItem (item) =>
      @syncSubcriptions?.dispose()
      return if item is @editor

      @provider.needRestoreEditorState = false
      return unless needToSync(item)

      if @provider.boundToEditor
        if @provider.editor is item
          @startSyncToEditor(item)
        else
          @provider.bindEditor(item)
          @refresh(force: true).then =>
            @startSyncToEditor(item)
      else
        @startSyncToEditor(item) if @hasSomeNormalItemForFilePath(item.getPath())

  getPane: ->
    paneForItem(@editor)

  isActive: ->
    isActiveEditor(@editor)

  focus: ->
    pane = @getPane()
    pane.activate()
    pane.activateItem(@editor)
    @preview() if @autoPreview

  focusPrompt: ->
    if @isActive() and @isPromptRow(@editor.getCursorBufferPosition().row)
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
      pane.activate()
      activeItem = pane.getActiveItem()
      if isTextEditor(activeItem)
        activeItem.scrollToCursorPosition()

  destroy: ->
    return if @destroyed
    @destroyed = true
    @highlighter.destroy()
    @syncSubcriptions?.dispose()
    @disposables.dispose()
    @editor.destroy()
    @activateProviderPane()

    @providerPanel.destroy()
    @provider?.destroy?()
    @itemIndicator?.destroy()

  # This function is mapped from `narrow:close`
  # To differentiate `narrow:close` for protected narrow-editor.
  # * Two purpose.
  # 1. So that don't close non-protected narrow-editor when narrow:close is
  #   invoked from protected narrow-editor
  # 2. To re-focus to caller editor for not interfering regular preview-then-close-by-ctrl-g flow.
  narrowClose: (event) ->
    if @protected
      event.stopImmediatePropagation()
      @insertQuery() # clear query
      @activateProviderPane()

  # Just setting cursor position works but it lost goalColumn when that row was skip item's row.
  moveUpOrDown: (event, direction) ->
    cursor = @editor.getLastCursor()
    row = cursor.getBufferRow()

    if (direction is 'next' and row is @editor.getLastBufferRow()) or
        (direction is 'previous' and @isPromptRow(row))
      # This is the command which override `core:move-up`, `core-move-down`
      # So when this command do work, it stop propagation, unless that case
      # this command do nothing and default behavior is still executed.
      ensureCursorIsOneColumnLeftFromEOL = @vmpIsNormalMode()
      event.stopImmediatePropagation()
      row = @findRowForNormalOrPromptItem(row, direction)
      setBufferRow(cursor, row, {ensureCursorIsOneColumnLeftFromEOL})

  # Even in movemnt not happens, it should confirm current item
  # This ensure next-item/previous-item always move to selected item.
  confirmItemForDirection: (direction) ->
    row = @findRowForNormalItem(@getRowForSelectedItem(), direction)
    if row?
      @selectItemForRow(row)
      @confirm(keepOpen: true, flash: true)

  nextItem: ->
    cursorPosition = atom.workspace.getActiveTextEditor().getCursorBufferPosition()
    item = @getSelectedItem()
    if item? and cursorPosition.isLessThan(item.range?.start ? item.point)
      @confirm(keepOpen: true, flash: true)
    else
      @confirmItemForDirection('next')

  previousItem: ->
    cursorPosition = atom.workspace.getActiveTextEditor().getCursorBufferPosition()
    item = @getSelectedItem()
    if item? and cursorPosition.isGreaterThan(item.range?.end ? item.point)
      @confirm(keepOpen: true, flash: true)
    else
      @confirmItemForDirection('previous')

  previewItemForDirection: (direction) ->
    if not @highlighter.hasLineMarker() and direction is 'next'
      # When initial invocation not cause preview(since initial query input was empty).
      # Don't want `tab` skip first seleted item.
      row = @getRowForSelectedItem()
    else
      row = @findRowForNormalItem(@getRowForSelectedItem(), direction)

    if row?
      @selectItemForRow(row)
      @preview()

  previewNextItem: ->
    @previewItemForDirection('next')

  previewPreviousItem: ->
    @previewItemForDirection('previous')

  getQuery: ->
    @lastQuery = @editor.lineTextForBufferRow(0)

  excludeFile: ->
    return if @provider.boundToEditor
    return unless selectedItem = @getSelectedItem()
    unless selectedItem.filePath in @excludedFiles
      @excludedFiles.push(selectedItem.filePath)
      nextFileItem = @findDifferentFileItem('next')
      {column} = @editor.getCursorBufferPosition()
      @refresh().then =>
        if nextFileItem
          @selectItem(nextFileItem)
          @moveToSelectedItem(ignoreCursorMove: false)
          {row} = @editor.getCursorBufferPosition()
          @editor.setCursorBufferPosition([row, column])

  clearExcludedFiles: ->
    return if @excludedFiles.length is 0
    @excludedFiles = []
    selectedItem = @getSelectedItem()
    {column} = @editor.getCursorBufferPosition()
    @refresh().then =>
      if selectedItem
        @selectItem(selectedItem)
        @moveToSelectedItem(ignoreCursorMove: false)
        {row} = @editor.getCursorBufferPosition()
        @editor.setCursorBufferPosition([row, column])

  refresh: ({force}={}) ->
    @emitWillRefresh()

    if force
      @cachedItems = null

    if @cachedItems?
      promiseForItems = Promise.resolve(@cachedItems)
    else
      promiseForItems = Promise.resolve(@provider.getItems()).then (items) =>
        @injectLineHeader(items) if @provider.showLineHeader
        @cachedItems = items if @provider.supportCacheItems
        items

    filterSpec = getFilterSpecForQuery(@getQuery())
    if @provider.updateGrammarOnQueryChange
      @grammar.update(filterSpec.include) # No need to highlight excluded items

    promiseForItems.then (items) =>
      items = @provider.filterItems(items, filterSpec)
      if not @provider.boundToEditor and @excludedFiles.length
        items = items.filter ({filePath}) => filePath not in @excludedFiles

      @items = [@promptItem, items...]
      @renderItems(items)

      if @isActive()
        @selectItemForRow(@findRowForNormalItem(0, 'next'))
      @setModifiedState(false)
      unless @hasNormalItem()
        @selectedItem = null
        @previouslySelectedItem = null
        @highlighter.clearLineMarker()

      @emitDidRefresh()
      @emitDidStopRefreshing()

  renderItems: (items) ->
    texts = items.map (item) => @provider.viewForItem(item)
    @withIgnoreChange =>
      if @editor.getLastBufferRow() is 0
        # Need to recover query prompt
        @insertQuery()
        @moveToPrompt()
        @providerPanel.show() # redraw providerPanel block decoration.
      itemArea = new Range(@itemAreaStart, @editor.getEofBufferPosition())
      range = @editor.setTextInBufferRange(itemArea, texts.join("\n"), undo: 'skip')
      @editorLastRow = range.end.row

  debouncedPreview: ->
    clearTimeout(@debouncedPreviewTimeout) if @debouncedPreviewTimeout?
    preview = =>
      @debouncedPreviewTimeout = null
      @preview()
    @debouncedPreviewTimeout = setTimeout(preview, @debouncedPreviewDelay)

  observeChange: ->
    @editor.buffer.onDidChange ({newRange, oldRange}) =>
      return if @ignoreChange

      promptRange = @getPromptRange()
      onPrompt = (range) -> range.intersectsWith(promptRange)
      isQueryModified = (newRange, oldRange) ->
        (not newRange.isEmpty() and onPrompt(newRange)) or (not oldRange.isEmpty() and onPrompt(oldRange))

      if isQueryModified(newRange, oldRange)
        # is Query changed
        if @editor.hasMultipleCursors()
          # Destroy cursors on prompt to protect query from mutation on 'find-and-replace:select-all'( cmd-alt-g ).
          for selection in @editor.getSelections() when onPrompt(selection.getBufferRange())
            selection.destroy()
          @withIgnoreChange => @insertQuery(@lastQuery) # Recover query
        else
          @refresh().then =>
            if @autoPreviewOnQueryChange and @isActive()
              if @provider.boundToEditor
                @preview()
              else
                @debouncedPreview()
      else
        @setModifiedState(true)

  observeCursorMove: ->
    @editor.onDidChangeCursorPosition (event) =>
      return if @ignoreCursorMove

      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event
      return if textChanged or
        (not cursor.selection.isEmpty()) or
        (oldBufferPosition.row is newBufferPosition.row)

      newRow = newBufferPosition.row
      oldRow = oldBufferPosition.row

      if isHeaderRow = not @isPromptRow(newRow) and not @isNormalItemRow(newRow)
        direction = if newRow > oldRow then 'next' else 'previous'
        newRow = @findRowForNormalOrPromptItem(newRow, direction)

      if @isPromptRow(newRow)
        @withIgnoreCursorMove =>
          @editor.setCursorBufferPosition([newRow, newBufferPosition.column])
          @emitDidMoveToPrompt()
      else
        @selectItemForRow(newRow)
        @moveToSelectedItem() if isHeaderRow
        @emitDidMoveToItemArea() if @isPromptRow(oldRow)
        @preview() if @autoPreview

  findClosestItemForEditor: (editor) ->
    # * Closest item is
    #  - Same filePath of current active-editor
    #  - It's point is less than or equal to active-editor's cursor position.
    if @provider.boundToEditor
      items = @getNormalItems()
    else
      items = @getNormalItemsForFilePath(editor.getPath())

    return null unless items.length

    cursorPosition = editor.getCursorBufferPosition()
    for item in items by -1 when item.point.isLessThanOrEqual(cursorPosition)
      return item

    return items[0]

  syncToEditor: (editor) ->
    return if @preventSyncToEditor
    if item = @findClosestItemForEditor(editor)
      @selectItem(item)
      unless @isActive()
        {row} = @editor.getCursorBufferPosition()
        @moveToSelectedItem(scrollToColumnZero: true)
        @emitDidMoveToItemArea() if @isPromptRow(row)

  moveToSelectedItem: ({scrollToColumnZero, ignoreCursorMove}={}) ->
    if (row = @getRowForSelectedItem()) >= 0
      {column} = @editor.getCursorBufferPosition()
      point = scrollPoint = [row, column]
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

  preview: ->
    @preventSyncToEditor = true
    item = @getSelectedItem()
    unless item
      @preventSyncToEditor = false
      @highlighter.clearLineMarker()
      return

    @provider.openFileForItem(item).then (editor) =>
      editor.scrollToBufferPosition(item.point, center: true)
      @preventSyncToEditor = false
      @emitDidPreview({editor, item})

  confirm: ({keepOpen, flash}={}) ->
    return unless @hasNormalItem()
    item = @getSelectedItem()
    needDestroy = not keepOpen and not @protected and @provider.getConfig('closeOnConfirm')

    @provider.confirmed(item).then (editor) =>
      if needDestroy
        @editor.destroy()
      else
        @highlighter.flashItem(editor, item) if flash
        @emitDidConfirm({editor, item})

  # Return row
  # Never fail since prompt is row 0 and always exists
  findRowForNormalOrPromptItem: (row, direction) ->
    delta = switch direction
      when 'next' then +1
      when 'previous' then -1

    loop
      row = getValidIndexForList(@items, row + delta)
      if @isNormalItemRow(row) or @isPromptRow(row)
        return row

  # Return row
  findRowForNormalItem: (row, direction) ->
    return null unless @hasNormalItem()
    delta = switch direction
      when 'next' then +1
      when 'previous' then -1

    loop
      if @isNormalItemRow(row = getValidIndexForList(@items, row + delta))
        return row

  findDifferentFileItem: (direction) ->
    return if @provider.boundToEditor
    return null unless selectedItem = @getSelectedItem()

    delta = switch direction
      when 'next' then +1
      when 'previous' then -1

    nextRow = (row) => getValidIndexForList(@items, row + delta)
    startRow = row = @getRowForSelectedItem()
    while (row = nextRow(row)) isnt startRow
      if @isNormalItemRow(row) and @items[row].filePath isnt selectedItem.filePath
        return @items[row]

  isCursorOutOfSyncWithSelectedItem: ->
    @editor.getCursorBufferPosition().row isnt @getRowForSelectedItem()

  moveToNextFileItem: ->
    @moveToDifferentFileItem('next')

  moveToPreviousFileItem: ->
    @moveToDifferentFileItem('previous')

  moveToDifferentFileItem: (direction) ->
    if @isCursorOutOfSyncWithSelectedItem()
      @moveToSelectedItem(ignoreCursorMove: false)
      return

    # Fallback to selected item in case there is only single filePath in all items
    # But want to move to item from query-prompt.
    if item = @findDifferentFileItem(direction) ? @getSelectedItem()
      @selectItem(item)
      @moveToSelectedItem(ignoreCursorMove: false)

  moveToPromptOrSelectedItem: ->
    row = @getRowForSelectedItem()
    if (row is @editor.getCursorBufferPosition().row) or not (row >= 0)
      @moveToPrompt()
    else
      # move to current item
      @editor.setCursorBufferPosition([row, 0])

  getRowForSelectedItem: ->
    @getRowForItem(@getSelectedItem())

  moveToPrompt: ->
    @withIgnoreCursorMove =>
      @editor.setCursorBufferPosition(@getPromptRange().end)
      @setReadOnly(false)
      @emitDidMoveToPrompt()

  isPromptRow: (row) ->
    row is 0

  isNormalItem: (item) ->
    item? and not item.skip

  isNormalItemRow: (row) ->
    @isNormalItem(@items[row])

  getRowForItem: (item) ->
    @items.indexOf(item)

  selectItem: (item) ->
    @selectItemForRow(row) if (row = @getRowForItem(item)) >= 0

  hasNormalItem: ->
    @items.some (item) -> (not item.skip)

  hasSomeNormalItemForFilePath: (filePath) ->
    @items.some (item) ->
      (not item.skip) and (item.filePath is filePath)

  getNormalItems: ->
    @items.filter (item) -> (not item.skip)

  getNormalItemsForFilePath: (filePath) ->
    @items.filter (item) ->
      (not item.skip) and (item.filePath is filePath)

  updateProviderPanel: (states) ->
    @providerPanel.updateStateElements(states)

  selectItemForRow: (row) ->
    item = @items[row]
    if @isNormalItem(item)
      @itemIndicator.setToRow(row)
      @previouslySelectedItem = @selectedItem
      @selectedItem = item
      event = {
        oldItem: @previouslySelectedItem
        newItem: @selectedItem
      }
      @emitDidChangeSelectedItem(event)

  getSelectedItem: ->
    @selectedItem

  getPreviouslySelectedItem: ->
    @previouslySelectedItem

  getPromptRange: ->
    @editor.bufferRangeForBufferRow(0)

  # Return range
  insertQuery: (text='') ->
    @editor.setTextInBufferRange([[0, 0], @itemAreaStart], text + "\n")

  startSyncToEditor: (editor) ->
    syncToEditor = @syncToEditor.bind(this, editor)
    syncToEditor()

    @syncSubcriptions = new CompositeDisposable
    ignoreColumnChange = @provider.ignoreSideMovementOnSyncToEditor

    @syncSubcriptions.add editor.onDidChangeCursorPosition (event) ->
      return unless isActiveEditor(editor)
      return if event.textChanged
      return if ignoreColumnChange and (event.oldBufferPosition.row is event.newBufferPosition.row)
      syncToEditor()

    @syncSubcriptions.add @onDidRefresh(syncToEditor)

    refresh = => @refresh(force: true) unless @isActive()

    if @provider.boundToEditor
      # Surppress refreshing while editor is active to avoid auto-refreshing while direct-edit.
      @syncSubcriptions.add editor.onDidStopChanging(refresh)
    else
      @syncSubcriptions.add editor.onDidSave(refresh)

  # Return intems which are injected maxLineTextWidth(used to align lineHeader)
  injectLineHeader: (items) ->
    normalItems = _.reject(items, (item) -> item.skip)
    points = _.pluck(normalItems, 'point')
    maxLine = Math.max(_.pluck(points, 'row')...) + 1
    maxColumn = Math.max(_.pluck(points, 'column')...) + 1
    maxLineWidth = String(maxLine).length
    maxColumnWidth = Math.max(String(maxColumn).length, 2)
    for item in normalItems
      item._lineHeader = @getLineHeaderForItem(item.point, maxLineWidth, maxColumnWidth)
    items

  getLineHeaderForItem: (point, maxLineWidth, maxColumnWidth) ->
    lineText = String(point.row + 1)
    padding = " ".repeat(maxLineWidth - lineText.length)
    lineHeader = "#{@provider.indentTextForLineHeader}#{padding}#{lineText}"
    if @provider.showColumnOnLineHeader
      columnText = String(point.column + 1)
      padding = " ".repeat(maxColumnWidth - columnText.length)
      lineHeader = "#{lineHeader}:#{padding}#{columnText}"
    lineHeader + ": "

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
    return unless @provider.supportDirectEdit
    return unless @isModified()

    if settings.get('confirmOnUpdateRealFile')
      unless atom.confirm(message: 'Update real file?', buttons: ['Update', 'Cancel']) is 0
        return

    return unless @ensureNarrowEditorIsValidState()

    changes = []
    lines = @editor.buffer.getLines()
    for line, row in lines when @isNormalItem(item = @items[row])
      if item._lineHeader?
        line = line[item._lineHeader.length...] # Strip lineHeader
      if line isnt item.text
        changes.push({newText: line, item})

    return unless changes.length

    unless @provider.boundToEditor
      {success, message} = @ensureNoModifiedFileForChanges(changes)
      unless success
        atom.notifications.addWarning(message, dismissable: true)
        return

    {success, message} = @ensureNoConflictForChanges(changes)
    unless success
      atom.notifications.addWarning(message, dismissable: true)
      return

    @provider.updateRealFile(changes)
    @setModifiedState(false)

  ensureNarrowEditorIsValidState: ->
    unless @editorLastRow is @editor.getLastBufferRow()
      return false

    # Ensure all item have valid line header
    if @provider.showLineHeader
      for line, row in @editor.buffer.getLines() when @isNormalItem(item = @items[row])
        return false unless line.startsWith(item._lineHeader)

    true

  getModifiedFilePathsInChanges: (changes) ->
    _.uniq(changes.map ({item}) -> item.filePath).filter (filePath) ->
      atom.project.isPathModified(filePath)

  ensureNoModifiedFileForChanges: (changes) ->
    message = ''
    modifiedFilePaths = @getModifiedFilePathsInChanges(changes)
    success = modifiedFilePaths.length is 0
    unless success
      modifiedFilePathsAsString = modifiedFilePaths.map((filePath) -> " - `#{filePath}`").join("\n")
      message = """
        Cancelled `update-real-file`.
        You are trying to update file which have **unsaved modification**.
        But `narrow:#{@provider.getDashName()}` can not detect unsaved change.
        To use `update-real-file`, you need to save these files.

        #{modifiedFilePathsAsString}
        """

    return {success, message}

  ensureNoConflictForChanges: (changes) ->
    message = []
    conflictChanges = @detectConflictForChanges(changes)
    success = _.isEmpty(conflictChanges)
    unless success
      message.push """
        Cancelled `update-real-file`.
        Detected **conflicting change to same line**.
        """
      for filePath, changesInFile of conflictChanges
        message.push("- #{filePath}")
        for {newText, item} in changesInFile
          message.push("  - #{item.point.translate([1, 1]).toString()}, #{newText}")

    return {success, message: message.join("\n")}

  detectConflictForChanges: (changes) ->
    conflictChanges = {}
    changesByFilePath =  _.groupBy(changes, ({item}) -> item.filePath)
    for filePath, changesInFile of changesByFilePath
      changesByRow = _.groupBy(changesInFile, ({item}) -> item.point.row)
      for row, changesInRow of changesByRow
        newTexts = _.pluck(changesInRow, 'newText')
        if _.uniq(newTexts).length > 1
          conflictChanges[filePath] ?= []
          conflictChanges[filePath].push(changesInRow...)
    conflictChanges
