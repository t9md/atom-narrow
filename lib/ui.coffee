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

  constructor: (@provider, params={}) ->
    @disposables = new CompositeDisposable
    {@initialKeyword, @input} = params

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
    @grammar = new NarrowGrammar(@narrowEditor, {@initialKeyword, includeHeaderRules})
    @grammar.activate()

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
    activePane = atom.workspace.getActivePane()
    direction = settings.get('directionToOpen')
    if direction is 'here'
      @pane = activePane.activateItem(@narrowEditor)
      @autoPreview = false
    else
      @pane = openItemInAdjacentPaneForPane(activePane, @narrowEditor, direction)
      defaultAutoPreviewConfigName = @provider.getName() + "DefaultAutoPreview"
      @autoPreview = settings.get(defaultAutoPreviewConfigName) ? false

    @narrowEditor.insertText("\n")
    @narrowEditor.setCursorBufferPosition([0, Infinity])
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
    @narrowEditor.lineTextForBufferRow(0)

  forceRefresh: ->
    @provider.invalidateCachedItem()
    @narrowEditor.setCursorBufferPosition([0, Infinity])
    @refresh()

  refreshing: false
  refresh: ->
    @refreshing = true
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    pattern = words.map(_.escapeRegExp).join('|')
    @grammar.update({pattern})

    Promise.resolve(@provider.getItems()).then (items) =>
      @clearItemsText()
      @setItems(@provider.filterItems(items, words))
      @refreshing = false

  observeInputChange: ->
    @narrowEditor.buffer.onDidChange ({newRange, oldRange}) =>
      if not newRange.isEmpty() and (newRange.start.row is 0) and (newRange.end.row is 0)
        return @refresh()

      if not oldRange.isEmpty() and (oldRange.start.row is 0) and (oldRange.end.row is 0)
        return @refresh()

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
      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event
      return if @isLocked() or
        not cursor.selection.isEmpty() or
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

  preview: ->
    @confirm(keepOpen: true).then ({editor, point}) =>
      @rowMarker = @highlightRow(editor, Point.fromObject(point).row)
      @focus()

  isValidItem: (item) ->
    item? and not item.skip

  highlightRow: (editor, row) ->
    point = [row, 0]
    marker = editor.markBufferRange([point, point])
    editor.decorateMarker(marker, type: 'line', class: 'narrow-result')
    marker

  confirm: (options={}) ->
    @rowMarker?.destroy()
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
      eof = @narrowEditor.getLastSelection().insertText("\n").end
      @narrowEditor.setCursorBufferPosition([0, Infinity])
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
      # move to query
      @narrowEditor.setCursorBufferPosition([0, Infinity])
    else
      # move to current item
      @narrowEditor.setCursorBufferPosition([row, 0])

  getRowForSelectedItem: ->
    @getRowForItem(@getSelectedItem())

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
