_ = require 'underscore-plus'
{Point, Range, CompositeDisposable, Emitter, Disposable} = require 'atom'
{
  activatePaneItemInAdjacentPane
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

class CurrentItemIndicator
  constructor: (@editor) ->
    @gutter = @editor.addGutter(name: 'narrow-prompt', priority: 100)

    @item = document.createElement('span')
    @item.textContent = " > "

  setToRow: (row) ->
    @marker?.destroy()
    @marker = @editor.markBufferPosition([row, 0])
    @gutter.decorateMarker @marker,
      class: "narrow-ui-selected-row"
      item: @item

  destroy: ->
    @marker?.destroy()

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

  # UI.prototype
  # -------------------------
  autoPreview: null
  autoPreviewOnQueryChange: null
  autoPreviewOnNextStopChanging: false

  preventAutoPreview: false
  preventSyncToEditor: false
  ignoreChange: false
  ignoreCursorMove: false
  destroyed: false
  items: []
  itemsByProvider: null # Used to cache result
  lastNarrowQuery: ''
  modifiedState: null
  readOnly: false

  isModified: ->
    @modifiedState

  setModifiedState: (state) ->
    if state isnt @modifiedState
      # HACK: overwrite TextBuffer:isModified to return static state.
      # This state is used for tabs package to show modified icon on tab.
      @modifiedState = state
      @editor.buffer.isModified = -> state
      @editor.buffer.emitModifiedStatusChanged(state)

  onDidMoveToPrompt: (fn) -> @emitter.on('did-move-to-prompt', fn)
  emitDidMoveToPrompt: -> @emitter.emit('did-move-to-prompt')

  onDidMoveToItemArea: (fn) -> @emitter.on('did-move-to-item-area', fn)
  emitDidMoveToItemArea: -> @emitter.emit('did-move-to-item-area')

  onDidRefresh: (fn) -> @emitter.on('did-refresh', fn)
  emitDidRefresh: -> @emitter.emit('did-refresh')

  constructor: (@provider, {@input}={}) ->
    @disposables = new CompositeDisposable
    @emitter = new Emitter
    @autoPreview = @provider.getConfig('autoPreview')
    @autoPreviewOnQueryChange = @provider.getConfig('autoPreviewOnQueryChange')

    # Special item used to translate narrow editor row to items without pain
    @promptItem = Object.freeze({_prompt: true, skip: true})
    @itemAreaStart = Object.freeze(new Point(1, 0))

    # Setup narrow-editor
    # -------------------------
    # Hide line number gutter for empty indent provider
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: @provider.indentTextForLineHeader)

    # FIXME
    # Opening multiple narrow-editor for same provider get title `undefined`
    # (e.g multiple narrow-editor for lines provider)
    providerDashName = @provider.getDashName()
    @editor.getTitle = -> providerDashName
    @editor.onDidDestroy(@destroy.bind(this))
    @editorElement = @editor.element
    @editorElement.classList.add('narrow', 'narrow-editor', providerDashName)

    @currentItemIndicator = new CurrentItemIndicator(@editor)
    @grammar = new Grammar(@editor, includeHeaderRules: @provider.includeHeaderGrammar)

    @disposables.add @onDidMoveToItemArea  => @setReadOnly(true)

    @disposables.add(
      @registerCommands()
      @observeChange()
      @observeStopChanging()
      @observeCursorMove()
      @observeStopChangingActivePaneItem()
    )

    @constructor.register(this)
    @disposables.add new Disposable =>
      @constructor.unregister(this)

  onMoveToItemArea: ->
    @editorElement.component?.setInputEnabled(false)
    @editorElement.classList.add('read-only')
    @vmpActivateNormalMode() if @vmpIsInsertMode()

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

  observeStopChangingActivePaneItem: ->
    atom.workspace.onDidStopChangingActivePaneItem (item) =>
      @syncSubcriptions?.dispose()
      return if item is @editor
      @rowMarker?.destroy()

      # Only sync to text-editor which meet following conditions
      # - Not narrow-editor
      # - Contained in different pane from narrow-editor is contained.
      if (not isTextEditor(item)) or isNarrowEditor(item) or (paneForItem(item) is @getPane())
        return

      if @provider.boundToEditor
        @provider.bindEditor(item)
        @refresh(force: true).then =>
          @syncToEditor(item)
          @setSyncToEditor(item)
      else
        filePath = item.getPath()
        if @items.some((item) -> item.filePath is filePath)
          @syncToEditor(item)
          @setSyncToEditor(item)

  start: ->
    activatePaneItemInAdjacentPane(@editor, split: settings.get('directionToOpen'))
    @grammar.activate()
    @setPrompt(@input)
    @moveToPrompt(startInsert: true)
    @refresh()

  getPane: ->
    paneForItem(@editor)

  isActive: ->
    isActiveEditor(@editor)

  isPromptRow: (row) ->
    row is 0

  focus: ->
    pane = @getPane()
    pane.activate()
    pane.activateItem(@editor)

  focusPrompt: ->
    if @isActive() and @isPromptRow(@editor.getCursorBufferPosition().row)
      @activateProviderPane()
    else
      @focus() unless @isActive()
      @moveToPrompt(startInsert: true)

  toggleFocus: ->
    if @isActive()
      @activateProviderPane()
    else
      @focus()

  activateProviderPane: ->
    if (pane = @provider.getPane()) and pane.isAlive()
      pane.activate()

  destroy: ->
    return if @destroyed
    @destroyed = true
    @syncSubcriptions?.dispose()
    @disposables.dispose()
    @editor.destroy()
    @activateProviderPane()

    @provider?.destroy?()
    @currentItemIndicator?.destroy()
    @rowMarker?.destroy()

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'narrow-ui:confirm-keep-open': => @confirm(keepOpen: true)
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:preview-next-item': => @previewNextItem()
      'narrow-ui:preview-previous-item': => @previewPreviousItem()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()
      'narrow-ui:refresh-force': => @refresh(force: true, moveToPrompt: true)
      'narrow-ui:move-to-prompt-or-selected-item': => @moveToPromptOrSelectedItem()
      'narrow-ui:move-to-prompt': => @moveToPrompt(startInsert: true)
      'core:move-up': (event) => @moveUpOrDown(event, 'previous')
      'core:move-down': (event) => @moveUpOrDown(event, 'next')
      'narrow-ui:update-real-file': => @updateRealFile()

  updateRealFile: ->
    return unless @isModified()
    if settings.get('confirmOnUpdateRealFile')
      unless atom.confirm(message: 'Update real file?', buttons: ['Update', 'Cancel']) is 0
        return

    return unless @provider.supportDirectEdit
    return unless @ensureNarrowEditorIsValidState()

    changes = []
    lines = @editor.buffer.getLines()
    for line, row in lines when @isNormalItem(item = @items[row])
      if item._lineHeader?
        line = line[item._lineHeader.length...] # Strip lineHeader
      if line isnt item.text
        changes.push({newText: line, item})

    if changes.length
      if not @provider.boundToEditor and (modifiedFilePaths = @getModifiedFilePathsInChanges(changes)).length
        modifiedFilePathsAsString = modifiedFilePaths.map((filePath) -> " - `#{filePath}`").join("\n")
        message = """
          Cancelled `update-real-file`.
          You are trying to update file which have **unsaved modification**.
          But `narrow:#{@provider.getDashName()}` can not detect unsaved change.
          To use `update-real-file`, you need to save these files.

          #{modifiedFilePathsAsString}
          """
        atom.notifications.addWarning(message, dismissable: true)
        return

      @provider.updateRealFile(changes)
      @setModifiedState(false)

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
      @confirm(keepOpen: true)

  nextItem: ->
    @confirmItemForDirection('next')

  previousItem: ->
    @confirmItemForDirection('previous')

  previewItemForDirection: (direction) ->
    row = @findRowForNormalItem(@getRowForSelectedItem(), direction)
    if row?
      @selectItemForRow(row)
      @preview()

  previewNextItem: ->
    @previewItemForDirection('next')

  previewPreviousItem: ->
    @previewItemForDirection('previous')

  toggleAutoPreview: ->
    @autoPreview = not @autoPreview
    @preview() if @autoPreview

  getNarrowQuery: ->
    @lastNarrowQuery = @editor.lineTextForBufferRow(0)

  refresh: ({force, moveToPrompt}={}) ->
    if force
      @itemsByProvider = null
    if moveToPrompt
      @moveToPrompt()

    # In case prompt accidentaly mutated
    eof = @editor.getEofBufferPosition()
    if eof.isLessThan(@itemAreaStart)
      eof = @setPrompt().end
      @moveToPrompt()

    filterSpec = getFilterSpecForQuery(@getNarrowQuery())

    Promise.resolve(@itemsByProvider ? @provider.getItems()).then (items) =>
      if @provider.supportCacheItems
        @itemsByProvider = items
      items = @provider.filterItems(items, filterSpec)
      @items = [@promptItem, items...]

      @renderItems(items)

      # No need to highlight excluded items
      @grammar.update(filterSpec.include)

      if @isActive()
        @selectItemForRow(@findRowForNormalItem(0, 'next'))
      @setModifiedState(false)
      @emitDidRefresh()

  renderItems: (items) ->
    texts = items.map (item) => @provider.viewForItem(item)
    itemArea = new Range(@itemAreaStart, @editor.getEofBufferPosition())
    @withIgnoreChange =>
      range = @editor.setTextInBufferRange(itemArea, texts.join("\n"), undo: 'skip')
      @editorLastRow = range.end.row

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

  observeStopChanging: ->
    @editor.onDidStopChanging =>
      if @autoPreviewOnNextStopChanging
        @preview()
        @autoPreviewOnNextStopChanging = false

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
          @setPrompt(@lastNarrowQuery) # Recover query
        else
          @refresh().then =>
            if @autoPreviewOnQueryChange and @isActive()
              if @provider.boundToEditor
                @preview()
              else
                # Delay immediate preview unless @provider is boundToEditor
                @autoPreviewOnNextStopChanging = true
      else
        @setModifiedState(true)

  withIgnoreCursorMove: (fn) ->
    @ignoreCursorMove = true
    fn()
    @ignoreCursorMove = false

  withIgnoreChange: (fn) ->
    @ignoreChange = true
    fn()
    @ignoreChange = false

  withPreventAutoPreview: (fn) ->
    @preventAutoPreview = true
    fn()
    @preventAutoPreview = false

  observeCursorMove: ->
    @editor.onDidChangeCursorPosition (event) =>
      return if @ignoreCursorMove

      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event
      return if textChanged or
        (not cursor.selection.isEmpty()) or
        (oldBufferPosition.row is newBufferPosition.row)

      newRow = newBufferPosition.row
      oldRow = oldBufferPosition.row

      if @isPromptRow(newRow)
        @emitDidMoveToPrompt()
        return

      if @isNormalItemRow(newRow)
        @selectItemForRow(newRow)
        @emitDidMoveToItemArea() if @isPromptRow(oldRow)
      else
        direction = if newRow > oldRow then 'next' else 'previous'
        row = @findRowForNormalOrPromptItem(newRow, direction)
        if @isPromptRow(row)
          @emitDidMoveToPrompt()
        else
          @selectItemForRow(row)
          @moveToSelectedItem()

      if @autoPreview and not @preventAutoPreview
        @preview()

  findClosestItemForEditor: (editor) ->
    # Detect item
    # - cursor position is equal or greather than that item.
    cursorPosition = editor.getCursorBufferPosition()
    if @provider.boundToEditor
      items = _.reject(@items, (item) -> item.skip)
    else
      # Item must support filePath
      filePath = editor.getPath()
      items = @items.filter((item) -> not item.skip and (item.filePath is filePath))

    for item in items by -1 when @isNormalItem(item)
      # It have only point(no filePath field in each item)
      if item.point.isLessThanOrEqual(cursorPosition)
        break
    return item # return items[0] as fallback

  syncToEditor: (editor) ->
    return if @preventSyncToEditor
    return if @isActive() # Prevent UI cursor from being moved while UI is active.
    if item = @findClosestItemForEditor(editor)
      @selectItem(item)
      @moveToSelectedItem() unless @isActive()

  moveToSelectedItem: ->
    if (row = @getRowForSelectedItem()) >= 0
      oldPosition = @editor.getCursorBufferPosition()
      @withIgnoreCursorMove =>
        # Manually set cursor to center to avoid scrollTop drastically changes
        # when refresh and auto-sync.
        point = [row, oldPosition.column]
        @editor.setCursorBufferPosition(point, autoscroll: false)
        @editor.scrollToBufferPosition(point, center: true)
        @emitDidMoveToItemArea() if @isPromptRow(oldPosition.row)

  setRowMarker: (editor, point) ->
    @rowMarker?.destroy()
    @rowMarker = editor.markBufferRange([point, point])
    editor.decorateMarker(@rowMarker, type: 'line', class: 'narrow-result')

  preview: ->
    @preventSyncToEditor = true
    @confirm(keepOpen: true, preview: true).then ({editor, point}) =>
      if editor.isAlive()
        @setRowMarker(editor, point)
        @focus()
      @preventSyncToEditor = false

  isNormalItem: (item) ->
    item? and not item.skip

  confirm: ({preview, keepOpen}={}) ->
    item = @getSelectedItem()
    Promise.resolve(@provider.confirmed(item, {preview})).then ({editor, point}) =>
      if not keepOpen and @provider.getConfig('closeOnConfirm')
        @editor.destroy()
      {editor, point}

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

  moveToPromptOrSelectedItem: ->
    row = @getRowForSelectedItem()
    if (row is @editor.getCursorBufferPosition().row) or not (row >= 0)
      @moveToPrompt(startInsert: true)
    else
      # move to current item
      @editor.setCursorBufferPosition([row, 0])

  getRowForSelectedItem: ->
    @getRowForItem(@getSelectedItem())

  moveToPrompt: ({startInsert}={}) ->
    @withIgnoreCursorMove =>
      @editor.setCursorBufferPosition(@getPromptRange().end)
      @setReadOnly(false) if startInsert
      @emitDidMoveToPrompt()

  isNormalItemRow: (row) ->
    @isNormalItem(@items[row])

  hasNormalItem: ->
    normalItems = @items.filter (item) => @isNormalItem(item)
    normalItems.length > 0

  getRowForItem: (item) ->
    @items.indexOf(item)

  selectItem: (item) ->
    if (row = @getRowForItem(item)) >= 0
      @selectItemForRow(row)

  selectItemForRow: (row) ->
    item = @items[row]
    if @isNormalItem(item)
      @currentItemIndicator.setToRow(row)
      @selectedItem = item

  getSelectedItem: ->
    @selectedItem

  getPromptRange: ->
    @editor.bufferRangeForBufferRow(0)

  # Return range
  setPrompt: (text='') ->
    if @editor.getLastBufferRow() is 0
      text += "\n"

    range = null
    @withIgnoreChange =>
      range = @editor.setTextInBufferRange(@getPromptRange(0), text)
    range

  setSyncToEditor: (editor) ->
    @syncSubcriptions = new CompositeDisposable
    @syncSubcriptions.add editor.onDidChangeCursorPosition (event) =>
      if isActiveEditor(editor) and
          (not event.textChanged) and
          (event.oldBufferPosition.row isnt event.newBufferPosition.row)
        @syncToEditor(editor)

    @syncSubcriptions.add @onDidRefresh =>
      @syncToEditor(editor)

    if @provider.boundToEditor
      @syncSubcriptions.add editor.onDidStopChanging =>
        # Surppress refreshing while editor is active to avoid auto-refreshing while direct-edit.
        @refresh(force: true) unless @isActive()
    else
      @syncSubcriptions.add editor.onDidSave =>
        @refresh(force: true) unless @isActive()

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
