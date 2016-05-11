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

    @editor.onDidChangeCur
    @editor.onDidChangeCursorPosition ({oldBufferPosition, newBufferPosition, textChanged}) =>
      return if textChanged
      if @isAutoReveal() and (oldBufferPosition.row isnt newBufferPosition.row)
        @confirm(reveal: true)

    @editor.getTitle = -> ["Narrow", params.title].join(' ')
    @editor.isModified = -> false

  registerCommands: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'narrow:ui:reveal-item': => @confirm(reveal: true)
      'narrow:ui:toggle-auto-reveal': => @toggleAutoReveal()
      # 'core:cancel': => @refresh()

  autoReveal: null
  isAutoReveal: ->
    @autoReveal
  toggleAutoReveal: ->
    @autoReveal = not @autoReveal

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

  # clearEditor: ->
  #   range = [[1, 0], @editor.getEofBufferPosition()]
  #   @editor.setTextInBufferRange(range, "")
  confirm: (options) ->
    point = @editor.getCursorBufferPosition()
    index = if point.row is 0
      0
    else
      point.row - 1
    @provider.confirmed(@items[index] ? {}, options)
    # else
    #   @provider.confirmed(@items[point.row - 1] ? {})

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

  renderItems: (items) ->
    initialRow = @editor.getLastBufferRow()

    @rowToItem = {}
    lines = []
    for item, i in items
      @rowToItem[i+1] = item
      lines.push(@provider.viewForItem(item))
    @appendText(lines.join("\n"))

    # for item in items
    #   if showHeader
    #     if item.project isnt currentProject
    #       currentProject = item.project
    #       lines.push("# #{path.basename(currentProject)}")
    #
    #     if item.filePath isnt currentFile
    #       currentFile = item.filePath
    #       lines.push("## #{currentFile}")
    #     lines.push(" " + @formatLine(item))
    #   else
    #     lines.push(@formatLine(item))
    #   @rowToEntry[initialRow + (lines.length - 1)] = item
    #
    # range = [[initialRow, 0], editor.getEofBufferPosition()]
    # editor.setTextInBufferRange(range, lines.join("\n") + "\n")

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


  renderCandidate: (editor, candidates, {replace, showHeader}={}) ->
    @locked = true
    try
      replace ?= false
      if replace
        @rowToEntry = {}
      else
        @rowToEntry ?= {}

      lines = []
      currentProject = null
      currentFile = null
      initialRow = if replace then 1 else editor.getLastBufferRow()
      for entry in candidates
        if showHeader
          if entry.project isnt currentProject
            currentProject = entry.project
            lines.push("# #{path.basename(currentProject)}")

          if entry.filePath isnt currentFile
            currentFile = entry.filePath
            lines.push("## #{currentFile}")
          lines.push(" " + @formatLine(entry))
        else
          lines.push(@formatLine(entry))
        @rowToEntry[initialRow + (lines.length - 1)] = entry

      range = [[initialRow, 0], editor.getEofBufferPosition()]
      editor.setTextInBufferRange(range, lines.join("\n") + "\n")
    finally
      @locked = false
