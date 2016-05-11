_ = require 'underscore-plus'
{
  getAdjacentPaneForPane
  getVisibleBufferRange
  openItemInAdjacentPane
} = require './utils'
settings = require './settings'
path = require 'path'

module.exports =
class Narrow
  autoReveal: null
  show: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@editor)

  isAlive: ->
    @editor?.isAlive?()

  buildEditor: (params={}) ->
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @editor.onDidDestroy =>
      @originalPane.activate()
      @provider?.destroy?()

    @editorElement = atom.views.getView(@editor)
    @editorElement.classList.add('narrow')
    @editorElement.classList.add(params.class) if params.class

    @editor.onDidChangeCursorPosition ({oldBufferPosition, newBufferPosition, textChanged}) =>
      return if textChanged
      if @isAutoReveal() and (oldBufferPosition.row isnt newBufferPosition.row)
        @confirm(reveal: true)

    @editor.getTitle = => ["Narrow", @provider?.getTitle()].join(' ')
    @editor.isModified = -> false

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'narrow-ui:reveal-item': => @confirm(reveal: true)
      'narrow-ui:toggle-auto-reveal': => @toggleAutoReveal()
      # 'core:cancel': => @refresh()

  isAutoReveal: -> @autoReveal
  toggleAutoReveal: -> @autoReveal = not @autoReveal

  getItems: ->
    Promise.resolve(@provider.getItems())

  start: (@provider) ->
    direction = settings.get('directionToOpen')
    @pane = openItemInAdjacentPane(@editor, direction)
    @getItems().then (items) =>
      @setItems(items)

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
          item[filterKey].match(///#{pattern}///i)

      @updateGrammar(@editor, patterns.join('|'))
      @setItems(items)

  observeInputChange: (editor) ->
    buffer = editor.getBuffer()
    buffer.onDidChange ({newRange}) =>
      return unless (newRange.start.row is 0)
      @refresh()

  confirm: (options) ->
    point = @editor.getCursorBufferPosition()
    index = if point.row is 0
      0
    else
      point.row - 1
    @provider.confirmed(@items[index] ? {}, options)

  appendText: (text) ->
    range = [[1, 0], @editor.getEofBufferPosition()]
    @editor.setTextInBufferRange(range, text)

  constructor: (params={}) ->
    {@initialKeyword} = params
    @originalPane = atom.workspace.getActivePane()
    @buildEditor(params)
    @editor.insertText("\n")
    @editor.setCursorBufferPosition([0, 0])
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
