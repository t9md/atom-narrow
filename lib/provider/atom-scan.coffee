path = require 'path'
_ = require 'underscore-plus'
{Point, Range} = require 'atom'
SearchBase = require './search-base'

module.exports =
class AtomScan extends SearchBase
  # Not used but keep it since I'm planning to introduce per file refresh on modification
  scanFilePath: (filePath) ->
    items = []
    atom.workspace.open(filePath, activateItem: false).then (editor) =>
      editor.scan @searchRegExp, ({range}) ->
        items.push({
          filePath: filePath
          text: editor.lineTextForBufferRow(range.start.row)
          point: range.start
          range: range
        })
      items

  scanWorkspace: ->
    matchesByFilePath = {}
    scanPromise = atom.workspace.scan @searchRegExp, (result) ->
      if result?.matches?.length
        matchesByFilePath[result.filePath] ?= []
        matchesByFilePath[result.filePath].push(result.matches...)

    scanPromise.then ->
      items = []
      for filePath, matches of matchesByFilePath
        for match in matches
          items.push({
            filePath: filePath
            text: match.lineText
            point: Point.fromObject(match.range[0])
            range: Range.fromObject(match.range)
          })
      items

  getItems: (filePath) ->
    if filePath?
      return @items unless atom.project.contains(filePath)

      @scanFilePath(filePath).then (newItems) =>
        @items = @replaceOrAppendItemsForFilePath(@items, filePath, newItems)
    else
      @scanWorkspace().then (items) =>
        @items = items
