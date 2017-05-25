ProviderBase = require './provider-base'
{getProjectPaths} = require '../utils'
Searcher = require '../searcher'
path = require 'path'
_ = require 'underscore-plus'

module.exports =
class Search extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  showProjectHeader: true
  showFileHeader: true
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  useFirstQueryAsSearchTerm: true
  supportFilePathOnlyItemsUpdate: true
  refreshOnDidStopChanging: true
  searchInOrdered: false # FIXME: This is set to true in spec to test easily

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
    modifiedBuffers = atom.project.getBuffers().filter (buffer) -> buffer.getPath()? and buffer.isModified()
    modifiedBuffersScanned = []

    scanBuffer = (buffer) =>
      return if buffer in modifiedBuffersScanned
      @updateItems(@scanItemsForBuffer(buffer, @searchOptions.searchRegex))
      modifiedBuffersScanned.push(buffer)

    finished = 0
    onFinish = (project) =>
      finished++
      # compare with dir separator appended to avoid partial match like 'atom' also matches atom-keymaps'.
      projectPathWithDirectorySeparator = project + path.sep
      for buffer in modifiedBuffers when buffer.getPath().startsWith(projectPathWithDirectorySeparator)
        scanBuffer(buffer)

      if projects.length
        searchNextProject()
      else
        if finished is @projects.length
          scanBuffer(buffer) for buffer in modifiedBuffers
          @finishUpdateItems()

    searchNextProject = =>
      @searcher.searchProject(projects.shift(), @updateItemsIfNotModified, onFinish)

    if @searchInOrdered
      searchNextProject()
    else
      searchNextProject() while projects.length

  updateItemsIfNotModified: (items) =>
    items = items.filter (item) -> not atom.project.isPathModified(item.filePath)
    @updateItems(items)

  updateItems: (items) =>
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
