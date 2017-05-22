{Emitter} = require 'atom'
_ = require 'underscore-plus'

module.exports =
class SearchOptions
  constructor: (@provider, props={}) ->
    @emitter = new Emitter

    Object.assign(this, props)

    @searchTerm ?= false
    @searchUseRegex ?= false
    @searchRegex ?= false

    @searchWholeWord ?= false
    @searchWholeWordChangedManually ?= false

    @searchIgnoreCase ?= false
    @searchIgnoreCaseChangedManually ?= false

  set: (params) ->
    for param, value of params
      this[param] = value

  toggle: (param) ->
    this[param] = not this[param]
    switch param
      when 'searchWholeWord'
        @searchWholeWordChangedManually = true
      when 'searchIgnoreCase'
        @searchIgnoreCaseChangedManually = true
      when 'searchUseRegex'
        @searchUseRegexChangedManually = true

  pick: (names...) ->
    params = {}
    for name in names
      params[name] = this[name]
    params

  getIgnoreCaseValueForSearchTerm: (term) ->
    sensitivity = @provider.getConfig('caseSensitivityForSearchTerm')
    (sensitivity is 'insensitive') or (sensitivity is 'smartcase' and not /[A-Z]/.test(term))

  buildRegExp: ->
    return null unless @searchTerm

    if @searchUseRegex
      source = @searchTerm
      try
        new RegExp(source, '')
      catch error
        return null
    else
      source = _.escapeRegExp(@searchTerm)

    if @searchWholeWord
      startBoundary = /^\w/.test(@searchTerm)
      endBoundary = /\w$/.test(@searchTerm)
      if not startBoundary and not endBoundary
        # Go strict
        source = "\\b" + source + "\\b"
      else
        # Relaxed if I can set end or start boundary
        startBoundaryString = if startBoundary then "\\b" else ''
        endBoundaryString = if endBoundary then "\\b" else ''
        source = startBoundaryString + source + endBoundaryString

    flags = 'g'
    flags += 'i' if @searchIgnoreCase
    new RegExp(source, flags)

  getState: ->
    {
      @searchWholeWord
      @searchWholeWordChangedManually
      @searchIgnoreCase
      @searchIgnoreCaseChangedManually
      @searchUseRegex
      @searchUseRegexChangedManually
      @searchTerm
    }

  setSearchTerm: (@searchTerm) ->
    if @searchTerm
      # Auto disable @searchWholeWord unless it's manually changed..
      if @searchWholeWord and not @searchWholeWordChangedManually
        @searchWholeWord = /\w/.test(@searchTerm)

      unless @searchIgnoreCaseChangedManually
        @searchIgnoreCase = @getIgnoreCaseValueForSearchTerm(@searchTerm)

    @searchRegex = @buildRegExp()
    @grammarCanHighlight = @searchRegex? and (not @searchUseRegex or (@searchTerm is _.escapeRegExp(@searchTerm)))
