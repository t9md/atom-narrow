path = require 'path'
_ = require 'underscore-plus'
{Point, Disposable, Range} = require 'atom'
{cloneRegExp} = require '../utils'
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

  scanEditor: (regExp) ->
    items = []
    regExp = cloneRegExp(regExp)
    for lineText, row in @editor.buffer.getLines()
      regExp.lastIndex = 0
      while match = regExp.exec(lineText)
        range = new Range([row, match.index], [row, match.index + match[0].length])
        items.push(text: lineText, point: range.start, range: range)
    items

  updateRegExp: (regExp) ->
    @ui.highlighter.setRegExp(regExp)
    @ui.grammar.setSearchTerm(regExp)
    @ui.controlBar.updateSearchTermElement(regExp)
    unless regExp?
      @ui.highlighter.clear()
      @ui.grammar.activate()

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

      @updateRegExp(regexp)

      @initiallySearchedRegexp = regexp
      @scanEditor(regexp)
    else
      @updateRegExp(null)
      @editor.buffer.getLines().map (text, row) ->
        point = new Point(row, 0)
        {text, point, range: new Range(point, point)}

  filterItems: (items, {include}) ->
    include.shift()
    @ui.grammar.update(include)
    super
