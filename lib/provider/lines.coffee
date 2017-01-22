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
