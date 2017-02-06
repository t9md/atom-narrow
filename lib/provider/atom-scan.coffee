path = require 'path'
_ = require 'underscore-plus'
{Point} = require 'atom'
SearchBase = require './search-base'

module.exports =
class AtomScan extends SearchBase
  supportCacheItems: true

  # Not used but keep it since I'm planning to introduce per file refresh on modification
  scanFile: (regexp, filePath) ->
    items = []
    atom.workspace.open(filePath, activateItem: false).then (editor) ->
      editor.scan regexp, ({range}) ->
        items.push({
          filePath: filePath
          text: editor.lineTextForBufferRow(range.start.row)
          point: range.start
        })
      items

  scanWorkspace: (regexp) ->
    matchesByFilePath = {}
    scanPromise = atom.workspace.scan regexp, (result) ->
      if result?.matches?.length
        matchesByFilePath[result.filePath] ?= []
        matchesByFilePath[result.filePath].push(result.matches...)

    itemizePromise = scanPromise.then ->
      items = []
      for filePath, matches of matchesByFilePath
        projectName = path.basename(atom.project.relativizePath(filePath)[0])
        for match in matches
          items.push({
            projectName: projectName
            filePath: filePath
            text: match.lineText
            point: Point.fromObject(match.range[0])
            range: match.range
          })
      items

    itemizePromise.then (_items) ->
      items = []
      for projectName, itemsInProject of _.groupBy(_items, (item) -> item.projectName)
        header = "# #{projectName}"
        items.push({header, projectName, projectHeader: true, skip: true})

        for filePath, itemsInFile of _.groupBy(itemsInProject, (item) -> item.filePath)
          header = "## #{atom.project.relativize(filePath)}"
          items.push({header, projectName, filePath, skip: true})
          items.push(itemsInFile...)
      items

  getItems: ->
    @scanWorkspace(@regExpForSearchTerm)
