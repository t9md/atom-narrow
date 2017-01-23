_ = require 'underscore-plus'

ProviderBase = require './provider-base'
settings = require '../settings'
{getCurrentWordAndBoundary} = require '../utils'

module.exports =
class SearchBase extends ProviderBase
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

  injectMaxLineTextWidth: (items) ->
    # Inject maxLineTextWidth field to each item just for make row header aligned.
    items = items.filter((item) -> not item.skip) # normal item only
    maxRow = Math.max((items.map (item) -> item.point.row)...)
    maxLineTextWidth = String(maxRow + 1).length
    for item in items
      item.maxLineTextWidth = maxLineTextWidth

  # Confirmed
  # -------------------------
  confirmed: ({filePath, point}) ->
    return unless point?
    @pane.activate()
    atom.workspace.open(filePath, pending: true).then (editor) ->
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      return {editor, point}
