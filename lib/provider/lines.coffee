ProviderBase = require './provider-base'
{Point} = require 'atom'

module.exports =
class Lines extends ProviderBase
  boundToEditor: true
  supportDirectEdit: true

  getItems: ->
    @items ?= @editor.buffer.getLines().map (text, i) ->
      point: new Point(i, 0)
      text: text

  trimRowPart: (text) ->
    rowPartLength = @textWidthForLastRow + 1
    text[rowPartLength...]

  updateRealFile: (states) ->
    changes = @getChangeSet(states)
    return unless changes.length
    for {row, text} in changes
      range = @editor.bufferRangeForBufferRow(row)
      @editor.setTextInBufferRange(range, text)

  getChangeSet: (states) ->
    changes = []
    filePath = @editor.getPath()
    for state in states
      {row, text, item} = state
      newText = @trimRowPart(text)
      if newText isnt item.text
        changes.push({row, text: newText})
    changes

  viewForItem: ({text, point}) ->
    @getLineNumberText(point.row) + ":" + text
