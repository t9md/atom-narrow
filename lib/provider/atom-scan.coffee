{Point, Range} = require 'atom'
ProviderBase = require './provider-base'
SearchOptions = require '../search-options'

module.exports =
class AtomScan extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  useFirstQueryAsSearchTerm: true
  supportFilePathOnlyItemsUpdate: true

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
    @scanPromise = atom.workspace.scan @searchRegex, (result) =>
      if result?.matches?.length
        {filePath, matches} = result
        @updateItems matches.map (match) ->
          {
            filePath: filePath
            text: match.lineText
            point: Point.fromObject(match.range[0])
            range: Range.fromObject(match.range)
          }

    @scanPromise.then (message) =>
      # Relying on Atom's workspace.scan's specific implementation
      # `workspace.scan` return cancellable promise.
      # When cancelled, promise is NOT rejected, instead it's resolved with 'cancelled' message
      if message isnt 'cancelled'
        @scanPromise = null
        @finishUpdateItems()
      else
        console.log 'canceled'

  search: (filePath) ->
    if @scanPromise?
      @scanPromise.cancel()
      @scanPromise = null

    if filePath?
      if atom.project.contains(filePath)
        @scanFilePath(filePath).then (items) =>
          @finishUpdateItems(items)
      else
        # When non project file was saved. We have nothing todo, so just return old @items.
        @finishUpdateItems([])
    else
      @scanWorkspace()

  getItems: (filePath) ->
    @updateSearchState()
    if @searchRegex?
      @search().then (@items) =>
        @items
    else
      @finishUpdateItems([])
