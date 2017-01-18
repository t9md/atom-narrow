_ = require 'underscore-plus'
Base = require './base'
{Point} = require 'atom'

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
  foldLevel: 2

  initialize: ->
    @subscribe @editor.onDidStopChanging(@refresh.bind(this))
    @registerCommands()

  registerCommands: ->
    atom.commands.add @ui.narrowEditorElement,
      'narrow-ui:fold:increase-fold-level': => @updateFoldLevel(+1)
      'narrow-ui:fold:decrease-fold-level': => @updateFoldLevel(-1)

  refresh: ->
    @items = null # invalidate cache
    @ui.refresh()

  updateFoldLevel: (relativeLevel) ->
    @foldLevel = Math.max(0, @foldLevel + relativeLevel)
    @refresh()

  getItems: ->
    if @items?
      @items
    else
      startRows = getCodeFoldStartRowsAtIndentLevel(@editor, @foldLevel)
      filePath = @editor.getPath()
      rows = _.sortBy(_.uniq(startRows), (row) -> row)
      @items = rows.map (row) =>
        {filePath, point: new Point(row, 0), text: @editor.lineTextForBufferRow(row)}

  viewForItem: ({text}) ->
    text
