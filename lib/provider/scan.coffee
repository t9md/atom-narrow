path = require 'path'
_ = require 'underscore-plus'
{Point, Disposable} = require 'atom'
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
  updateGrammarOnQueryChange: false # for manual update
  useHighlighter: true

  initialize: ->
    if @options.uiInput? and @editor.getSelectedBufferRange().isEmpty()
      # scan by word-boundry if scan-by-current-word is invoked with empty selection.
      @searchWholeWord = true
    else
      @searchWholeWord = @getConfig('searchWholeWord')

  scanEditor: (regexp) ->
    items = []
    @editor.scan regexp, ({range}) =>
      items.push({
        text: @editor.lineTextForBufferRow(range.start.row)
        point: range.start
        range: range
      })
    items

  getItems: ->
    {include} = @ui.getFilterSpec()
    if include.length
      # 'include' hold instance of RegExp
      regexp = @getRegExpForSearchSource(include.shift().source)
      @ui.highlighter.setRegExp(regexp)
      @setGrammarSearchTerm(regexp)
      @scanEditor(regexp)
    else
      @ui.highlighter.setRegExp(null)
      @ui.highlighter.clear()
      []

  filterItems: (items, {include, exclude}) ->
    if include.length is 0
      items
    else
      include.shift()
      @ui.grammar.update(include)
      super
