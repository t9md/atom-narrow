_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{requireFrom} = require '../utils'

TagGenerator = requireFrom('symbols-view', 'tag-generator')

module.exports =
class Symbols extends ProviderBase
  initialize: ->
    @subscribe @editor.onDidSave(@refresh.bind(this))

  refresh: ->
    @items = null # invalidate cache.
    @ui.refresh()

  getItems: ->
    if @items?
      @items
    else
      filePath = @editor.getPath()
      scopeName = @editor.getGrammar().scopeName
      new TagGenerator(filePath, scopeName).generate().then (tags) =>
        # We show full line text of symbol's line, so just care for which line have symbols.
        @items = []
        for {position} in _.uniq(tags, (tag) -> tag.position.row)
          @items.push(
            point: position
            text: @editor.lineTextForBufferRow(position.row)
          )
        @items

  viewForItem: ({text, point}) ->
    @getTextForRow(point.row) + ":" + text
