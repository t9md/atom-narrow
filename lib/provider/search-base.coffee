_ = require 'underscore-plus'

ProviderBase = require './provider-base'
Input = null
{getCurrentWord, findFirstAndLastIndexBy} = require '../utils'
history = require '../input-history-manager'

lastIgnoreCaseOption = {}

module.exports =
class SearchBase extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  searchRegExp: null
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  querySelectedText: false
  searchTerm: null
  isRegExpSearch: false

  getState: ->
    @mergeState(super, {@isRegExpSearch})

  @useReglarExpressionSearch: null
  getUseReglarExpressionSearch: ->
    if @getConfig('rememberUseReglarExpressionSearch')
      @constructor.useReglarExpressionSearch ? @getConfig('useReglarExpressionSearch')
    else
      @getConfig('useReglarExpressionSearch')

  setUseReglarExpressionSearch: (value) ->
    if @getConfig('rememberUseReglarExpressionSearch')
      @constructor.useReglarExpressionSearch = value

  getSearchTerm: ->
    if @options.search
      return @options.search

    editor = atom.workspace.getActiveTextEditor()
    if text = editor.getSelectedText()
      return text

    if @options.searchCurrentWord
      @searchWholeWord = true
      getCurrentWord(editor)

  checkReady: ->
    if @reopened
      return Promise.resolve(true)

    @searchTerm = @getSearchTerm()
    @searchWholeWord ?= @getConfig('searchWholeWord')

    if @options.searchCurrentWord
      if @getConfig('rememberIgnoreCaseForByCurrentWordSearch')
        @searchIgnoreCase = lastIgnoreCaseOption.byCurrentWord
    else
      if @getConfig('rememberIgnoreCaseForByHandSearch')
        @searchIgnoreCase = lastIgnoreCaseOption.byHand

    if @searchTerm?
      Promise.resolve(@searchTerm).then =>
        history.save(@searchTerm, false)
        @searchIgnoreCase ?= @getIgnoreCaseValueForSearchTerm(@searchTerm)
        return @searchTerm
    else
      Input ?= require '../input'
      new Input().readInput(@getUseReglarExpressionSearch()).then ({text, isRegExp}) =>
        @setUseReglarExpressionSearch(isRegExp)
        @searchTerm = text
        history.save(@searchTerm, isRegExp)
        # Automatically switch to static search for faster range calcuration and good syntax highlight
        @isRegExpSearch = isRegExp and _.escapeRegExp(text) isnt text

        @searchIgnoreCase ?= @getIgnoreCaseValueForSearchTerm(@searchTerm)
        return @searchTerm

  destroy: ->
    if @reopened
      return super

    if @options.searchCurrentWord
      if @getConfig('rememberIgnoreCaseForByCurrentWordSearch')
        lastIgnoreCaseOption.byCurrentWord = @searchIgnoreCase
    else
      if @getConfig('rememberIgnoreCaseForByHandSearch')
        lastIgnoreCaseOption.byHand = @searchIgnoreCase
    super

  initialize: ->
    @resetRegExpForSearchTerm()
    @initiallySearchedRegexp = @searchRegExp

  resetRegExpForSearchTerm: ->
    if @isRegExpSearch
      flags = 'g'
      flags += 'i' if @searchIgnoreCase
      expression = @searchTerm
      if @searchWholeWord
        expression = "\\b#{@searchTerm}\\b"
      @searchRegExp = new RegExp(expression, flags)
    else
      @searchRegExp = @getRegExpForSearchTerm(@searchTerm, {@searchWholeWord, @searchIgnoreCase})
      @ui.grammar.setSearchTerm(@searchRegExp)

    @ui.highlighter.setRegExp(@searchRegExp)
    @ui.controlBar.updateSearchTermElement(@searchRegExp)

  toggleSearchWholeWord: ->
    super
    @resetRegExpForSearchTerm()

  toggleSearchIgnoreCase: ->
    super
    @resetRegExpForSearchTerm()

  # If passed items have filePath's item, replace old items with new items.
  # If passed items have no filePath's item, append to end.
  replaceOrAppendItemsForFilePath: (items, filePath, newItems) ->
    amountOfRemove = 0
    indexToInsert = items.length - 1

    [firstIndex, lastIndex] = findFirstAndLastIndexBy(items, (item) -> item.filePath is filePath)
    if firstIndex? and lastIndex?
      indexToInsert = firstIndex
      amountOfRemove = lastIndex - firstIndex + 1

    items.splice(indexToInsert, amountOfRemove, newItems...)
    items
