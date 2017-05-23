{Point, Range} = require 'atom'
{cloneRegExp} = require '../utils'
ProviderBase = require './provider-base'

module.exports =
class Scan extends ProviderBase
  boundToSingleFile: true
  supportDirectEdit: true
  showColumnOnLineHeader: true
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  useFirstQueryAsSearchTerm: true
  refreshOnDidStopChanging: true

  getItems: ->
    @updateSearchState()
    {searchRegex} = @searchOptions
    if searchRegex?
      items = @scanItemsForBuffer(@editor.buffer, searchRegex)
    else
      items = @editor.buffer.getLines().map (text, row) ->
        point = new Point(row, 0)
        {text, point, range: new Range(point, point)}

    @finishUpdateItems(items)
