{Point, Range} = require 'atom'
ProviderBase = require './provider-base'
{replaceOrAppendItemsForFilePath} = require '../utils'

module.exports =
class AtomScan extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  useFirstQueryAsSearchTerm: true

  initialize: ->
    @initializeSearchOptions() unless @reopened

  # Not used but keep it since I'm planning to introduce per file refresh on modification
  scanFilePath: (filePath) ->
    items = []
    atom.workspace.open(filePath, activateItem: false).then (editor) =>
      editor.scan @searchRegex, ({range}) ->
        items.push({
          filePath: filePath
          text: editor.lineTextForBufferRow(range.start.row)
          point: range.start
          range: range
        })
      items

  scanWorkspace: ->
    matchesByFilePath = {}
    scanPromise = atom.workspace.scan @searchRegex, (result) ->
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

  search: (filePath) ->
    if filePath?
      # When non project file was saved. We have nothing todo, so just return old @items.
      return @items unless atom.project.contains(filePath)

      replaceOrApppend = replaceOrAppendItemsForFilePath.bind(this, @items, filePath)
      @scanFilePath(filePath).then(replaceOrApppend)
    else
      @scanWorkspace()

  getItems: (filePath) ->
    @updateSearchState()
    if @searchRegex?
      @search().then (@items) =>
        @items
    else
      []
