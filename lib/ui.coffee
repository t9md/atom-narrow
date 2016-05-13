_ = require 'underscore-plus'
{
  getAdjacentPaneForPane
  getVisibleBufferRange
  openItemInAdjacentPane
} = require './utils'
settings = require './settings'
path = require 'path'

module.exports =
class UI
  autoPreview: false
  blockDecorations: null

  focus: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@editor)

  isAlive: ->
    @editor?.isAlive?()

  buildEditor: (params={}) ->
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @gutter = @editor.addGutter(name: 'narrow')
    @editor.onDidDestroy =>
      @destroy()

    @editorElement = atom.views.getView(@editor)
    @editorElement.classList.add('narrow')
    @editorElement.classList.add(params.class) if params.class

    @editor.onDidChangeCursorPosition ({oldBufferPosition, newBufferPosition, textChanged}) =>
      return if textChanged
      @updateGutter(newBufferPosition)
      if @isAutoPreview() and (oldBufferPosition.row isnt newBufferPosition.row)
        @preview()

    @editor.getTitle = => ["Narrow", @provider?.getTitle()].join(' ')
    @editor.isModified = -> false

  destroy: ->
    @originalPane.activate()
    @provider?.destroy?()
    @gutterMarker?.destroy()

  updateGutter: (point) ->
    if point.row is 0
      point.row = 1
    @gutterMarker?.destroy()
    @gutterMarker = @editor.markBufferPosition(point)
    item = document.createElement('span')
    item.textContent = " > "
    @gutter.decorateMarker(@gutterMarker, {class: "narrow-row", item})

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()
      # 'core:cancel': => @refresh()

  isAutoPreview: -> @autoPreview
  toggleAutoPreview: ->
    if @autoPreview = not @autoPreview
      @preview()

  getItems: ->
    Promise.resolve(@provider.getItems())

  start: (@provider) ->
    @autoPreview = @provider.autoPreview
    direction = settings.get('directionToOpen')
    @pane = openItemInAdjacentPane(@editor, direction)
    @getItems().then (items) =>
      @setItems(items)
      if @initialInput
        @editor.insertText(@initialInput)

  getNarrowQuery: ->
    @editor.lineTextForBufferRow(0)

  clearBlockDecorations: ->
    for decoration in @blockDecorations ? []
      decoration.getMarker().destroy()
    @blockDecorations = null

  refresh: ->
    @clearBlockDecorations()
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))

    @getItems().then (items) =>
      @updateGrammar(@editor, words.map(_.escapeRegExp).join('|'))
      @clearText()
      @setItems(@filterItems(items, words))
      @updateGutter(@editor.getCursorBufferPosition())

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


  addBlockDecorationForBufferRow: (row, item) ->
    @blockDecorations ?= []
    @blockDecorations.push @editor.decorateMarker(
      @editor.markScreenPosition([row, 0], invalidate: "touch"),
      type: "block", item: item, position: "before"
    )

  observeInputChange: (editor) ->
    buffer = editor.getBuffer()
    buffer.onDidChange ({newRange}) =>
      return unless (newRange.start.row is 0)
      @refresh()

  preview: ->
    @confirm(preview: true)

  isValidItem: (item) ->
    filterKey = @provider.getFilterKey()
    return (filterKey of item)

  confirm: (options={}) ->
    point = @editor.getCursorBufferPosition()
    index = if point.row is 0
      0
    else
      point.row - 1
    item = @items[index] ? {}
    return unless @isValidItem(item)
    @provider.confirmed(@items[index] ? {}, options)
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
    @updateGrammar(@editor)
    @observeInputChange(@editor)

  blockDecorationItemForText: (text, options={}) ->
    {classList} = options
    item = document.createElement("div")
    item.textContent = text
    item.classList.add(classList...) if classList?
    console.log item
    {itemType: 'blockDecoration', item}

  setItems: (items) ->
    @items = []
    itemsForDecoration = []

    decorationRow = 1
    for item, i in items
      if item.itemType is 'blockDecoration'
        itemsForDecoration.push([decorationRow, item.item])
      else
        decorationRow = i
        @items.push(item)

    @appendText(
      @items.map (item) =>
        @provider.viewForItem(item)
      .join("\n")
    )
    for [row, item] in itemsForDecoration
      @addBlockDecorationForBufferRow(row, item)

  OriginalGrammarNumberOfPattern = 3
  updateGrammar: (editor, pattern=null) ->
    filePath = path.join(__dirname, 'grammar', 'narrow.cson')

    @grammarObject ?= require './grammar'
    atom.grammars.removeGrammarForScopeName('source.narrow')
    @grammarObject.patterns.splice(OriginalGrammarNumberOfPattern)

    rawPatterns = []
    if @initialKeyword?
      rawPatterns.push(
        match: "(?i:#{_.escapeRegExp(@initialKeyword)})"
        name: 'entity.name.function.narrow'
      )
    if pattern
      rawPatterns.push(
        match: "(?i:#{pattern})"
        name: 'keyword.narrow'
      )
    if rawPatterns.length
      @grammarObject.patterns.push(rawPatterns...)

    grammar = atom.grammars.createGrammar(filePath, @grammarObject)
    atom.grammars.addGrammar(grammar)
    editor.setGrammar(grammar)
