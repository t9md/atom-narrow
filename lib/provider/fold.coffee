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
  showLineHeader: false

  initialize: ->
    atom.commands.add @ui.editorElement,
      'narrow-ui:fold:increase-fold-level': => @updateFoldLevel(+1)
      'narrow-ui:fold:decrease-fold-level': => @updateFoldLevel(-1)

  updateFoldLevel: (relativeLevel) ->
    @foldLevel = Math.max(0, @foldLevel + relativeLevel)
    @refresh()

  getItems: ->
    return @items if @items?

    filePath = @editor.getPath()
    rows = getCodeFoldStartRows(@editor, @foldLevel)
    @items = rows.map (row) =>
      point: new Point(row, 0)
      text: @editor.lineTextForBufferRow(row)
      filePath: filePath
