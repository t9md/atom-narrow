SearchBase = require './search-base'
Searcher = require '../searcher'
{getProjectPaths, replaceOrAppendItemsForFilePath} = require '../utils'

module.exports =
class Search extends SearchBase
  getState: ->
    @mergeState(super, {@projects})

  checkReady: ->
    if @projects ?= getProjectPaths(if @options.currentProject then @editor)
      super

  getSearcher: ->
    command = @getConfig('searcher')
    searchUseRegex = @useRegex
    new Searcher({command, searchUseRegex, @searchRegex, @searchTerm})

  search: (filePath) ->
    # When non project file was saved. We have nothing todo, so just return old @items.
    if filePath? and not atom.project.contains(filePath)
      return @items

    if filePath?
      replaceOrApppend = replaceOrAppendItemsForFilePath.bind(this, @items, filePath)
      @getSearcher().searchFilePath(filePath).then(replaceOrApppend)
    else
      @getSearcher().searchProjects(@projects)

  getItems: (filePath) ->
    @search(filePath).then (@items) =>
      @items
