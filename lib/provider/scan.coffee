path = require 'path'
_ = require 'underscore-plus'
{Point, Disposable, Range} = require 'atom'
ProviderBase = require './provider-base'

module.exports =
class Scan extends ProviderBase
  boundToSingleFile: true
  supportDirectEdit: true
  showColumnOnLineHeader: true
  updateGrammarOnQueryChange: false # for manual update
  itemHaveRange: true
  showSearchOption: true

  initialize: ->
    return if @reopened

    editor = atom.workspace.getActiveTextEditor()
    if @options.queryCurrentWord and editor.getSelectedBufferRange().isEmpty()
      @searchWholeWord = true
    else
      @searchWholeWord = @getConfig('searchWholeWord')

  scanEditor: (regexp) ->
    items = []
    regExp = new RegExp(regexp.source, regexp.flags) # clone to reset lastIndex
    for lineText, row in @editor.buffer.getLines()
      regExp.lastIndex = 0
      while result = regExp.exec(lineText)
        start = new Point(row, result.index)
        items.push(
          text: lineText
          point: start
          range: Range.fromPointWithDelta(start, 0, result[0].length)
        )
    items

  getItems: ->
    searchTerm = @ui.getQuery().split(/\s+/)[0]
    if searchTerm
      unless @searchWholeWordChangedManually
        # Auto relax \b restriction when there is no word-char in searchTerm.
        @searchWholeWord = false if @searchWholeWord and (not /\w/.test(searchTerm))

      unless @searchIgnoreCaseChangedManually
        @searchIgnoreCase = @getIgnoreCaseValueForSearchTerm(searchTerm)

      regexp = @getRegExpForSearchTerm(searchTerm, {@searchWholeWord, @searchIgnoreCase})

      @ui.controlBar.updateStateElements
        wholeWordButton: @searchWholeWord
        ignoreCaseButton: @searchIgnoreCase

      @ui.highlighter.setRegExp(regexp)
      @ui.grammar.setSearchTerm(regexp)
      @initiallySearchedRegexp = regexp
      @scanEditor(regexp)
    else
      # Reset search term and grammar
      @ui.highlighter.clear()
      @ui.highlighter.setRegExp(null)
      @ui.grammar.setSearchTerm(null)
      @ui.grammar.activate()

      @editor.buffer.getLines().map (text, row) ->
        point: new Point(row, 0)
        range: new Range([row, 0], [row, 0])
        text: text

  filterItems: (items, {include}) ->
    include.shift()
    @ui.grammar.update(include)
    super
