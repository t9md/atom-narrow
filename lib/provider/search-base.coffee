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
  searchRegExp: null
  supportRangeHighlight: true
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

  toggleSearchWholeWord: ->
    super
    @resetRegExpForSearchTerm()

  toggleSearchIgnoreCase: ->
    super
    @resetRegExpForSearchTerm()

  resetRegExpForSearchTerm: ->
    @searchRegExp = @getRegExpForSearchTerm(@options.search, {@searchWholeWord, @searchIgnoreCase})
    @searchIgnoreCase ?= @searchRegExp.ignoreCase
    @ui.highlighter.setRegExp(@searchRegExp)
    @ui.grammar.setSearchTerm(@searchRegExp)

  initialize: ->
    @resetRegExpForSearchTerm()

  filterItems: (items, filterSpec) ->
    @getItemsWithoutUnusedHeader(super)
