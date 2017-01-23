_ = require 'underscore-plus'

ProviderBase = require './provider-base'
settings = require '../settings'
{getCurrentWordAndBoundary} = require '../utils'

module.exports =
class SearchBase extends ProviderBase
  items: null
  includeHeaderGrammarRules: true
  supportDirectEdit: true
  indentTextForLineHeader: ""

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

  injectMaxLineTextWidth: (items) ->
    # Inject maxLineTextWidth field to each item just for make row header aligned.
    items = items.filter((item) -> not item.skip) # normal item only
    maxRow = Math.max((items.map (item) -> item.point.row)...)
    maxLineTextWidth = String(maxRow + 1).length
    for item in items
      item.maxLineTextWidth = maxLineTextWidth

  # Direct Edit
  # -------------------------
  updateRealFile: (states) ->
    changes = @getChangeSet(states)
    return unless changes.length
    @pane.activate()
    for filePath, changes of _.groupBy(changes, 'filePath')
      @updateFile(filePath, changes)

  getChangeSet: (states) ->
    changes = []
    for {newText, item} in states
      {text, filePath, point} = item
      lineHeaderLength = @getLineHeaderForItem(item).length
      newText = newText[lineHeaderLength...]
      if newText isnt text
        changes.push({row: point.row, text: newText, filePath})
    changes

  updateFile: (filePath, changes) ->
    needSaveAfterEdit = settings.get(@configForSaveAfterDirectEdit)
    atom.workspace.open(filePath).then (editor) ->
      editor.transact ->
        for {row, text} in changes
          range = editor.bufferRangeForBufferRow(row)
          editor.setTextInBufferRange(range, text)
      editor.save() if needSaveAfterEdit

  # Confirmed
  # -------------------------
  confirmed: ({filePath, point}) ->
    return unless point?
    @pane.activate()
    atom.workspace.open(filePath, pending: true).then (editor) ->
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      return {editor, point}
