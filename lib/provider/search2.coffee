{inspect} = require 'util'
p = (args...) -> console.log inspect(args...)

ProviderBase = require './provider-base'
{getProjectPaths, replaceOrAppendItemsForFilePath} = require '../utils'
Searcher = require '../searcher'

module.exports =
class Search2 extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  searchRegExp: null
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  querySelectedText: false
  searchTerm: null
  useRegex: false

  useFirstQueryAsSearchTerm: true

  getState: ->
    @mergeState(super, {@projects})

  checkReady: ->
    @projects ?= getProjectPaths(if @options.currentProject then @editor)

  searchFilePath: (filePath) ->
    command = @getConfig('searcher')
    args = @getSearchArgs(command)
    search({command, args, filePath}).then(@flattenSortAndSetRangeHint)

  getSearcher: ->
    command = @getConfig('searcher')
    new Searcher({command, @useRegex, @searchRegExp, @searchTerm})

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
    @updateSearchState()

    if @searchRegExp?
      @search(filePath).then (@items) =>
        @items
    else
      []
