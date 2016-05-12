_ = require 'underscore-plus'
Base = require './base'

getCodeFoldStartRowsAtIndentLevel = (editor, indentLevel) ->
  rows = [0..editor.getLastBufferRow()]
  rows.map (row) ->
    editor.languageMode.rowRangeForCodeFoldAtBufferRow(row)
  .filter (rowRange) ->
    (rowRange? and rowRange[0]? and rowRange[1]?)
  .map ([startRow, endRow]) ->
    startRow
  .filter (startRow) ->
    editor.indentationForBufferRow(startRow) < indentLevel

module.exports =
class Fold extends Base
  autoReveal: true
  
  initialize: ->
    @editor.onDidStopChanging =>
      @items = null # invalidate cache
      @narrow.refresh()

  getItems: ->
    return @items if @items?

    @items = []
    startRows = getCodeFoldStartRowsAtIndentLevel(@editor, 2)
    rows = _.sortBy(_.uniq(startRows), (row) -> row)
    filePath = @editor.getPath()
    for row, i in rows
      item = {filePath, point: [row, 0], text: @editor.lineTextForBufferRow(row)}
      @items.push(item)
    @items

  viewForItem: (item) ->
    "  " + item.text
