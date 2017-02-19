_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{Disposable} = require 'atom'
{getCurrentWord, findFirstAndLastIndexBy} = require '../utils'

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
    @searchTerm = @options.search or editor.getSelectedText()
    if not @searchTerm and @options.searchCurrentWord
      @searchTerm = getCurrentWord(editor)
      @searchWholeWord = true

    @searchWholeWord ?= @getConfig('searchWholeWord')

    if @searchTerm
      Promise.resolve(true)
    else
      @readInput().then (@searchTerm) =>
        @searchTerm.length > 0

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

  filterItems: (items, filterSpec) ->
    @getItemsWithoutUnusedHeader(super)

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
