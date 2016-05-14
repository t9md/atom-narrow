_ = require 'underscore-plus'
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

  observeCursorPositionChange: ->
    @editor.onDidChangeCursorPosition ({oldBufferPosition, newBufferPosition, textChanged}) =>
      return if textChanged
      @selectItemForRow(newBufferPosition.row)
      if @isAutoPreview() and (oldBufferPosition.row isnt newBufferPosition.row)
        @preview()

  preview: ->
    @confirm(preview: true)

  isValidItem: (item) ->
    filterKey = @provider.getFilterKey()
    return (filterKey of item)

  setGutterMarkerToRow: (row) ->
    @gutterMarker?.destroy()
    @gutterMarker = @editor.markBufferPosition([row, 0])
    item = document.createElement('span')
    item.textContent = " > "
    @gutter.decorateMarker(@gutterMarker, {class: "narrow-row", item})

  confirm: (options={}) ->
    return unless @isValidItem(item = @getSelectedItem())
    @provider.confirmed(item, options)
    unless options.preview ? false
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

  selectFirstValidItem: (startRow) ->
    skip = Math.max(startRow - 1, 0)
    for item, i in @items.slice(skip) when @isValidItem(item)
      row = i + skip + 1
      break

    @selectItemForRow(row)

  selectItemForRow: (row) ->
    item = @items[row - 1]
    if item? and @isValidItem(item)
      @setGutterMarkerToRow(row)
      @selectedItem = item

  getSelectedItem: ->
    @selectedItem ? {}

  setItems: (@items) ->
    text = (@provider.viewForItem(item) for item in @items).join("\n")
    @appendText(text)
    @selectFirstValidItem(1)
    # @selectFirstValidItem(1)
