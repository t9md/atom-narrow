path = require 'path'
_ = require 'underscore-plus'
{Point} = require 'atom'
SearchBase = require './search-base'

module.exports =
class AtomScan extends SearchBase
  # Not used but keep it since I'm planning to introduce per file refresh on modification
  scanFilePath: (regexp, filePath) ->
    items = []
    atom.workspace.open(filePath, activateItem: false).then (editor) ->
      editor.scan regexp, ({range}) ->
        items.push({
          filePath: filePath
          text: editor.lineTextForBufferRow(range.start.row)
          point: range.start
          range: range
        })
      items

  scanWorkspace: (regexp) ->
    matchesByFilePath = {}
    scanPromise = atom.workspace.scan regexp, (result) ->
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
            range: match.range
          })
      items

  getItems: (filePath) ->
    if filePath?
      itemsPromise = @scanFilePath(@searchRegExp, filePath).then (newItems) =>
        @replaceOrAppendItemsForFilePath(@items, filePath, newItems)
    else
      itemsPromise = @scanWorkspace(@searchRegExp)

    itemsPromise.then (items) =>
      # hold last generated item to support per-file-refresh.
      @items = items
      @getItemsWithHeaders(@items)
