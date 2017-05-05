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
  useFirstQueryAsSearchTerm: true
  supportCacheItems: true

  initialize: ->
    return if @reopened

    editor = atom.workspace.getActiveTextEditor()
    if @options.queryCurrentWord and editor.getSelectedBufferRange().isEmpty()
      @searchWholeWord = true
    else
      @searchWholeWord = @getConfig('searchWholeWord')

  scanEditor: (regExp) ->
    items = []
    regExp = cloneRegExp(regExp)
    for lineText, row in @editor.buffer.getLines()
      regExp.lastIndex = 0
      while match = regExp.exec(lineText)
        range = new Range([row, match.index], [row, match.index + match[0].length])
        items.push(text: lineText, point: range.start, range: range)
    items

  getItems: ->
    @updateSearchState()
    if @searchRegExp?
      @scanEditor(@searchRegExp)
    else
      @editor.buffer.getLines().map (text, row) ->
        point = new Point(row, 0)
        {text, point, range: new Range(point, point)}
