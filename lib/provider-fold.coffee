_ = require 'underscore-plus'

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
class Fold
  constructor: (@narrow) ->
    @editor = atom.workspace.getActiveTextEditor()
    @editor.onDidStopChanging =>
      @items = null
      @narrow.refresh()

    @narrow.start(this)

  getFilterKey: ->
    "text"

  getItems: ->
    return @items if @items?
    @items = []
    startRows = getCodeFoldStartRowsAtIndentLevel(@editor, 2)
    rows = _.sortBy(_.uniq(startRows), (row) -> row)

    filePath = @editor.getPath()
    for row, i in rows
      item = {
        path: filePath
        point: [row, 0]
        text: @editor.lineTextForBufferRow(row)
      }
      @items.push(item)
    @items

  viewForItem: (item) ->
    width = String(@editor.getLastBufferRow()).length
    row = item.point[0] + 1
    padding = " ".repeat(width - String(row).length + 1)
    padding + row + ':' + item.text
