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
  show: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@editor)

  isAlive: ->
    @editor?.isAlive?()

  buildEditor: (params={}) ->
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @gutter = @editor.addGutter(name: 'narrow')
    @editor.onDidDestroy =>
      @originalPane.activate()
      @provider?.destroy?()

    @editorElement = atom.views.getView(@editor)
    @editorElement.classList.add('narrow')
    @editorElement.classList.add(params.class) if params.class

    @editor.onDidChangeCursorPosition ({oldBufferPosition, newBufferPosition, textChanged}) =>
      return if textChanged
      @updateGutter(newBufferPosition)
      if @isAutoPreview() and (oldBufferPosition.row isnt newBufferPosition.row)
        @confirm(preview: true)

    @editor.getTitle = => ["Narrow", @provider?.getTitle()].join(' ')
    @editor.isModified = -> false

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
      'narrow-ui:preview-item': => @confirm(preview: true)
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()
      # 'core:cancel': => @refresh()

  isAutoPreview: -> @autoPreview
  toggleAutoPreview: -> @autoPreview = not @autoPreview

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

  refresh: ->
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    filterKey = @provider.getFilterKey()

    @getItems().then (items) =>
      patterns = []
      for word in words
        pattern = _.escapeRegExp(word)
        patterns.push(pattern)

        items = _.filter items, (item) ->
          if filterKey of item
            item[filterKey].match(///#{pattern}///i)
          else
            # When item has no filterKey, it is special, always displayed.
            true

      @updateGrammar(@editor, patterns.join('|'))
      @setItems(items)
      @updateGutter(@editor.getCursorBufferPosition())

  observeInputChange: (editor) ->
    buffer = editor.getBuffer()
    buffer.onDidChange ({newRange}) =>
      return unless (newRange.start.row is 0)
      @refresh()

  confirm: (options={}) ->
    point = @editor.getCursorBufferPosition()
    index = if point.row is 0
      0
    else
      point.row - 1
    @provider.confirmed(@items[index] ? {}, options)
    unless options.preview ? false
      @editor.destroy()

  appendText: (text) ->
    range = [[1, 0], @editor.getEofBufferPosition()]
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

  setItems: (@items) ->
    lines = []
    lines.push(@provider.viewForItem(item)) for item in @items
    @appendText(lines.join("\n"))

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
