_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{requireFrom} = require '../utils'

TagGenerator = requireFrom('symbols-view', 'tag-generator')

module.exports =
class Symbols extends ProviderBase
  boundToEditor: true

  getItems: ->
    if @items?
      @items
    else
      # We show full line text of symbol's line, so just care for which line have symbol.
      filePath = @editor.getPath()
      scopeName = @editor.getGrammar().scopeName
      new TagGenerator(filePath, scopeName).generate().then (tags) =>
        tags = _.uniq(tags, (tag) -> tag.position.row)
        @items = tags.map ({position}) =>
          point: position
          text: @editor.lineTextForBufferRow(position.row)

  viewForItem: ({text}) ->
    text
