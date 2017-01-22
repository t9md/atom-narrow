_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{Point} = require 'atom'
settings = require '../settings'

module.exports =
class Lines extends ProviderBase
  boundToEditor: true
  supportDirectEdit: true

  getItems: ->
    @items ?= @editor.buffer.getLines().map (text, i) ->
      point: new Point(i, 0)
      text: text

  getRowHeaderForItem: ({point}) ->
    @getLineNumberText(point.row) + ":"

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

  viewForItem: (item) ->
    @getRowHeaderForItem(item) + item.text

  updateRealFile: (states) ->
    changes = @getChangeSet(states)
    @editor.transact =>
      for {row, text} in changes
        range = @editor.bufferRangeForBufferRow(row)
        @editor.setTextInBufferRange(range, text)
    if settings.get('LinesSaveAfterDirectEdit')
      @editor.save()

  getChangeSet: (states) ->
    changes = []
    for {newText, item} in states
      {text, point} = item
      newText = newText[@getRowHeaderForItem(item).length...]
      if newText isnt text
        changes.push({row: point.row, text: newText})
    changes
