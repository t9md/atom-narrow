_ = require 'underscore-plus'
{
  getAdjacentPaneForPane
  getVisibleBufferRange
  openItemInAdjacentPaneForPane
} = require './utils'
settings = require './settings'
path = require 'path'
NarrowGrammar = require './grammar'

module.exports =
class UI
  autoPreview: false
  items: []

  focus: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@editor)

  isAlive: ->
    @editor?.isAlive?()

  buildEditor: (params={}) ->
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @gutter = @editor.addGutter(name: 'narrow')
    @editor.onDidDestroy => @destroy()

    @editorElement = @editor.element
    @editorElement.classList.add('narrow')
    @editorElement.classList.add(params.class) if params.class

    @editor.getTitle = => @provider?.getTitle()
    @editor.isModified = -> false

  destroy: ->
    @originalPane.activate() if @originalPane.isAlive()
    @provider?.destroy?()
    @gutterMarker?.destroy()

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'narrow-ui:open-without-close': => @confirm(keepOpen: true)
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()

  isAutoPreview: ->
    @autoPreview

  toggleAutoPreview: ->
    @autoPreview = not @autoPreview
    @preview() if @isAutoPreview()

  getItems: ->
    Promise.resolve(@provider.getItems())

  start: (@provider) ->
    if @provider.constructor.name is 'Search'
      includeHeaderRules = true
    @grammar = new NarrowGrammar(@editor, {@initialKeyword, includeHeaderRules})
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

    @getItems().then (items) =>
      @setItems(items)
      if @initialInput
        @editor.insertText(@initialInput)

  getNarrowQuery: ->
    @editor.lineTextForBufferRow(0)

  refresh: ->
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    pattern = words.map(_.escapeRegExp).join('|')

    @getItems().then (items) =>
      @grammar.update({pattern})
      @clearItemsText()
      @setItems(@provider.filterItems(items, words))

  observeInputChange: ->
    buffer = @editor.getBuffer()
    buffer.onDidChange ({newRange}) =>
      if newRange.start.row is 0
        @refresh()

  locked: false
  isLocked: -> @locked
  withLock: (fn) ->
    @locked = true
    fn()
    @locked = false

  observeCursorPositionChange: ->
    @editor.onDidChangeCursorPosition (event) =>
      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event
      return if @isLocked() or
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
    @gutterMarker = @editor.markBufferPosition([row, 0])
    @gutter.decorateMarker @gutterMarker,
      class: "narrow-ui-row"
      item: @getGutterItem()

  confirm: (options={}) ->
    @provider.confirmed(@getSelectedItem(), options)
    unless options.preview or options.keepOpen
      @editor.destroy()

  # clear text from  2nd row to last row.
  clearItemsText: ->
    start = [1, 0]
    end = @editor.getEofBufferPosition()
    range = [start, end]
    @editor.setTextInBufferRange(range, '')

  appendText: (text) ->
    row = @editor.getLastBufferRow()
    range = [[row, 0], [row, Infinity]]
    @editor.setTextInBufferRange(range, text)

  constructor: (params={}) ->
    {@initialKeyword, @initialInput} = params
    @originalPane = atom.workspace.getActivePane()
    @buildEditor(params)

    # [FIXME?] With just "\n", narrow:line fail to syntax highlight
    # with custom grammar on initial open.s
    @editor.insertText("\n ")
    @editor.setCursorBufferPosition([0, Infinity])

    @registerCommands()
    @observeInputChange()
    @observeCursorPositionChange()

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
    @selectItemForRow(@findValidItem(1, 'next'))
