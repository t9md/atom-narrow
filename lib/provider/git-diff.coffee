ProviderBase = require './provider-base'
{Point} = require 'atom'
{limitNumber} = require '../utils'

# Borrowed from git-diff core pacakge.
repositoryForPath = (goalPath) ->
  for directory, i in atom.project.getDirectories()
    if goalPath is directory.getPath() or directory.contains(goalPath)
      return atom.project.getRepositories()[i]
  null

module.exports =
class GitDiff extends ProviderBase
  refresh: ->
    @items = []
    @ui.refresh()

  getItems: ->
    if @items?
      @items
    else
      filePath = @editor.getPath()
      diffs = repositoryForPath(filePath)?.getLineDiffs(filePath, @editor.getText()) ? []
      for diff in diffs
        bufferRow = limitNumber(diff.newStart - 1, min: 0)
        diff.point = new Point(bufferRow, 0)
        diff.text = @editor.lineTextForBufferRow(bufferRow)
      @items = diffs

  viewForItem: ({text, point}) ->
    @getLineNumberText(point.row) + ":" + text
