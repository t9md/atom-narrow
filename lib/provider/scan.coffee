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
  wholeWord: null

  initialize: ->
    if @options.uiInput? and @editor.getSelectedBufferRange().isEmpty()
      # scan by word-boundry if scan-by-current-word is invoked with empty selection.
      @wholeWord = true
    else
      @wholeWord = @getConfig('wholeWord')

    atom.commands.add @ui.editorElement,
      'narrow:scan:toggle-whole-word': => @toggleWholeWord()

  scanEditor: (regexp) ->
    items = []
    @editor.scan regexp, ({range}) =>
      items.push({
        text: @editor.lineTextForBufferRow(range.start.row)
        point: range.start
        range: range
      })
    items

  toggleWholeWord: ->
    @wholeWord = not @wholeWord
    @ui.refresh(force: true)

  getItems: ->
    {include} = @ui.getFilterSpec()
    if include.length
      regexp = setGlobalFlagForRegExp(include.shift())
      if @wholeWord
        regexp = new RegExp("\\b#{regexp.source}\\b", regexp.flags)

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
