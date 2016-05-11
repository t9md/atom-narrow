_ = require 'underscore-plus'
{emitter, Emitter} = require 'atom'
{getAdjacentPaneForPane, getVisibleBufferRange} = require './utils'
CSON = null
path = require 'path'

module.exports =
class Narrow
  @fromProvider: (provider) ->
    narrow = new this
    Promise.resolve(provider.getItems()).then (items) ->
      narrow.setItems(items)

  onDidInputChange: (fn) -> @emitter.on 'did-input-change', fn
  emitDidInputChange: (event) -> @emitter.emit('did-input-change', event)

  onDidItemSelected: (fn) -> @emitter.on 'did-item-selected', fn
  emitDidItemSelected: (event) -> @emitter.emit('did-item-selected', event)

  buildEditor: (params={}) ->
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @editor.onDidDestroy =>
      @markerLayer?.destroy()
      @provider?.destroy?()

    @editorElement = atom.views.getView(@editor)
    @editorElement.classList.add('narrow')
    @editorElement.classList.add(params.class) if params.class

    @editor.getTitle = -> ["Narrow", params.title].join(' ')
    @editor.isModified = -> false

  openInAdjacentPane: ->
    activePane = atom.workspace.getActivePane()
    if pane = getAdjacentPaneForPane(activePane)
      pane.activateItem(@editor)
    else
      pane = activePane.splitRight(items: [@editor])
    pane.activate()

  init: ->
    # @editor.insertText(" > \n")
    @editor.insertText("\n")
    @editor.setCursorBufferPosition([0, 0])
    @updateGrammar(@editor)
    @observeInputChange(@editor)

  getItems: ->
    Promise.resolve(@provider.getItems())
    # .then (items) =>
    #   @setItems(items)

  start: (@provider) ->
    @openInAdjacentPane()
    @getItems().then (items) =>
      @setItems(items)

  getNarrowQuery: ->
    @editor.lineTextForBufferRow(0)

  refresh: ->
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    filterKey = @provider.getFilterKey()

    @getItems().then (items) =>
      @markerLayer?.destroy()
      @decorationLayer?.destroy()
      @markerLayer = @editor.addMarkerLayer()
      @decorationLayer = @editor.decorateMarkerLayer(@markerLayer, {type: 'highlight', class: 'narrow-match'})

      patterns = []
      for word in words
        pattern = _.escapeRegExp(word)
        patterns.push(pattern)

        items = _.filter items, (item) ->
          item[filterKey].match(///#{pattern}///i)
      # @updateGrammar(@editor, patterns.join('|'))
      @setItems(items)
      pattern = ///#{patterns.join('|')}///gi
      scanRange = getVisibleBufferRange(@editor)
      @editor.scanInBufferRange pattern, scanRange, ({range}) =>
        @markerLayer.markBufferRange(range)

  observeInputChange: (editor) ->
    buffer = editor.getBuffer()
    buffer.onDidChange ({newRange}) =>
      return unless (newRange.start.row is 0)
      @refresh()

  clearEditor: ->
    range = [[1, 0], @editor.getEofBufferPosition()]
    @editor.setTextInBufferRange(range, "")

  appendText: (text) ->
    range = [[1, 0], @editor.getEofBufferPosition()]
    @editor.setTextInBufferRange(range, text)

  constructor: (params) ->
    @emitter = new Emitter
    # markerLayerOptions = if @editor.displayLayer? then {persistent: true} else {maintainHistory: true}
    @buildEditor(params)

    @init()

  setItems: (items) ->
    lines = []
    lines.push(@provider.viewForItem(item)) for item in items
    @appendText(lines.join("\n"))

  render: (items) ->

  readGrammarFile: (filePath) ->
    CSON ?= require 'season'
    CSON.readFileSync(filePath)

  updateGrammar: (editor, pattern=null) ->
    filePath = path.join(__dirname, 'grammar', 'narrow.cson')
    @grammarObject ?= @readGrammarFile(filePath)
    atom.grammars.removeGrammarForScopeName('source.narrow')
    if pattern?
      @grammarObject.patterns[0].match = "(?i:#{pattern})"
    else
      @grammarObject.patterns[0].match = '$a'
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
