path = require 'path'
_ = require 'underscore-plus'
{Point} = require 'atom'
{setGlobalFlagForRegExp} = require '../utils'
ProviderBase = require './provider-base'

module.exports =
class Scan extends ProviderBase
  boundToEditor: true
  supportCacheItems: false
  supportDirectEdit: true
  showLineHeader: true
  showColumnOnLineHeader: true
  ignoreSideMovementOnSyncToEditor: false
  updateGrammarOnQueryChange: false

  scanEditor: (regexp) ->
    regexp = setGlobalFlagForRegExp(regexp)
    items = []
    @editor.scan regexp, ({range}) =>
      items.push({
        text: @editor.lineTextForBufferRow(range.start.row)
        point: range.start
      })
    items

  getItems: ->
    {include} = @ui.getFilterSpec()
    if include.length
      regexp = include.shift()
      source = regexp.source
      if regexp.ignoreCase
        searchTerm = "(?i:#{source})"
      else
        searchTerm = source
      @ui.grammar.setSearchTerm(searchTerm)
      @scanEditor(regexp)
    else
      []

  filterItems: (items, {include, exclude}) ->
    if include.length is 0
      return items

    include.shift()
    @ui.grammar.update(include)
    for regexp in exclude
      items = items.filter (item) -> not regexp.test(item.text)

    for regexp in include
      items = items.filter (item) -> regexp.test(item.text)

    items
