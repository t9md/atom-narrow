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
  @fromProvider: (provider) ->
    narrow = new this
    Promise.resolve(provider.getItems()).then (items) ->
      narrow.setItems(items)

  buildEditor: (params={}) ->
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @editor.onDidDestroy =>
      @originalPane.activate()
      @provider?.destroy?()

    @editorElement = atom.views.getView(@editor)
    @editorElement.classList.add('narrow')
    @editorElement.classList.add(params.class) if params.class

    @editor.getTitle = -> ["Narrow", params.title].join(' ')
    @editor.isModified = -> false

  getItems: ->
    Promise.resolve(@provider.getItems())

  start: (@provider) ->
    direction = settings.get('directionToOpen')
    openItemInAdjacentPane(@editor, direction)
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

  appendText: (text) ->
    range = [[1, 0], @editor.getEofBufferPosition()]
    @editor.setTextInBufferRange(range, text)

  constructor: (params={}) ->
    {@initialKeyword} = params
    @originalPane = atom.workspace.getActivePane()
    @buildEditor(params)
    @editor.insertText("\n")
    @editor.setCursorBufferPosition([0, 0])
    @updateGrammar(@editor)
    @observeInputChange(@editor)

  setItems: (items) ->
    lines = []
    lines.push(@provider.viewForItem(item)) for item in items
    @appendText(lines.join("\n"))

  renderItems: (items) ->
    # initialRow = if replace then 1 else editor.getLastBufferRow()
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
        name: 'keyword.search.search-and-replace'
      )
    if rawPatterns.length
      @grammarObject.patterns.push(rawPatterns...)

    grammar = atom.grammars.createGrammar(filePath, @grammarObject)
    atom.grammars.addGrammar(grammar)
    editor.setGrammar(grammar)

  autoReveal: null
  isAutoReveal: -> @autoReveal
  toggleAutoReveal: ->
    @autoReveal = not @autoReveal

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
