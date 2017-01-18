ProviderBase = require './provider-base'
{Point} = require 'atom'

module.exports =
class Lines extends ProviderBase
  initialize: ->
    @subscribe @editor.onDidStopChanging(@refresh)

  refresh: =>
    @items = null
    @ui.refresh()

  getItems: ->
    @items ?= @editor.buffer.getLines().map (text, i) ->
      point: new Point(i, 0)
      text: text

  viewForItem: ({text, point}) ->
    @getLineNumberText(point.row) + ":" + text
