_ = require 'underscore-plus'
Base = require './base'
{Point} = require 'atom'
{padStringLeft, requireFrom} = require '../utils'
settings = require '../settings'

# Borrowed from git-diff core pacakge.
repositoryForPath = (goalPath) ->
  for directory, i in atom.project.getDirectories()
    if goalPath is directory.getPath() or directory.contains(goalPath)
      return atom.project.getRepositories()[i]
  null

module.exports =
class GitDiff extends Base
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
        bufferRow = if diff.newStart > 0 then diff.newStart - 1 else diff.newStart
        diff.point = new Point(bufferRow, 0)
        diff.text = @editor.lineTextForBufferRow(bufferRow)
      @items = diffs

  viewForItem: (item) ->
    {point, text} = item
    @width ?= String(@editor.getLastBufferRow()).length
    padString = padStringLeft(String(point.row + 1), @width)
    "#{padString}:#{text}"
