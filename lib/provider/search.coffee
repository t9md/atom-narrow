ProviderBase = require './provider-base'
{getProjectPaths, replaceOrAppendItemsForFilePath} = require '../utils'
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

  getState: ->
    @mergeState(super, {@projects})

  checkReady: ->
    return true if @reopened
    @projects ?= getProjectPaths(if @options.currentProject then @editor)

  initialize: ->
    @initializeSearchOptions() unless @reopened
    @searcher = new Searcher()

  searchFilePath: (filePath) ->
    command = @getConfig('searcher')
    args = @getSearchArgs(command)
    search({command, args, filePath}).then(@flattenSortAndSetRangeHint)

  getSearcherOptions: ->
    command = @getConfig('searcher')
    {command, @searchUseRegex, @searchRegex, @searchTerm}

  projectHeaderFor: (projectName) ->
    header = "# #{projectName}"
    {header, projectName, projectHeader: true, skip: true}

  filePathHeaderFor: (projectName, filePath) ->
    header = "## " + atom.project.relativize(filePath)
    {header, projectName, filePath, fileHeader: true, skip: true}

  search: (filePath) ->
    @searcher.cancel()
    @searcher.setOptions(@getSearcherOptions())

    if filePath?
      # When non project file was saved. We have nothing todo, so just return old @items.
      return @items unless atom.project.contains(filePath)

      replaceOrApppend = replaceOrAppendItemsForFilePath.bind(this, @items, filePath)
      @searcher.searchFilePath(filePath).then(replaceOrApppend)
    else
      projectNameSeen = {}
      filePathSeen = {}
      previousPoint = null
      onItems = (newItems, project) =>
        updateItemCount = false

        items = []
        projectName = path.basename(project)

        if projectName not of projectNameSeen
          items.push(@projectHeaderFor(projectName))
          projectNameSeen[projectName] = true

        for item in newItems when filePath = item.filePath
          if filePath not of filePathSeen
            updateItemCount = true
            items.push(@filePathHeaderFor(projectName, filePath))
            filePathSeen[filePath] = true

          item.projectName = projectName # inject
          items.push(item)

        # if updateItemC
        if updateItemCount
          setImmediate =>
            @ui.controlBar.updateElements(itemCount: @ui.items.getCount())
        @ui.emitDidUpdateItems(items)

      finishCount = 0
      onFinish = =>
        finishCount++
        if finishCount is @projects.length
          @ui.emitFinishUpdateItems()

      for project in @projects
        @searcher.searchProject(project, onItems, onFinish)

  getItems: (filePath) ->
    @updateSearchState()
    @ui.grammar.update()

    if @searchRegex?
      if filePath?
        @search(filePath).then (@items) =>
          @ui.emitDidUpdateItems(@items)
          @ui.emitFinishUpdateItems()
      else
      @search()
    else
      @ui.emitDidUpdateItems([])
      @ui.emitFinishUpdateItems()

  requestItems: (event) ->
    {filePath} = event
    @getItems()
