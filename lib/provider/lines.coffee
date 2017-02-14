_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{Point} = require 'atom'

module.exports =
class Lines extends ProviderBase
  boundToSingleFile: true
  supportDirectEdit: true
  supportCacheItems: true
  showLineHeader: true

  getItems: ->
    @editor.buffer.getLines().map (text, row) ->
      point: new Point(row, 0)
      text: text

  filterItems: (items, filterSpec) ->
    @regexps = filterSpec.include
    super

  adjustPoint: (point) ->
    return null if @regexps.length is 0

    scanRange = @editor.bufferRangeForBufferRow(point.row)
    points = []
    for regexp in @regexps
      @editor.scanInBufferRange regexp, scanRange, ({range}) ->
        points.push(range.start)

    return _.min(points, (point) -> point.column)
