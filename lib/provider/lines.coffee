Base = require './base'
{padStringLeft} = require '../utils'
settings = require '../settings'

module.exports =
class Lines extends Base
  autoPreview: true

  initialize: ->
    @editor.onDidStopChanging =>
      @items = null # invalidate cache.
      @ui.refresh()

  useFuzzyFilter: ->
    settings.get('LinesUseFuzzyFilter')

  keepItemsOrderOnFuzzyFilter: ->
    settings.get('LinesKeepItemsOrderOnFuzzyFilter')

  getItems: ->
    return @items if @items?
    @items = []
    filePath = @editor.getPath()
    for line, i in @editor.getBuffer().getLines()
      point = [i, 0]
      text = line
      @items.push({filePath, point, text})
    @items

  viewForItem: (item) ->
    width = String(@editor.getLastBufferRow()).length
    row = item.point[0] + 1
    padStringLeft(String(row), width) + ':' + item.text
