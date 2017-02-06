path = require 'path'
_ = require 'underscore-plus'
{Point, Disposable} = require 'atom'
{setGlobalFlagForRegExp} = require '../utils'
ProviderBase = require './provider-base'
Highlighter = require '../highlighter'

module.exports =
class Scan extends ProviderBase
  boundToEditor: true
  supportCacheItems: false
  supportDirectEdit: true
  showLineHeader: true
  showColumnOnLineHeader: true
  ignoreSideMovementOnSyncToEditor: false
  updateGrammarOnQueryChange: false # for manual update

  initialize: ->
    if @options.uiInput? and @editor.getSelectedBufferRange().isEmpty()
      # scan by word-boundry if scan-by-current-word is invoked with empty selection.
      @scanWord = true
    else
      @scanWord = @getConfig('scanWord')

    @highlighter = new Highlighter(this)
    @subscriptions.add new Disposable =>
      @highlighter.destroy()

    atom.commands.add @ui.editorElement,
      'narrow:scan:toggle-scan-word': => @toggleScanWord()

  scanEditor: (regexp) ->
    items = []
    @editor.scan regexp, ({range}) =>
      items.push({
        text: @editor.lineTextForBufferRow(range.start.row)
        point: range.start
      })
    items

  toggleScanWord: ->
    @scanWord = not @scanWord
    @ui.refresh(force: true)

  getItems: ->
    {include} = @ui.getFilterSpec()
    if include.length
      regexp = setGlobalFlagForRegExp(include.shift())
      if @scanWord
        regexp = new RegExp("\\b#{regexp.source}\\b", regexp.flags)

      @highlighter.setRegExp(regexp)
      @setGrammarSearchTerm(regexp)
      @scanEditor(regexp)
    else
      @highlighter.setRegExp(null)
      @highlighter.clearHighlight()
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
