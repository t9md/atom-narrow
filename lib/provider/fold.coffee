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
  boundToSingleFile: true
  showLineHeader: false
  foldLevel: 2
  supportCacheItems: true

  initialize: ->
    atom.commands.add @ui.editorElement,
      'narrow-ui:fold:increase-fold-level': => @updateFoldLevel(+1)
      'narrow-ui:fold:decrease-fold-level': => @updateFoldLevel(-1)

  updateFoldLevel: (relativeLevel) ->
    @foldLevel = Math.max(0, @foldLevel + relativeLevel)
    @ui.refresh(force: true)

  getItems: ->
    getCodeFoldStartRows(@editor, @foldLevel).map (row) =>
      point: @getFirstCharacterPointOfRow(row)
      text: @editor.lineTextForBufferRow(row)
