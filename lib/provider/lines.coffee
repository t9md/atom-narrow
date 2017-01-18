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
    @items ?= ({point: new Point(i, 0), text} for text, i in @editor.getBuffer().getLines())

  viewForItem: ({text, point}) ->
    @getLineNumberText(point.row) + ":" + text
