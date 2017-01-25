_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{getCurrentWordAndBoundary} = require '../utils'

module.exports =
class SearchBase extends ProviderBase
  items: null
  includeHeaderGrammar: true
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

  # Confirmed
  # -------------------------
  confirmed: ({filePath, point}) ->
    return unless point?
    @pane.activate()
    atom.workspace.open(filePath, pending: true).then (editor) ->
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      return {editor, point}
