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

  checkReady: ->
    editor = atom.workspace.getActiveTextEditor()
    @searchTerm ?= @options.search or editor.getSelectedText()
    if not @searchTerm and @options.searchCurrentWord
      @searchTerm = getCurrentWord(editor)
      @searchWholeWord = true

    @searchWholeWord ?= @getConfig('searchWholeWord')
    unless @reopened
      if @options.searchCurrentWord
        if @getConfig('rememberIgnoreCaseForByCurrentWordSearch')
          @searchIgnoreCase = lastIgnoreCaseOption.byCurrentWord
      else
        if @getConfig('rememberIgnoreCaseForByHandSearch')
          @searchIgnoreCase = lastIgnoreCaseOption.byHand

    if @searchTerm
      history.save(@searchTerm)
      Promise.resolve(true)
    else
      @readInput().then (@searchTerm) =>
        history.save(@searchTerm)
        @searchTerm.length > 0

  destroy: ->
    unless @reopened
      if @options.searchCurrentWord
        if @getConfig('rememberIgnoreCaseForByCurrentWordSearch')
          lastIgnoreCaseOption.byCurrentWord = @searchIgnoreCase
      else
        if @getConfig('rememberIgnoreCaseForByHandSearch')
          lastIgnoreCaseOption.byHand = @searchIgnoreCase
    super

  toggleSearchWholeWord: ->
    super
    @resetRegExpForSearchTerm()

  toggleSearchIgnoreCase: ->
    super
    @resetRegExpForSearchTerm()

  resetRegExpForSearchTerm: ->
    @searchRegExp = @getRegExpForSearchTerm(@searchTerm, {@searchWholeWord, @searchIgnoreCase})
    @searchIgnoreCase ?= @searchRegExp.ignoreCase
    @ui.highlighter.setRegExp(@searchRegExp)
    @ui.grammar.setSearchTerm(@searchRegExp)

  initialize: ->
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
