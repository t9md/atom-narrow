{Point} = require 'atom'
_ = require 'underscore-plus'

ProviderBase = require './provider-base'
settings = require '../settings'
{padStringLeft, getCurrentWordAndBoundary} = require '../utils'

module.exports =
class AtomScan extends ProviderBase
  items: null
  includeHeaderGrammarRules: true
  supportDirectEdit: true

  checkReady: ->
    if @options.currentWord
      {word, boundary} = getCurrentWordAndBoundary(@editor)
      @options.wordOnly = boundary
      @options.search = word

    if @options.search
      Promise.resolve(true)
    else
      @readInput().then (input) =>
        @options.search = input
        true

  initialize: ->
    source = _.escapeRegExp(@options.search)
    if @options.wordOnly
      source = "\\b#{source}\\b"
    searchTerm = "(?i:#{source})"
    @ui.grammar.setSearchTerm(searchTerm)

  getItems: ->
    if @items?
      @items
    else
      resultsByFilePath = {}

      source = _.escapeRegExp(@options.search)
      if @options.wordOnly
        regexp = ///\b#{source}\b///i
      else
        regexp = ///#{source}///i

      scanPromise = atom.workspace.scan regexp, (result) ->
        if result?.matches?.length
          (resultsByFilePath[result.filePath] ?= []).push(result.matches...)

      scanPromise.then =>
        items = []
        for filePath, results of resultsByFilePath
          header = "# #{filePath}"
          items.push({header, filePath, skip: true})
          rows = []
          for item in results
            filePath = filePath
            text = item.lineText
            point = Point.fromObject(item.range[0])
            if point.row not in rows
              rows.push(point.row) # ensure single item per row
              items.push({filePath, text, point})

        @injectMaxLineTextWidth(items)
        @items = items

  injectMaxLineTextWidth: (items) ->
    # Inject maxLineTextWidth field to each item just for make row header aligned.
    items = items.filter((item) -> not item.skip) # normal item only
    maxRow = Math.max((items.map (item) -> item.point.row)...)
    maxLineTextWidth = String(maxRow + 1).length
    for item in items
      item.maxLineTextWidth = maxLineTextWidth

  confirmed: ({filePath, point}) ->
    return unless point?
    @pane.activate()
    atom.workspace.open(filePath, pending: true).then (editor) ->
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      return {editor, point}

  filterItems: (items, regexps) ->
    filterKey = @getFilterKey()
    for regexp in regexps
      items = items.filter (item) ->
        item.skip or regexp.test(item[filterKey])
    items

    normalItems = _.filter(items, (item) -> not item.skip)
    filePaths = _.uniq(_.pluck(normalItems, "filePath"))

    _.filter items, (item) ->
      if item.header?
        item.filePath in filePaths
      else
        true

  getRowHeaderForItem: (item) ->
    "  " + padStringLeft(String(item.point.row + 1), item.maxLineTextWidth) + ":"

  viewForItem: (item) ->
    if item.header?
      item.header
    else
      @getRowHeaderForItem(item) + item.text

  updateRealFile: (states) ->
    changes = @getChangeSet(states)
    return unless changes.length
    @pane.activate()
    for filePath, changes of _.groupBy(changes, 'filePath')
      @updateFile(filePath, changes)

  updateFile: (filePath, changes) ->
    atom.workspace.open(filePath).then (editor) ->
      editor.transact ->
        for {row, text} in changes
          range = editor.bufferRangeForBufferRow(row)
          editor.setTextInBufferRange(range, text)
      if settings.get('AtomScanSaveAfterDirectEdit')
        editor.save()

  getChangeSet: (states) ->
    changes = []
    for {newText, item} in states
      {text, filePath, point} = item
      newText = newText[@getRowHeaderForItem(item).length...]
      if newText isnt text
        changes.push({row: point.row, text: newText, filePath})
    changes
