Base = require './base'
{Point} = require 'atom'
{padStringLeft} = require '../utils'
settings = require '../settings'

module.exports =
class Lines extends Base
  initialize: ->
    @subscribe @editor.onDidStopChanging(@refresh.bind(this))

  refresh: ->
    [@items, @width] = []  # invalidate cache.
    @ui.refresh()

  getItems: ->
    if @items?
      @items
    else
      filePath = @editor.getPath()
      @items = @editor.getBuffer().getLines().map (text, i) ->
        {filePath, point: new Point(i, 0), text}

  viewForItem: (item) ->
    @width ?= String(@editor.getLastBufferRow()).length
    padString = padStringLeft(String(item.point.row + 1), @width)
    "#{padString}:#{item.text}"
