_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{getCurrentWord, findFirstAndLastIndexBy} = require '../utils'
history = require '../input-history-manager'

lastIgnoreCaseOption = {}
readInput = require '../read-input'

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
  useRegex: false

  getState: ->
    @mergeState(super, {@useRegex})

  @useRegex: null
  getUseRegex: ->
    if @getConfig('rememberUseRegex')
      @constructor.useRegex ? @getConfig('useRegex')
    else
      @getConfig('useRegex')

  setUseRegex: (value) ->
    if @getConfig('rememberUseRegex')
      @constructor.useRegex = value

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
      readInput(@getUseRegex()).then ({text, useRegex}) =>
        # Validate regexp
        if useRegex
          try
            new RegExp(text)
          catch error
            console.warn "invalid regex pattern:", error
            return null

        @setUseRegex(useRegex)
        @searchTerm = text
        history.save(@searchTerm, useRegex)
        # Automatically switch to static search for faster range calcuration and good syntax highlight
        @useRegex = useRegex and _.escapeRegExp(text) isnt text

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
    if @useRegex
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
