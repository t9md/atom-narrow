_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{Disposable} = require 'atom'
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

    Promise.resolve(@searchTerm ? @readInput()).then (@searchTerm) =>
      history.save(@searchTerm)
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

  resetRegExpForSearchTerm: ->
    @searchRegExp = @getRegExpForSearchTerm(@searchTerm, {@searchWholeWord, @searchIgnoreCase})
    @ui.highlighter.setRegExp(@searchRegExp)
    @ui.grammar.setSearchTerm(@searchRegExp)

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
