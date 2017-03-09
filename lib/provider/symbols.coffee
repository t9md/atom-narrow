_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{requireFrom} = require '../utils'

TagGenerator = requireFrom('symbols-view', 'tag-generator')

# Symbols provider depending on ctag via TagGenerator.
# Which read tag info from file on disk.
# So we cant update symbol unless it's saved on disk.
# This is very exceptional provider not supportCacheItems in spite of boundToSingleFile.

module.exports =
class Symbols extends ProviderBase
  boundToSingleFile: true
  showLineHeader: false
  queryWordBoundaryOnByCurrentWordInvocation: true
  items: null

  onBindEditor: ({newEditor}) ->
    @items = null
    @subscribeEditor(newEditor.onDidSave => @items = null)

  itemForTag: ({position, name}) =>
    row = position.row
    {
      point: @getFirstCharacterPointOfRow(row)
      text: '  '.repeat(@getLevelForRow(row)) + name
    }

  getLevelForRow: (row) ->
    # For gfm source, determine level by counting leading '#' chars( use header level ).
    if @editor.getGrammar().scopeName in ['source.gfm', 'text.md']
      lineText = @editor.lineTextForBufferRow(row)
      (lineText.match(/#+/)?[0]?.length - 1) ? 0
    else
      @editor.indentationForBufferRow(row)

  getItems: ->
    return @items if @items?
    # We show full line text of symbol's line, so just care for which line have symbol.
    filePath = @editor.getPath()
    scopeName = @editor.getGrammar().scopeName
    new TagGenerator(filePath, scopeName).generate().then (tags) =>
      tags = _.uniq(tags, (tag) -> tag.position.row)
      @items = tags.map(@itemForTag.bind(this))
