{Point, Range} = require 'atom'
{cloneRegExp} = require '../utils'
ProviderBase = require './provider-base'
SearchOptions = require '../search-options'

module.exports =
class Scan extends ProviderBase
  boundToSingleFile: true
  supportDirectEdit: true
  showColumnOnLineHeader: true
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  useFirstQueryAsSearchTerm: true

  scanEditor: (regExp) ->
    items = []
    regExp = cloneRegExp(regExp)
    for lineText, row in @editor.buffer.getLines()
      regExp.lastIndex = 0
      while match = regExp.exec(lineText)
        range = new Range([row, match.index], [row, match.index + match[0].length])
        items.push(text: lineText, point: range.start, range: range)
        # Avoid infinite loop in zero length match when regExp is /^/
        break unless match[0]
    items

  getItems: ->
    @updateSearchState()
    {searchRegex} = @searchOptions
    if searchRegex?
      items = @scanEditor(searchRegex)
    else
      items = @editor.buffer.getLines().map (text, row) ->
        point = new Point(row, 0)
        {text, point, range: new Range(point, point)}

    @finishUpdateItems(items)
