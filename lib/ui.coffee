_ = require 'underscore-plus'
fuzzaldrin = require 'fuzzaldrin'
{
  getAdjacentPaneForPane
  getVisibleBufferRange
  openItemInAdjacentPane
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

    @editorElement = atom.views.getView(@editor)
    @editorElement.classList.add('narrow')
    @editorElement.classList.add(params.class) if params.class

    @editor.getTitle = => @provider?.getTitle()
    @editor.isModified = -> false

  destroy: ->
    @originalPane.activate()
    @provider?.destroy?()
    @gutterMarker?.destroy()

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'narrow-ui:open-without-close': => @confirm(keepOpen: true)
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()

  isAutoPreview: -> @autoPreview
  toggleAutoPreview: ->
    if @autoPreview = not @autoPreview
      @preview()

  getItems: ->
    Promise.resolve(@provider.getItems())

  start: (@provider) ->
    if @provider.constructor.name is 'Search'
      includeHeaderRules = true
    @grammar = new NarrowGrammar(@editor, {@initialKeyword, includeHeaderRules})
    @grammar.activate()

    @autoPreview = @provider.autoPreview
    direction = settings.get('directionToOpen')
    @pane = openItemInAdjacentPane(@editor, direction)
    @getItems().then (items) =>
      @setItems(items)
      if @initialInput
        @editor.insertText(@initialInput)

  getNarrowQuery: ->
    @editor.lineTextForBufferRow(0)

  refresh: ->
    # @clearBlockDecorations()
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))

    @getItems().then (items) =>
      @grammar.update(pattern: words.map(_.escapeRegExp).join('|'))
      @clearText()

      items = if @provider.filterItems?
        @provider.filterItems(items, words)
      else
        if @provider.useFuzzyFilter()
          filteredItems = fuzzaldrin.filter(items.slice(), query, key: @provider.getFilterKey())
          if @provider.keepItemsOrderOnFuzzyFilter()
            items = items.filter((item) -> item in filteredItems)
          else
            filteredItems
        else
          @filterItems(items, words)
      @setItems(items)

  filterItems: (items, words) ->
    filterKey = @provider.getFilterKey()

    filter = (items, pattern) ->
      _.filter items, (item) ->
        if filterKey of item
          item[filterKey].match(///#{pattern}///i)
        else
          # When item has no filterKey, it is special, always displayed.
          true

    for pattern in words.map(_.escapeRegExp)
      items = filter(items, pattern)
    items

  observeInputChange: ->
    buffer = @editor.getBuffer()
    buffer.onDidChange ({newRange}) =>
      return unless (newRange.start.row is 0)
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
      return if @isLocked() or textChanged
      return if (oldBufferPosition.row is newBufferPosition.row)

      if (newBufferPosition.row - oldBufferPosition.row) > 0
        direction = 'next'
      else
        direction = 'previous'

      {row, column} = newBufferPosition
      if (row = @selectFirstValidItem(row, direction))?
        @withLock -> cursor.setBufferPosition([row, column])
      else if direction is 'previous'
        cursor.setBufferPosition([row, column])

      @preview() if @isAutoPreview()

  preview: ->
    @confirm(preview: true)

  isValidItem: (item) ->
    item? and not item.skip

  setGutterMarkerToRow: (row) ->
    @gutterMarker?.destroy()
    @gutterMarker = @editor.markBufferPosition([row, 0])
    item = document.createElement('span')
    item.textContent = " > "
    @gutter.decorateMarker(@gutterMarker, {class: "narrow-row", item})

  confirm: (options={}) ->
    return unless @isValidItem(item = @getSelectedItem())
    @provider.confirmed(item, options)
    unless options.preview or options.keepOpen
      @editor.destroy()

  clearText: ->
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

  selectFirstValidItem: (startRow, direction) ->
    maxRow = @items.length - 1
    rows = if direction is 'next'
      [startRow..maxRow]
    else
      [startRow..0]

    for row in rows when @isValidItem(@items[row])
      @selectItemForRow(row)
      return row

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
    @selectFirstValidItem(1, 'next')
