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

  getRowHeaderForItem: ({point}) ->
    @getLineNumberText(point.row) + ":"

  viewForItem: (item) ->
    @getRowHeaderForItem(item) + item.text

  updateRealFile: (states) ->
    changes = @getChangeSet(states)
    for {row, text} in changes
      range = @editor.bufferRangeForBufferRow(row)
      @editor.setTextInBufferRange(range, text)

  getChangeSet: (states) ->
    changes = []
    for {row, text, item} in states
      newText = text[@getRowHeaderForItem(item).length...]
      if newText isnt item.text
        changes.push({row, text: newText})
    changes
