path = require 'path'
_ = require 'underscore-plus'
{Point, Disposable} = require 'atom'
ProviderBase = require './provider-base'

module.exports =
class Scan extends ProviderBase
  boundToSingleFile: true
  supportDirectEdit: true
  showColumnOnLineHeader: true
  updateGrammarOnQueryChange: false # for manual update
  itemHaveRange: true
  showSearchOption: true
  searchIgnoreCaseChangedManually: false

  initialize: ->
    editor = atom.workspace.getActiveTextEditor()
    if @options.queryCurrentWord and editor.getSelectedBufferRange().isEmpty()
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
    firstQuery = @ui.getQuery().split(/\s+/)[0]
    if firstQuery
      if @searchIgnoreCaseChangedManually
        regexp = @getRegExpForSearchTerm(firstQuery, {@searchWholeWord, @searchIgnoreCase})
      else
        regexp = @getRegExpForSearchTerm(firstQuery, {@searchWholeWord})
        if regexp.ignoreCase isnt @searchIgnoreCase
          @searchIgnoreCase = regexp.ignoreCase
          @ui.updateProviderPanel(ignoreCaseButton: @searchIgnoreCase)

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
