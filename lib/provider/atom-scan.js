{Point, Range} = require 'atom'
ProviderBase = require './provider-base'
SearchOptions = require '../search-options'

module.exports =
class AtomScan extends ProviderBase
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

  scanWorkspace: ->
    @scanPromise = atom.workspace.scan @searchOptions.searchRegex, (result) =>
      if result?.matches?.length
        {filePath, matches} = result
        @updateItems matches.map (match) ->
          range = Range.fromObject(match.range)
          {
            filePath: filePath
            text: match.lineText
            point: range.start
            range: range
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

  search: (event) ->
    if @scanPromise?
      @scanPromise.cancel()
      @scanPromise = null

    {filePath} = event

    if filePath?
      if atom.project.contains(filePath)
        @scanItemsForFilePath(filePath, @searchOptions.searchRegex).then (items) =>
          @finishUpdateItems(items)
      else
        # When non project file was saved. We have nothing todo, so just return old @items.
        @finishUpdateItems([])
    else
      @scanWorkspace()

  getItems: (event) ->
    @updateSearchState()
    if @searchOptions.searchRegex?
      @search(event)
    else
      @finishUpdateItems([])
