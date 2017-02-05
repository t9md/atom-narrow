_ = require 'underscore-plus'
{Point} = require 'atom'
SearchBase = require './search-base'

module.exports =
class AtomScan extends SearchBase
  supportCacheItems: true

  getItems: ->
    resultsByFilePath = {}
    scanPromise = atom.workspace.scan @regExpForSearchTerm, (result) ->
      if result?.matches?.length
        (resultsByFilePath[result.filePath] ?= []).push(result.matches...)

    scanPromise.then ->
      items = []
      for filePath, results of resultsByFilePath
        items.push({header: "# #{filePath}", filePath, skip: true})
        for item in results
          items.push({
            filePath: filePath
            text: item.lineText
            point: Point.fromObject(item.range[0])
          })
      items

  filterItems: (items, filterSpec) ->
    items = super
    normalItems = _.reject(items, (item) -> item.skip)
    filePaths = _.uniq(_.pluck(normalItems, "filePath"))

    _.filter items, (item) ->
      if item.header?
        item.filePath in filePaths
      else
        true
