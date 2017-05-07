{inspect} = require 'util'
p = (args...) -> console.log inspect(args...)

ProviderBase = require './provider-base'
{getProjectPaths, replaceOrAppendItemsForFilePath} = require '../utils'
Searcher = require '../searcher'

module.exports =
class Search extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  searchRegex: null
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  querySelectedText: false
  searchTerm: null
  useFirstQueryAsSearchTerm: true

  getState: ->
    @mergeState(super, {@projects})

  checkReady: ->
    return true if @reopened
    @projects ?= getProjectPaths(if @options.currentProject then @editor)

  initialize: ->
    editor = atom.workspace.getActiveTextEditor()
    if @options.queryCurrentWord and editor.getSelectedBufferRange().isEmpty()
      @searchWholeWord = true
    else
      @searchWholeWord = @getConfig('searchWholeWord')
    @searchUseRegex = @getConfig('searchUseRegex')

  searchFilePath: (filePath) ->
    command = @getConfig('searcher')
    args = @getSearchArgs(command)
    search({command, args, filePath}).then(@flattenSortAndSetRangeHint)

  getSearcher: ->
    command = @getConfig('searcher')
    new Searcher({command, @searchUseRegex, @searchRegex, @searchTerm})

  search: (filePath) ->
    if filePath?
      # When non project file was saved. We have nothing todo, so just return old @items.
      return @items unless atom.project.contains(filePath)

      replaceOrApppend = replaceOrAppendItemsForFilePath.bind(this, @items, filePath)
      @getSearcher().searchFilePath(filePath).then(replaceOrApppend)
    else
      @getSearcher().searchProjects(@projects)

  getItems: (filePath) ->
    @updateSearchState()

    if @searchRegex?
      @search().then (@items) =>
        @items
    else
      []
