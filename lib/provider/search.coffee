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
  searchInOrdered: false # This is set to true in spec to test easily

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
    projects = @projects.slice()
    modifiedBuffers = atom.project.getBuffers().filter (buffer) -> buffer.isModified()
    modifiedBuffersScanned = []

    scanBuffer = (buffer) =>
      return if buffer in modifiedBuffersScanned
      @updateItems(@scanItemsForBuffer(buffer, @searchOptions.searchRegex))
      modifiedBuffersScanned.push(buffer)

    onFinish = (project) =>
      dir = atom.project.getDirectoryForProjectPath(project)
      for buffer in modifiedBuffers when dir.contains(buffer.getPath())
        scanBuffer(buffer)

      if projects.length
        searchNextProject()
      else
        scanBuffer(buffer) for buffer in modifiedBuffers
        @finishUpdateItems()

    searchNextProject = =>
      @searcher.searchProject(projects.shift(), @updateItems, onFinish)

    if @searchInOrdered
      searchNextProject()
    else
      searchNextProject() while projects.length

  updateItems: (items) ->
    items = items.filter (item) -> not atom.project.isPathModified(item.filePath)
    if @searchInOrdered
      items = _.sortBy(items, (item) -> item.filePath)
    super(items)

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
