_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{Point} = require 'atom'

getCodeFoldStartRows = (editor, indentLevel) ->
  [0..editor.getLastBufferRow()].map (row) ->
    editor.languageMode.rowRangeForCodeFoldAtBufferRow(row)
  .filter (rowRange) ->
    (rowRange? and rowRange[0]? and rowRange[1]?)
  .map ([startRow, endRow]) ->
    startRow
  .filter (startRow) ->
    editor.indentationForBufferRow(startRow) < indentLevel

module.exports =
class Fold extends ProviderBase
  boundToEditor: true
  
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
      filePath = @editor.getPath()
      rows = getCodeFoldStartRows(@editor, @foldLevel)
      @items = rows.map (row) =>
        point: new Point(row, 0)
        text: @editor.lineTextForBufferRow(row)
        filePath: filePath

  viewForItem: ({text}) ->
    text
