_ = require 'underscore-plus'
{getValidIndexForList} = require './utils'

class Entry
  constructor: (@text, @useRegex) ->

  # use to eliminate duplicate entries by _.uniq()
  toString: ->
    @text + ':' + String(@useRegex)

module.exports =
new class InputHistoryManager
  maxSize: 100
  constructor: ->
    @index = -1
    @entries = []

  get: (direction) ->
    delta = switch direction
      when 'previous' then +1
      when 'next' then -1
    @index = getValidIndexForList(@entries, @index + delta)
    @entries[@index]

  save: (text, useRegex) ->
    return unless text
    entry = new Entry(text, useRegex)
    @entries.unshift(entry)
    @entries = _.uniq(@entries, (entry) -> entry.toString())
    @entries.splice(@maxSize) if @entries.length > @maxSize

  reset: ->
    @index = -1

  destroy: ->
    @entries = null
