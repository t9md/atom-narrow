_ = require 'underscore-plus'
{Point, CompositeDisposable} = require 'atom'
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

    @originalPane = atom.workspace.getActivePane()
    @gutterItem = document.createElement('span')
    @gutterItem.textContent = " > "

    @narrowEditor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    dashName = @provider.getDashName()
    @narrowEditor.getTitle = -> dashName
    @narrowEditor.isModified = -> false
    @narrowEditor.onDidDestroy(@destroy.bind(this))
    @narrowEditorElement = @narrowEditor.element
    @narrowEditorElement.classList.add('narrow', dashName)

    @gutterForPrompt = new PromptGutter(@narrowEditor)

    includeHeaderRules = @provider.includeHeaderGrammarRules
    @grammar = new NarrowGrammar(@narrowEditor, {includeHeaderRules})
    @registerCommands()
    @disposables.add(@observeInputChange())
    @observeCursorPositionChangeForNarrowEditor()

    @disposables.add atom.workspace.onDidStopChangingActivePaneItem (item) =>
      @rowMarker?.destroy() if item isnt @narrowEditor

    if @provider.boundToEditor
      providerEditor = @provider.editor
      @disposables.add providerEditor.onDidChangeCursorPosition(@syncToProviderEditor.bind(this))
      @disposables.add providerEditor.onDidDestroy(@destroy.bind(this))

    @constructor.registerUI(@narrowEditor, this)

  start: ->
    @grammar.activate()
    activePane = atom.workspace.getActivePane()
    direction = settings.get('directionToOpen')
    if direction is 'here'
      @pane = activePane.activateItem(@narrowEditor)
      @autoPreview = false
    else
      @pane = openItemInAdjacentPaneForPane(activePane, @narrowEditor, direction)
      defaultAutoPreviewConfigName = @provider.getName() + "DefaultAutoPreview"
      @autoPreview = settings.get(defaultAutoPreviewConfigName) ? false

    @setPromptLine("\n")
    @moveToPrompt()
    if @input
      @narrowEditor.insertText(@input)
    else
      @refresh()

  focus: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@narrowEditor)

  isAlive: ->
    @narrowEditor?.isAlive?()

  destroy: ->
    return if @destroyed
    @destroyed = true

    @disposables.dispose()
    @narrowEditor.destroy()
    @originalPane.activate() if @originalPane.isAlive()
    @provider?.destroy?()
    @gutterForPrompt?.destroy()
    @constructor.unregisterUI(@narrowEditor)
    @rowMarker?.destroy()

  registerCommands: ->
    atom.commands.add @narrowEditorElement,
      'core:confirm': => @confirm()
      'narrow-ui:confirm-keep-open': => @confirm(keepOpen: true)
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()
      'narrow-ui:force-refresh': => @forceRefresh()
      'narrow-ui:move-to-query-or-current-item': => @moveToQueryOrCurrentItem()
      'narrow-ui:update-real-file': => @updateRealFile()

  updateRealFile: ->
    return unless @provider.supportDirectEdit
    return unless @ensureNarrowEditorIsValidState()

    changes = []
    lines = @narrowEditor.buffer.getLines()
    for line, row in lines when (row >= 1) and @isValidItem(item = @items[row])
      if item._lineHeader?
        line = line[item._lineHeader.length...] # Strip lineHeader

      unless line is item.text
        changes.push({newText: line, item})

    if changes.length
      @provider.updateRealFile(changes)

  moveUpDown: (direction) ->
    if (row = @getRowForSelectedItem()) >= 0
      @withLock => @narrowEditor.setCursorBufferPosition([row, 0])

    @withPreventAutoPreview =>
      switch direction
        when 'up' then @narrowEditor.moveUp()
        when 'down' then @narrowEditor.moveDown()

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
    @lastNarrowQuery = @narrowEditor.lineTextForBufferRow(0)

  getRegExpForWord: (word) ->
    pattern = _.escapeRegExp(word)
    sensitivity = settings.get('caseSensitivityForNarrowQuery')
    if (sensitivity is 'sensitive') or (sensitivity is 'smartcase' and /[A-Z]/.test(word))
      new RegExp(pattern)
    else
      new RegExp(pattern, 'i')

  forceRefresh: ->
    @provider.invalidateCachedItem()
    @moveToPrompt()
    @refresh()

  refresh: ->
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    regexps = words.map (word) => @getRegExpForWord(word)
    @grammar.update(regexps)
    
    @ignoreChangeOnNarrowEditor = true
    Promise.resolve(@provider.getItems()).then (items) =>
      @clearItemsText()
      @setItems(@provider.filterItems(items, regexps))
      @narrowEditorLastRow = @narrowEditor.getLastBufferRow()
      @ignoreChangeOnNarrowEditor = false

  ensureNarrowEditorIsValidState: ->
    # Ensure all item have valid line header
    unless @narrowEditorLastRow is @narrowEditor.getLastBufferRow()
      return false

    if @provider.showLineHeader
      for line, row in @narrowEditor.buffer.getLines() when (row >= 1) and not (item = @items[row]).skip
        return false unless line.startsWith(item._lineHeader)

    true


  observeInputChange: ->
    @narrowEditor.buffer.onDidChange ({newRange, oldRange, newText, oldText}) =>
      return if @ignoreChangeOnNarrowEditor

      promptRange = @getPromptRange()
      onPrompt = (range) -> range.intersectsWith(promptRange)
      notEmptyAndPrompt = (range) -> not range.isEmpty() and onPrompt(range)

      if notEmptyAndPrompt(newRange) or notEmptyAndPrompt(oldRange)
        if @narrowEditor.hasMultipleCursors()
          # Destroy cursors on prompt
          for selection in @narrowEditor.getSelections() when onPrompt(selection.getBufferRange())
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
    @narrowEditor.onDidChangeCursorPosition (event) =>
      return if @isLocked()
      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event
      return if (not cursor.selection.isEmpty()) or
        textChanged or
        (newBufferPosition.row is 0) or
        (oldBufferPosition.row is newBufferPosition.row)

      direction = if (newBufferPosition.row - oldBufferPosition.row) > 0 then 'next' else 'previous'
      {row, column} = newBufferPosition
      @withLock =>
        row = @findValidItem(row, direction)
        if row? # row might be '0'
          @selectItemForRow(row)
          cursor.setBufferPosition([row, column])
        else if direction is 'previous'
          cursor.setBufferPosition([0, column])

      @preview() if @isAutoPreview()

  syncToProviderEditor: ->
    cursorPosition = @provider.editor.getCursorBufferPosition()
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
    narrowEditorRow = @narrowEditor.getCursorBufferPosition().row
    selectedItemRow = @getRowForSelectedItem()

    if (narrowEditorRow isnt 0) and (narrowEditorRow isnt selectedItemRow)
      @withLock => @narrowEditor.setCursorBufferPosition([selectedItemRow, 0])

  setRowMarker: (editor, point) ->
    @rowMarker?.destroy()
    @rowMarker = editor.markBufferRange([point, point])
    editor.decorateMarker(@rowMarker, type: 'line', class: 'narrow-result')

  preview: ->
    @confirm(keepOpen: true).then ({editor, point}) =>
      @setRowMarker(editor, point)
      @focus()

  isValidItem: (item) ->
    item? and not item.skip

  confirm: (options={}) ->
    item = @getSelectedItem()
    Promise.resolve(@provider.confirmed(item)).then ({editor, point}) =>
      unless options.keepOpen
        @narrowEditor.destroy()
      {editor, point}

  # clear text from  2nd row to last row.
  clearItemsText: ->
    range = [[1, 0], @narrowEditor.getEofBufferPosition()]
    @narrowEditor.setTextInBufferRange(range, '')

  appendText: (text) ->
    eof = @narrowEditor.getEofBufferPosition()
    if eof.isLessThan([1, 0])
      eof = @setPromptLine("\n").end
      @moveToPrompt()
    @narrowEditor.setTextInBufferRange([eof, eof], text)

  # Return row
  findValidItem: (startRow, direction) ->
    maxRow = @items.length - 1
    rows = if direction is 'next'
      [startRow..maxRow]
    else
      [startRow..0]

    for row in rows when @isValidItem(@items[row])
      return row
    null

  moveToQueryOrCurrentItem: ->
    row = @getRowForSelectedItem()
    if row is @narrowEditor.getCursorBufferPosition().row
      @moveToPrompt()
    else
      # move to current item
      @narrowEditor.setCursorBufferPosition([row, 0])

  getRowForSelectedItem: ->
    @getRowForItem(@getSelectedItem())

  moveToPrompt: ->
    @narrowEditor.setCursorBufferPosition(@getPromptRange().end)

  getRowForItem: (item) ->
    @items.indexOf(item)

  selectItem: (item) ->
    if (row = @items.indexOf(item) ) >= 0
      @selectItemForRow(row)

  selectItemForRow: (row) ->
    item = @items[row]
    if @isValidItem(item)
      @gutterForPrompt.setToRow(row)
      @selectedItem = item

  getSelectedItem: ->
    @selectedItem ? {}

  setItems: (items) ->
    @items = [{_prompt: true, skip: true}, items...]
    texts = items.map (item) => @provider.viewForItem(item)
    @appendText(texts.join("\n"))
    @selectItemForRow(@findValidItem(1, 'next'))

  getPromptRange: ->
    @narrowEditor.bufferRangeForBufferRow(0)

  # Return range
  setPromptLine: (text) ->
    @ignoreChangeOnNarrowEditor = true
    range = @narrowEditor.setTextInBufferRange(@getPromptRange(0), text)
    @ignoreChangeOnNarrowEditor = false
    range
