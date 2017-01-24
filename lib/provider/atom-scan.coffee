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
        header = "# #{filePath}"
        items.push({header, filePath, skip: true})
        rows = []
        for item in results
          filePath = filePath
          text = item.lineText
          point = Point.fromObject(item.range[0])
          if point.row not in rows
            rows.push(point.row) # ensure single item per row
            items.push({filePath, text, point})

      @injectMaxLineTextWidth(items)
      items

  filterItems: (items, regexps) ->
    items = super
    normalItems = _.filter(items, (item) -> not item.skip)
    filePaths = _.uniq(_.pluck(normalItems, "filePath"))

    _.filter items, (item) ->
      if item.header?
        item.filePath in filePaths
      else
        true
