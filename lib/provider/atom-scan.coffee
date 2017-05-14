{Point, Range} = require 'atom'
ProviderBase = require './provider-base'
{replaceOrAppendItemsForFilePath} = require '../utils'
SearchOptions = require '../search-options'

module.exports =
class AtomScan extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  useFirstQueryAsSearchTerm: true

  initialize: ->
    @initializeSearchOptions() unless @reopened
    @searchOptions = new SearchOptions()

  # Not used but keep it since I'm planning to introduce per file refresh on modification
  scanFilePath: (filePath) ->
    items = []
    atom.workspace.open(filePath, activateItem: false).then (editor) =>
      editor.scan @searchRegex, ({range}) ->
        items.push({
          filePath: filePath
          text: editor.lineTextForBufferRow(range.start.row)
          point: range.start
          range: range
        })
      items

  scanWorkspace: ->
    itemFound = false
    scanPromise = atom.workspace.scan @searchRegex, (result) =>
      if result?.matches?.length
        itemFound = true
        {filePath, matches} = result
        @updateItems matches.map (match) ->
          {
            filePath: filePath
            text: match.lineText
            point: Point.fromObject(match.range[0])
            range: Range.fromObject(match.range)
          }

    scanPromise.then =>
      @finishUpdateItems([] unless itemFound)

  search: (filePath) ->
    if filePath?
      # When non project file was saved. We have nothing todo, so just return old @items.
      return @items unless atom.project.contains(filePath)

      replaceOrApppend = replaceOrAppendItemsForFilePath.bind(this, @items, filePath)
      @scanFilePath(filePath).then(replaceOrApppend)
    else
      @scanWorkspace()

  getItems: (filePath) ->
    @updateSearchState()
    if @searchRegex?
      @search().then (@items) =>
        @items
    else
      @finishUpdateItems([])
