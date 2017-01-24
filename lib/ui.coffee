_ = require 'underscore-plus'
{Point, Range, CompositeDisposable} = require 'atom'
{
  getAdjacentPaneForPane
  openItemInAdjacentPaneForPane
} = require './utils'
settings = require './settings'
path = require 'path'
NarrowGrammar = require './grammar'

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
  ignoreChangeOnNarrowEditor: false
  destroyed: false
  items: []
  itemsByProvider: null

  @unregisterUI: (narrowEditor) ->
    @uiByNarrowEditor.delete(narrowEditor)
    @updateWorkspaceClassList()

  @registerUI: (narrowEditor, ui) ->
    @uiByNarrowEditor.set(narrowEditor, ui)
    @updateWorkspaceClassList()

  @updateWorkspaceClassList: ->
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.classList.toggle('has-narrow', @uiByNarrowEditor.size)

  constructor: (@provider, {@input}={}) ->
    @disposables = new CompositeDisposable

    # Special item used to translate narrow editor row to items without pain
    @promptItem = Object.freeze({_prompt: true, skip: true})
    @itemAreaStart = Object.freeze(new Point(1, 0))

    @originalPane = atom.workspace.getActivePane()
    @gutterItem = document.createElement('span')
    @gutterItem.textContent = " > "

    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @providerEditor = @provider.editor
    dashName = @provider.getDashName()
    @editor.getTitle = -> dashName
    @editor.isModified = -> false
    @editor.onDidDestroy(@destroy.bind(this))
    @editorElement = @editor.element
    @editorElement.classList.add('narrow', 'narrow-editor', dashName)

    @gutterForPrompt = new PromptGutter(@editor)

    includeHeaderRules = @provider.includeHeaderGrammarRules
    @grammar = new NarrowGrammar(@editor, {includeHeaderRules})
    @registerCommands()
    @disposables.add(@observeInputChange())
    @observeCursorPositionChangeForNarrowEditor()

    @disposables.add atom.workspace.onDidStopChangingActivePaneItem (item) =>
      @rowMarker?.destroy() if item isnt @editor

    if @provider.boundToEditor
      @disposables.add @providerEditor.onDidChangeCursorPosition(@syncToProviderEditor.bind(this))
      @disposables.add @providerEditor.onDidDestroy(@destroy.bind(this))

    @constructor.registerUI(@editor, this)

  start: ->
    @grammar.activate()
    activePane = atom.workspace.getActivePane()
    direction = settings.get('directionToOpen')
    if direction is 'here'
      @pane = activePane.activateItem(@editor)
      @autoPreview = false
    else
      @pane = openItemInAdjacentPaneForPane(activePane, @editor, direction)
      defaultAutoPreviewConfigName = @provider.getName() + "DefaultAutoPreview"
      @autoPreview = settings.get(defaultAutoPreviewConfigName) ? false

    @setPromptLine("\n")
    @moveToPrompt()
    if @input
      @editor.insertText(@input)
    else
      @refresh()

  focus: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@editor)

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
      'narrow-ui:refresh-force': => @refresh(force: true)
      'narrow-ui:move-to-query-or-current-item': => @moveToQueryOrCurrentItem()
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

    @withPreventAutoPreview =>
      switch direction
        when 'up' then @editor.moveUp()
        when 'down' then @editor.moveDown()

    @confirm(keepOpen: true)

  nextItem: (options) ->
    @moveUpDown('down', options)

  previousItem: (options) ->
    @moveUpDown('up', options)

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

  refresh: ({force}={}) ->
    if force
      @itemsByProvider = null

    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    regexps = words.map (word) => @getRegExpForQueryWord(word)
    @ignoreChangeOnNarrowEditor = true

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
      @selectItemForRow(@findNormalItem(1, 'next'))

      @ignoreChangeOnNarrowEditor = false

  renderItems: (items) ->
    texts = items.map (item) => @provider.viewForItem(item)
    itemArea = new Range(@itemAreaStart, @editor.getEofBufferPosition())
    range = @editor.setTextInBufferRange(itemArea, texts.join("\n"))
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
    @editor.buffer.onDidChange ({newRange, oldRange, newText, oldText}) =>
      return if @ignoreChangeOnNarrowEditor

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

  observeCursorPositionChangeForNarrowEditor: ->
    @editor.onDidChangeCursorPosition (event) =>
      return if @isLocked()
      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event
      return if (not cursor.selection.isEmpty()) or
        textChanged or
        (newBufferPosition.row is 0) or
        (oldBufferPosition.row is newBufferPosition.row)

      direction = if (newBufferPosition.row - oldBufferPosition.row) > 0 then 'next' else 'previous'
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
    # Skip if not active editor.
    return unless atom.workspace.getActiveTextEditor() is @providerEditor

    cursorPosition = @providerEditor.getCursorBufferPosition()
    # Detect item
    # - cursor position is equal or greather than that item.
    foundItem = null
    for item in @items by -1 when item.point?
      itemPoint = Point.fromObject(item.point)
      if itemPoint.isLessThanOrEqual(cursorPosition)
        foundItem = item
        break
    return unless foundItem?

    @selectItem(foundItem)
    row = @editor.getCursorBufferPosition().row
    selectedItemRow = @getRowForSelectedItem()
    if (row isnt selectedItemRow)
      @withLock => @editor.setCursorBufferPosition([selectedItemRow, 0])

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

  moveToQueryOrCurrentItem: ->
    row = @getRowForSelectedItem()
    if row is @editor.getCursorBufferPosition().row
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
    if (row = @items.indexOf(item) ) >= 0
      @selectItemForRow(row)

  selectItemForRow: (row) ->
    item = @items[row]
    if @isNormalItem(item)
      @gutterForPrompt.setToRow(row)
      @selectedItem = item

  getSelectedItem: ->
    @selectedItem ? {}

  getPromptRange: ->
    @editor.bufferRangeForBufferRow(0)

  # Return range
  setPromptLine: (text) ->
    @ignoreChangeOnNarrowEditor = true
    range = @editor.setTextInBufferRange(@getPromptRange(0), text)
    @ignoreChangeOnNarrowEditor = false
    range
