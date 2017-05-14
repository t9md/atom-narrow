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
    command = @getConfig('searcher')
    args = @getSearchArgs(command)
    search({command, args, filePath}).then(@flattenSortAndSetRangeHint)

  projectHeaderFor: (projectName) ->
    header = "# #{projectName}"
    {header, projectName, projectHeader: true, skip: true}

  filePathHeaderFor: (projectName, filePath) ->
    header = "## " + atom.project.relativize(filePath)
    {header, projectName, filePath, fileHeader: true, skip: true}

  search: (filePath) ->
    if filePath?
      # When non project file was saved. We have nothing todo, so just return old @items.
      return @items unless atom.project.contains(filePath)

      replaceOrApppend = replaceOrAppendItemsForFilePath.bind(this, @items, filePath)
      @searcher.searchFilePath(filePath).then(replaceOrApppend)
    else
      onItems = @updateItems

      finishCount = 0
      onFinish = =>
        finishCount++
        if finishCount is @projects.length
          @finishUpdateItems()

      for project in @projects
        @searcher.searchProject(project, onItems, onFinish)

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
      # if filePath?
      #   @search(filePath).then (@items) =>
      #     @ui.emitDidUpdateItems(@items)
      #     @ui.emitFinishUpdateItems()
      # else
      @search()
    else
      @finishUpdateItems([])
