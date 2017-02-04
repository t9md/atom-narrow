_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{getCurrentWordAndBoundary} = require '../utils'

module.exports =
class SearchBase extends ProviderBase
  includeHeaderGrammar: true
  supportDirectEdit: true
  showLineHeader: true
  showColumnOnLineHeader: true

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

  getRegExpForSearchTerm: ->
    searchTerm = @options.search
    source = _.escapeRegExp(searchTerm)
    if @options.wordOnly
      source = "\\b#{source}\\b"

    sensitivity = @getConfig('caseSensitivityForSearchTerm')
    if (sensitivity is 'sensitive') or (sensitivity is 'smartcase' and /[A-Z]/.test(searchTerm))
      new RegExp(source)
    else
      new RegExp(source, 'i')

  initialize: ->
    regexp = @getRegExpForSearchTerm()
    source = regexp.source
    if regexp.ignoreCase
      searchTerm = "(?i:#{source})"
    else
      searchTerm = source
    @ui.grammar.setSearchTerm(searchTerm)
