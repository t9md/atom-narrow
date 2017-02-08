path = require 'path'
_ = require 'underscore-plus'
{Point, Disposable} = require 'atom'
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
  showSearchOption: true
  searchIgnoreCaseChangedManually: false

  initialize: ->
    if not @options.fromVmp and @options.uiInput? and @editor.getSelectedBufferRange().isEmpty()
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

  toggleSearchIgnoreCase: ->
    @searchIgnoreCaseChangedManually = true
    super

  getItems: ->
    source = @ui.getFilterSpec().include.shift()?.source
    if source?
      if @searchIgnoreCaseChangedManually
        regexp = @getRegExpForSearchSource(source, @searchIgnoreCase)
      else
        regexp = @getRegExpForSearchSource(source, null)
        if regexp.ignoreCase isnt @searchIgnoreCase
          @searchIgnoreCase = regexp.ignoreCase
          @ui.providerPanel.updateSearchOptionState()

      @ui.highlighter.setRegExp(regexp)
      @ui.grammar.setSearchTerm(regexp)
      @scanEditor(regexp)
    else
      # Reset search term and grammar
      @ui.highlighter.clear()
      @ui.highlighter.setRegExp(null)
      @ui.grammar.setSearchTerm(null)
      @ui.grammar.activate()

      @editor.buffer.getLines().map (text, row) ->
        point: new Point(row, 0)
        text: text

  filterItems: (items, {include}) ->
    include.shift()
    @ui.grammar.update(include)
    super
