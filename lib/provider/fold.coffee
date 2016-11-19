_ = require 'underscore-plus'
Base = require './base'
settings = require '../settings'

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
    newFoldLevel = @foldLevel + relativeLevel
    @foldLevel = Math.max(0, newFoldLevel)
    @refresh()

  getItems: ->
    if @items?
      @items
    else
      @items = []
      startRows = getCodeFoldStartRowsAtIndentLevel(@editor, @foldLevel)
      rows = _.sortBy(_.uniq(startRows), (row) -> row)
      filePath = @editor.getPath()
      for row, i in rows
        item = {filePath, point: [row, 0], text: @editor.lineTextForBufferRow(row)}
        @items.push(item)
      @items

  viewForItem: ({text}) ->
    text
