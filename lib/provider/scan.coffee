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
    editor = atom.workspace.getActiveTextEditor()
    # Why conditional assiginment for @searchWholeWord ?
    # It's because respect previous @searchWholeWord state on re-opened
    if @options.queryCurrentWord and editor.getSelectedBufferRange().isEmpty()
      @searchWholeWord ?= true
    else
      @searchWholeWord ?= @getConfig('searchWholeWord')

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
    searchTerm = @ui.getQuery().split(/\s+/)[0]
    if searchTerm
      if @searchIgnoreCaseChangedManually
        regexp = @getRegExpForSearchTerm(searchTerm, {@searchWholeWord, @searchIgnoreCase})
      else
        if @searchWholeWord and (searchTerm.length is 1) and (not /\w/.test(searchTerm))
          @searchWholeWord = false
          @ui.controlBar.updateStateElements(wholeWordButton: @searchWholeWord)

        regexp = @getRegExpForSearchTerm(searchTerm, {@searchWholeWord})

        if regexp.ignoreCase isnt @searchIgnoreCase
          @searchIgnoreCase = regexp.ignoreCase
          @ui.controlBar.updateStateElements(ignoreCaseButton: @searchIgnoreCase)

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
        range: new Range([row, 0], [row, 0])
        text: text

  filterItems: (items, {include}) ->
    include.shift()
    @ui.grammar.update(include)
    super
