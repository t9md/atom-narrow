_ = require 'underscore-plus'

ProviderBase = require './provider-base'
{getCurrentWord} = require '../utils'
history = require '../input-history-manager'

lastIgnoreCaseOption = {}
readInput = require '../read-input'

module.exports =
class SearchBase extends ProviderBase
  supportDirectEdit: true
  showColumnOnLineHeader: true
  searchRegex: null
  itemHaveRange: true
  showSearchOption: true
  supportCacheItems: true
  querySelectedText: false
  searchTerm: null
  useRegex: false

  getState: ->
    @mergeState(super, {@useRegex})

  @useRegex: null
  getUseRegex: ->
    if @getConfig('rememberUseRegex')
      @constructor.useRegex ? @getConfig('useRegex')
    else
      @getConfig('useRegex')

  setUseRegex: (value) ->
    if @getConfig('rememberUseRegex')
      @constructor.useRegex = value

  getSearchTerm: ->
    if @options.search
      return @options.search

    editor = atom.workspace.getActiveTextEditor()
    if text = editor.getSelectedText()
      return text

    if @options.searchCurrentWord
      @searchWholeWord = true
      getCurrentWord(editor)

  checkReady: ->
    return true if @reopened

    @searchTerm = @getSearchTerm()
    @searchWholeWord ?= @getConfig('searchWholeWord')

    if @options.searchCurrentWord
      if @getConfig('rememberIgnoreCaseForByCurrentWordSearch')
        @searchIgnoreCase = lastIgnoreCaseOption.byCurrentWord
    else
      if @getConfig('rememberIgnoreCaseForByHandSearch')
        @searchIgnoreCase = lastIgnoreCaseOption.byHand

    if @searchTerm?
      history.save(@searchTerm, false)
      @searchIgnoreCase ?= @getIgnoreCaseValueForSearchTerm(@searchTerm)
      return @searchTerm
    else
      readInput(@getUseRegex()).then ({text, useRegex}) =>
        # Validate regexp
        if useRegex
          try
            new RegExp(text)
          catch error
            console.warn "invalid regex pattern:", error
            return null

        @setUseRegex(useRegex)
        @searchTerm = text
        history.save(@searchTerm, useRegex)
        # Automatically switch to static search for faster range calcuration and good syntax highlight
        @useRegex = useRegex and _.escapeRegExp(text) isnt text

        @searchIgnoreCase ?= @getIgnoreCaseValueForSearchTerm(@searchTerm)
        return @searchTerm

  destroy: ->
    if @reopened
      return super

    if @options.searchCurrentWord
      if @getConfig('rememberIgnoreCaseForByCurrentWordSearch')
        lastIgnoreCaseOption.byCurrentWord = @searchIgnoreCase
    else
      if @getConfig('rememberIgnoreCaseForByHandSearch')
        lastIgnoreCaseOption.byHand = @searchIgnoreCase
    super

  initialize: ->
    @resetRegExpForSearchTerm()
    @initialSearchRegex = @searchRegex

  resetRegExpForSearchTerm: ->
    if @useRegex
      flags = 'g'
      flags += 'i' if @searchIgnoreCase
      expression = @searchTerm
      if @searchWholeWord
        expression = "\\b#{@searchTerm}\\b"
      @searchRegex = new RegExp(expression, flags)
    else
      @searchRegex = @getRegExpForSearchTerm(@searchTerm, {@searchWholeWord, @searchIgnoreCase})
      @ui.grammar.setSearchTerm(@searchRegex)
    @ui.highlighter.setRegExp(@searchRegex)

  toggleSearchWholeWord: ->
    super
    @resetRegExpForSearchTerm()

  toggleSearchIgnoreCase: ->
    super
    @resetRegExpForSearchTerm()
