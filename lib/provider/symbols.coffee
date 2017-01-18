_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{requireFrom} = require '../utils'

TagGenerator = requireFrom('symbols-view', 'tag-generator')

module.exports =
class Symbols extends ProviderBase
  initialize: ->
    @subscribe @editor.onDidSave(@refresh)

  refresh: =>
    @items = null # invalidate cache.
    @ui.refresh()

  getItems: ->
    if @items?
      @items
    else
      new TagGenerator(@editor.getPath(), @editor.getGrammar().scopeName).generate().then (tags) =>
        # We show full line text of symbol's line, so just care for which line have symbols.
        tags = _.uniq(tags, (tag) -> tag.position.row)
        @items = tags.map ({position}) =>
          point: position
          text: @editor.lineTextForBufferRow(position.row)

  viewForItem: ({text, point}) ->
    @getLineNumberText(point.row) + ":" + text
