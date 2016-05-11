Base = require './base'

module.exports =
class Lines extends Base
  initialize: ->
    @editor.onDidStopChanging =>
      @items = null
      @narrow.refresh()

  getItems: ->
    return @items if @items?

    @items = []
    filePath = @editor.getPath()
    for line, i in @editor.getBuffer().getLines()
      item = {path: filePath, point: [i, 0], text: line}
      @items.push(item)
    @items

  viewForItem: (item) ->
    width = String(@editor.getLastBufferRow()).length
    row = item.point[0] + 1
    padding = " ".repeat(width - String(row).length + 1)
    padding + row + ':' + item.text
