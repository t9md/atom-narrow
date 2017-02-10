_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{Disposable} = require 'atom'
{getCurrentWord} = require '../utils'

module.exports =
class SearchBase extends ProviderBase
  ignoreSideMovementOnSyncToEditor: false

  includeHeaderGrammar: true
  supportDirectEdit: true
  showLineHeader: true
  showColumnOnLineHeader: true
  regExpForSearchTerm: null
  useHighlighter: true
  showSearchOption: true

  checkReady: ->
    if @options.currentWord
      @options.search = getCurrentWord(@editor)

      if @editor.getSelectedBufferRange().isEmpty()
        @searchWholeWord = true

    @searchWholeWord ?= @getConfig('searchWholeWord')

    if @options.search
      Promise.resolve(true)
    else
      @readInput().then (input) =>
        @options.search = input
        true

  toggleSearchWholeWord: ->
    super
    @resetRegExpForSearchTerm()

  toggleSearchIgnoreCase: ->
    super
    @resetRegExpForSearchTerm()

  resetRegExpForSearchTerm: ->
    source = _.escapeRegExp(@options.search)
    @regExpForSearchTerm = @getRegExpForSearchSource(source, @searchIgnoreCase)
    @searchIgnoreCase ?= @regExpForSearchTerm.ignoreCase
    @ui.highlighter.setRegExp(@regExpForSearchTerm)
    @ui.grammar.setSearchTerm(@regExpForSearchTerm)

  initialize: ->
    @resetRegExpForSearchTerm()

  filterItems: (items, filterSpec) ->
    @getItemsWithoutNoItemHeader(super)
