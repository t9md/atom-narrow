_ = require 'underscore-plus'
{Point, CompositeDisposable} = require 'atom'
{
  getAdjacentPaneForPane
  openItemInAdjacentPaneForPane
} = require './utils'
settings = require './settings'
path = require 'path'
NarrowGrammar = require './grammar'

module.exports =
class UI
  @uiByNarrowEditor: new Map()
  autoPreview: false
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

  focus: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@narrowEditor)

  isAlive: ->
    @narrowEditor?.isAlive?()

  buildEditor: (params={}) ->
    @narrowEditor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @gutter = @narrowEditor.addGutter(name: 'narrow')
    @narrowEditor.onDidDestroy => @destroy()

    @narrowEditorElement = @narrowEditor.element
    @narrowEditorElement.classList.add('narrow')
    # @narrowEditorElement.classList.add(params.class) if params.class

    @narrowEditor.getTitle = => @provider?.getTitle()
    @narrowEditor.isModified = -> false

  destroy: ->
    @disposables.dispose()
    @originalPane.activate() if @originalPane.isAlive()
    @provider?.destroy?()
    @gutterMarker?.destroy()
    @constructor.unregisterUI(@narrowEditor)

  registerCommands: ->
    atom.commands.add @narrowEditorElement,
      'core:confirm': => @confirm()
      'narrow-ui:open-without-close': => @confirm(keepOpen: true)
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()
      'core:move-down': (event) =>
        event.stopImmediatePropagation()
        @nextItem(preview: true)
      'core:move-up': (event) =>
        event.stopImmediatePropagation()
        @previousItem(preview: true)

  moveUpDown: (direction, {preview}={}) ->
    if (row = @getRowForSelectedItem()) >= 0
      @withLock => @narrowEditor.setCursorBufferPosition([row, 0])

    switch direction
      when 'up' then @narrowEditor.moveUp()
      when 'down' then @narrowEditor.moveDown()

    if preview
      @preview()
    else
      @confirm(keepOpen: true)

  nextItem: (options) ->
    @moveUpDown('down', options)

  previousItem: (options) ->
    @moveUpDown('up', options)

  isAutoPreview: ->
    @autoPreview

  toggleAutoPreview: ->
    @autoPreview = not @autoPreview
    @preview() if @isAutoPreview()

  getItems: ->
    Promise.resolve(@provider.getItems())

  start: (@provider) ->
    if @provider.getName() in ['Search', 'Bookmarks']
      includeHeaderRules = true
    @grammar = new NarrowGrammar(@narrowEditor, {@initialKeyword, includeHeaderRules})
    @grammar.activate()
    @narrowEditorElement.classList.add(_.dasherize(@provider.getName()))

    if @provider.editor?
      @disposables.add @provider.editor.onDidChangeCursorPosition =>
        if @items.length and item = @findNearestItem(@items)
          @selectItem(item)

    activePane = atom.workspace.getActivePane()
    direction = settings.get('directionToOpen')
    if direction is 'here'
      @pane = activePane.activateItem(@narrowEditor)
      @autoPreview = false
    else
      @pane = openItemInAdjacentPaneForPane(activePane, @narrowEditor, direction)
      defaultAutoPreviewConfigName = @provider.getName() + "DefaultAutoPreview"
      @autoPreview = settings.get(defaultAutoPreviewConfigName) ? false

    @getItems().then (items) =>
      @setItems(items)
      if @initialInput
        @narrowEditor.insertText(@initialInput)

  findNearestItem: (items) ->
    cursorPosition = @provider.editor.getCursorBufferPosition()
    # Detect item
    # - cursor position is equal or greather than that item.
    for item, i in items by -1 when item.point?
      itemPoint = Point.fromObject(item.point)
      break if itemPoint.isLessThanOrEqual(cursorPosition)
    return item

  getNarrowQuery: ->
    @narrowEditor.lineTextForBufferRow(0)

  refresh: ->
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    pattern = words.map(_.escapeRegExp).join('|')

    @getItems().then (items) =>
      @grammar.update({pattern})
      @clearItemsText()
      @setItems(@provider.filterItems(items, words))

  observeInputChange: ->
    buffer = @narrowEditor.getBuffer()
    buffer.onDidChange ({newRange}) =>
      if newRange.start.row is 0
        @refresh()

  locked: false
  isLocked: -> @locked
  withLock: (fn) ->
    @locked = true
    fn()
    @locked = false

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

  preview: ->
    @confirm(preview: true)
    @focus()

  isValidItem: (item) ->
    item? and not item.skip

  getGutterItem: ->
    @gutterItem ?= (
      item = document.createElement('span')
      item.textContent = " > "
      item
    )

  setGutterMarkerToRow: (row) ->
    @gutterMarker?.destroy()
    @gutterMarker = @narrowEditor.markBufferPosition([row, 0])
    @gutter.decorateMarker @gutterMarker,
      class: "narrow-ui-row"
      item: @getGutterItem()

  confirm: (options={}) ->
    @provider.confirmed(@getSelectedItem(), options)
    unless options.preview or options.keepOpen
      @narrowEditor.destroy()

  # clear text from  2nd row to last row.
  clearItemsText: ->
    start = [1, 0]
    end = @narrowEditor.getEofBufferPosition()
    range = [start, end]
    @narrowEditor.setTextInBufferRange(range, '')

  appendText: (text) ->
    row = @narrowEditor.getLastBufferRow()
    range = [[row, 0], [row, Infinity]]
    @narrowEditor.setTextInBufferRange(range, text)

  constructor: (params={}) ->
    @disposables = new CompositeDisposable
    {@initialKeyword, @initialInput} = params
    @originalPane = atom.workspace.getActivePane()
    @buildEditor(params)

    # [FIXME?] With just "\n", narrow:line fail to syntax highlight
    # with custom grammar on initial open.s
    @narrowEditor.insertText("\n ")
    @narrowEditor.setCursorBufferPosition([0, Infinity])

    @registerCommands()
    @observeInputChange()
    @observeCursorPositionChangeForNarrowEditor()
    @constructor.registerUI(@narrowEditor, this)

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

  getRowForSelectedItem: ->
    @getRowForItem(@getSelectedItem())

  getRowForItem: (item) ->
    @items.indexOf(item)

  selectItem: (item) ->
    row = @items.indexOf(item)
    if row >= 0
      @selectItemForRow(row)

  selectItemForRow: (row) ->
    item = @items[row]
    if item? and @isValidItem(item)
      @setGutterMarkerToRow(row)
      @selectedItem = item

  getSelectedItem: ->
    @selectedItem ? {}

  setItems: (items) ->
    @items = [{_prompt: true, skip: true}, items...]
    text = (@provider.viewForItem(item) for item in items).join("\n")
    @appendText(text)

    if @provider.editor? and item = @findNearestItem(items)
      @selectItem(item)
    else
      @selectItemForRow(@findValidItem(1, 'next'))
