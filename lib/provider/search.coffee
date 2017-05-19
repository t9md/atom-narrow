ProviderBase = require './provider-base'
{getProjectPaths, replaceOrAppendItemsForFilePath} = require '../utils'
Searcher = require '../searcher'
SearchOptions = require '../search-options'
path = require 'path'
_ = require 'underscore-plus'

module.exports =
class Search extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  useFirstQueryAsSearchTerm: true
  supportFilePathOnlyItemsUpdate: true

  getState: ->
    @mergeState(super, {@projects})

  checkReady: ->
    return true if @reopened
    @projects ?= getProjectPaths(if @options.currentProject then @editor)

  initialize: ->
    @initializeSearchOptions() unless @reopened
    @searchOptions = new SearchOptions()
    @searcher = new Searcher(@searchOptions)

  searchFilePath: (filePath) ->
    if atom.project.contains(filePath)
      @searcher.searchFilePath(filePath, @updateItems, @finishUpdateItems)
    else
      # When non project file was saved. We have nothing todo, so just return old @items.
      @finishUpdateItems([])

  search: ->
    finishCount = 0
    onFinish = =>
      if (++finishCount) is @projects.length
        @finishUpdateItems()

    for project in @projects
      @searcher.searchProject(project, @updateItems, onFinish)

  destroy: ->
    @searcher.cancel()
    @searcher = null
    super

  getItems: (filePath) ->
    @searcher.cancel()
    @updateSearchState()
    @searchOptions.set({@searchUseRegex, @searchRegex, @searchTerm})
    @searcher.setCommand(@getConfig('searcher'))
    @ui.grammar.update()

    if @searchRegex?
      if filePath
        @searchFilePath(filePath)
      else
        @search()
    else
      @finishUpdateItems([])
