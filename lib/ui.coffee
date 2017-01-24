_ = require 'underscore-plus'
{Point, Range, CompositeDisposable, Emitter} = require 'atom'
{openItemInAdjacentPaneForPane, isActiveEditor} = require './utils'
settings = require './settings'
Grammar = require './grammar'

class PromptGutter
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
  @uiByNarrowEditor: new Map()
  autoPreview: false
  preventAutoPreview: false
  ignoreChangeOnEditor: false
  destroyed: false
  items: []
  itemsByProvider: null

  @unregisterUI: (editor) ->
    @uiByNarrowEditor.delete(editor)
    @updateWorkspaceClassList()

  @registerUI: (editor, ui) ->
    @uiByNarrowEditor.set(editor, ui)
    @updateWorkspaceClassList()

  @updateWorkspaceClassList: ->
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.classList.toggle('has-narrow', @uiByNarrowEditor.size)

  onDidFocused: (fn) -> @emitter.on('did-focused', fn)
  emitDidFocused: -> @emitter.emit('did-focused')

  constructor: (@provider, {@input}={}) ->
    @disposables = new CompositeDisposable
    @emitter = new Emitter
    @autoPreview = settings.get(@provider.getName() + "AutoPreview")

    # Special item used to translate narrow editor row to items without pain
    @promptItem = Object.freeze({_prompt: true, skip: true})
    @itemAreaStart = Object.freeze(new Point(1, 0))

    @onDidFocused =>
      @editor.scrollToCursorPosition(center: true)

    @originalPane = atom.workspace.getActivePane()

    @providerEditor = @provider.editor
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @editor.getTitle = => @provider.getDashName()
    @editor.isModified = -> false
    @editor.onDidDestroy(@destroy.bind(this))
    @editorElement = @editor.element
    @editorElement.classList.add('narrow', 'narrow-editor', @provider.getDashName())

    @gutterForPrompt = new PromptGutter(@editor)

    @grammar = new Grammar(@editor, includeHeaderRules: @provider.includeHeaderGrammar)
    @disposables.add(@registerCommands())
    @disposables.add(@observeInputChange())
    @disposables.add(@observeCursorPositionChange())

    @disposables.add atom.workspace.onDidStopChangingActivePaneItem (item) =>
      if item is @editor
        @emitDidFocused()
      else
        @rowMarker?.destroy()
        if @provider.boundToEditor and (item is @providerEditor)
          @syncToProviderEditor()

    if @provider.boundToEditor
      @disposables.add @providerEditor.onDidStopChanging =>
        # Skip is not activeEditor, important to skip auto-refresh on direct-edit.
        @refresh(force: true) if isActiveEditor(@providerEditor)

      @disposables.add @providerEditor.onDidChangeCursorPosition =>
        @syncToProviderEditor() if isActiveEditor(@providerEditor)

      @disposables.add @providerEditor.onDidDestroy(@destroy.bind(this))

    @constructor.registerUI(@editor, this)

  start: ->
    activePane = atom.workspace.getActivePane()
    options = {item: @editor, direction: settings.get('directionToOpen')}
    @pane = openItemInAdjacentPaneForPane(activePane, options)
    @grammar.activate()
    @setPromptLine((@input ? '') + "\n" )
    @moveToPrompt()
    @refresh()

  focus: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@editor)
      @emitDidFocused()

  isAlive: ->
    @editor?.isAlive?()

  destroy: ->
    return if @destroyed
    @destroyed = true

    @disposables.dispose()
    @editor.destroy()
    @originalPane.activate() if @originalPane.isAlive()
    @provider?.destroy?()
    @gutterForPrompt?.destroy()
    @constructor.unregisterUI(@editor)
    @rowMarker?.destroy()

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'narrow-ui:confirm-keep-open': => @confirm(keepOpen: true)
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()
      'narrow-ui:refresh-force': => @refresh(force: true, moveToPrompt: true)
      'narrow-ui:move-to-prompt-or-selected-item': => @moveToPromptOrSelectedItem()
      'narrow-ui:update-real-file': => @updateRealFile()

  updateRealFile: ->
    return unless @provider.supportDirectEdit
    return unless @ensureNarrowEditorIsValidState()

    changes = []
    lines = @editor.buffer.getLines()
    for line, row in lines when @isNormalItem(item = @items[row])
      if item._lineHeader?
        line = line[item._lineHeader.length...] # Strip lineHeader

      unless line is item.text
        changes.push({newText: line, item})

    if changes.length
      @provider.updateRealFile(changes)

  moveUpDown: (direction) ->
    if (row = @getRowForSelectedItem()) >= 0
      @withLock => @editor.setCursorBufferPosition([row, 0])

    if @direction is 'down' and @provider.boundToEditor
      # Prevent side scroll of narrow editor
      point = @providerEditor.getCursorBufferPosition()
      if point.isGreaterThanOrEqual(_.last(@items).point)
        return

    @withPreventAutoPreview =>
      switch direction
        when 'up'
          @editor.moveUp()
        when 'down'
          @editor.moveDown()

    @confirm(keepOpen: true)

  nextItem: ->
    @moveUpDown('down')

  previousItem: ->
    @moveUpDown('up')

  isAutoPreview: ->
    if @preventAutoPreview
      false
    else
      @autoPreview

  toggleAutoPreview: ->
    @autoPreview = not @autoPreview
    @preview() if @isAutoPreview()

  getNarrowQuery: ->
    @lastNarrowQuery = @editor.lineTextForBufferRow(0)

  getRegExpForQueryWord: (word) ->
    pattern = _.escapeRegExp(word)
    sensitivity = settings.get('caseSensitivityForNarrowQuery')
    if (sensitivity is 'sensitive') or (sensitivity is 'smartcase' and /[A-Z]/.test(word))
      new RegExp(pattern)
    else
      new RegExp(pattern, 'i')

  refresh: ({force, moveToPrompt}={}) ->
    if force
      @itemsByProvider = null
    if moveToPrompt
      @moveToPrompt()

    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    regexps = words.map (word) => @getRegExpForQueryWord(word)

    @ignoreChangeOnEditor = true
    # In case prompt accidentaly mutated
    eof = @editor.getEofBufferPosition()
    if eof.isLessThan(@itemAreaStart)
      eof = @setPromptLine("\n").end
      @moveToPrompt()

    Promise.resolve(@itemsByProvider ? @provider.getItems()).then (items) =>
      if @provider.supportCacheItems
        @itemsByProvider = items
      items = @provider.filterItems(items, regexps)
      @items = [@promptItem, items...]
      @renderItems(items)
      @grammar.update(regexps)

      if @provider.boundToEditor and @selectedItem and not isActiveEditor(@editor)
        # console.log "case1"
        @syncToProviderEditor()
      else
        # console.log "case2" #, @selectedItem
        @selectItemForRow(@findNormalItem(1, 'next'))
      @ignoreChangeOnEditor = false

  renderItems: (items) ->
    texts = items.map (item) => @provider.viewForItem(item)
    itemArea = new Range(@itemAreaStart, @editor.getEofBufferPosition())
    range = @editor.setTextInBufferRange(itemArea, texts.join("\n"), undo: 'skip')
    @editorLastRow = range.end.row

  ensureNarrowEditorIsValidState: ->
    # Ensure all item have valid line header
    unless @editorLastRow is @editor.getLastBufferRow()
      return false

    if @provider.showLineHeader
      for line, row in @editor.buffer.getLines() when @isNormalItem(item = @items[row])
        return false unless line.startsWith(item._lineHeader)

    true

  observeInputChange: ->
    @editor.buffer.onDidChange ({newRange, oldRange}) =>
      return if @ignoreChangeOnEditor

      promptRange = @getPromptRange()
      onPrompt = (range) -> range.intersectsWith(promptRange)
      notEmptyAndPrompt = (range) -> not range.isEmpty() and onPrompt(range)

      if notEmptyAndPrompt(newRange) or notEmptyAndPrompt(oldRange)
        if @editor.hasMultipleCursors()
          # Destroy cursors on prompt
          for selection in @editor.getSelections() when onPrompt(selection.getBufferRange())
            selection.destroy()
          # Recover query on prompt
          @setPromptLine(@lastNarrowQuery) if @lastNarrowQuery
        else
          @refresh()

  locked: false
  isLocked: -> @locked
  withLock: (fn) ->
    @locked = true
    fn()
    @locked = false

  withPreventAutoPreview: (fn) ->
    @preventAutoPreview = true
    fn()
    @preventAutoPreview = false

  observeCursorPositionChange: ->
    @editor.onDidChangeCursorPosition (event) =>
      return if @isLocked()
      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event
      return if (not cursor.selection.isEmpty()) or
        textChanged or
        (newBufferPosition.row is 0) or
        (oldBufferPosition.row is newBufferPosition.row)

      if newBufferPosition.row > oldBufferPosition.row
        direction = 'next'
      else
        direction = 'previous'
      {row, column} = newBufferPosition
      @withLock =>
        row = @findNormalItem(row, direction)
        if row? # row might be '0'
          @selectItemForRow(row)
          cursor.setBufferPosition([row, column])
        else if direction is 'previous'
          cursor.setBufferPosition([0, column])

      @preview() if @isAutoPreview()

  syncToProviderEditor: ->
    # Detect item
    # - cursor position is equal or greather than that item.
    cursorPosition = @providerEditor.getCursorBufferPosition()
    foundItem = null
    for item in @items by -1 when item.point?.isLessThanOrEqual(cursorPosition)
      foundItem = item
      break

    if foundItem?
      @selectItem(item)
    else
      @selectItemForRow(@findNormalItem(1, 'next'))

    unless isActiveEditor(@editor)
      row = @editor.getCursorBufferPosition().row
      selectedItemRow = @getRowForSelectedItem()
      if (row isnt selectedItemRow)
        @editor.scrollToBufferPosition([selectedItemRow, 0])

  setRowMarker: (editor, point) ->
    @rowMarker?.destroy()
    @rowMarker = editor.markBufferRange([point, point])
    editor.decorateMarker(@rowMarker, type: 'line', class: 'narrow-result')

  preview: ->
    @confirm(keepOpen: true).then ({editor, point}) =>
      if editor.isAlive()
        @setRowMarker(editor, point)
        @focus()

  isNormalItem: (item) ->
    item? and not item.skip

  confirm: (options={}) ->
    item = @getSelectedItem()
    Promise.resolve(@provider.confirmed(item)).then ({editor, point}) =>
      unless options.keepOpen
        @editor.destroy()
      {editor, point}

  # Return row
  findNormalItem: (startRow, direction) ->
    maxRow = @items.length - 1
    rows = if direction is 'next'
      [startRow..maxRow]
    else
      [startRow..0]

    for row in rows when @isNormalItem(@items[row])
      return row
    null

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
    @editor.setCursorBufferPosition(@getPromptRange().end)

  getRowForItem: (item) ->
    @items.indexOf(item)

  selectItem: (item) ->
    if (row = @getRowForItem(item)) >= 0
      @selectItemForRow(row)

  selectItemForRow: (row) ->
    item = @items[row]
    if @isNormalItem(item)
      @gutterForPrompt.setToRow(row)
      @selectedItem = item

  getSelectedItem: ->
    @selectedItem

  getPromptRange: ->
    @editor.bufferRangeForBufferRow(0)

  # Return range
  setPromptLine: (text) ->
    @ignoreChangeOnEditor = true
    range = @editor.setTextInBufferRange(@getPromptRange(0), text)
    @ignoreChangeOnEditor = false
    range
