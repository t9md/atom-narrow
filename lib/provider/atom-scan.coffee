_ = require 'underscore-plus'
{Point} = require 'atom'
SearchBase = require './search-base'

module.exports =
class AtomScan extends SearchBase
  indentTextForLineHeader: "  "
  supportCacheItems: true

  getItems: ->
    source = _.escapeRegExp(@options.search)
    if @options.wordOnly
      regexp = ///\b#{source}\b///i
    else
      regexp = ///#{source}///i

    resultsByFilePath = {}
    scanPromise = atom.workspace.scan regexp, (result) ->
      if result?.matches?.length
        (resultsByFilePath[result.filePath] ?= []).push(result.matches...)

    scanPromise.then =>
      items = []
      for filePath, results of resultsByFilePath
        items.push({header: "# #{filePath}", filePath, skip: true})
        for item in results
          items.push({
            filePath: filePath
            text: item.lineText
            point: Point.fromObject(item.range[0])
          })

      @injectMaxLineTextWidthForItems(items)

  filterItems: (items, filterSpec) ->
    items = super
    normalItems = _.reject(items, (item) -> item.skip)
    filePaths = _.uniq(_.pluck(normalItems, "filePath"))

    _.filter items, (item) ->
      if item.header?
        item.filePath in filePaths
      else
        true
