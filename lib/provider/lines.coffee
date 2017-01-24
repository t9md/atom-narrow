_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{Point} = require 'atom'
settings = require '../settings'

module.exports =
class Lines extends ProviderBase
  boundToEditor: true
  supportDirectEdit: true

  getItems: ->
    return @items if @items?

    @items = @editor.buffer.getLines().map (text, i) ->
      point: new Point(i, 0)
      text: text

  filterItems: (items, regexps) ->
    @regexps = regexps
    super(items, regexps)

  adjustPoint: (point) ->
    return null if @regexps.length is 0

    scanRange = @editor.bufferRangeForBufferRow(point.row)
    points = []
    for regexp in @regexps
      @editor.scanInBufferRange regexp, scanRange, ({range}) ->
        points.push(range.start)

    return _.min(points, (point) -> point.column)
