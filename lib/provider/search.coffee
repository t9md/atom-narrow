ProviderBase = require './provider-base'
{getProjectPaths} = require '../utils'
Searcher = require '../searcher'
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
  refreshOnDidStopChanging: true

  getState: ->
    @mergeState(super, {@projects})

  checkReady: ->
    return true if @reopened
    @projects ?= getProjectPaths(if @options.currentProject then @editor)

  initialize: ->
    @searcher = new Searcher(@searchOptions)

  searchFilePath: (filePath) ->
    if atom.project.contains(filePath)
      @scanItemsForFilePath(filePath, @searchOptions.searchRegex).then (items) =>
        @finishUpdateItems(items)
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

  searchInOrder: ->
    projects = @projects.slice()
    onItems = (items) =>
      items = _.sortBy(items, (item) -> item.filePath)
      @updateItems(items)

    searchNextProject = =>
      @searcher.searchProject(projects.shift(), onItems, onFinish)

    onFinish = =>
      if projects.length
        searchNextProject()
      else
        @finishUpdateItems()

    searchNextProject()

  destroy: ->
    @searcher.cancel()
    @searcher = null
    super

  getItems: (event) ->
    @searcher.cancel()
    @updateSearchState()
    @searcher.setCommand(@getConfig('searcher'))
    @ui.grammar.update()

    if @searchOptions.searchRegex?
      if event.filePath?
        @searchFilePath(event.filePath)
      else
        @search()
    else
      @finishUpdateItems([])
