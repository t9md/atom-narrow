_ = require 'underscore-plus'
{getValidIndexForList} = require './utils'

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
    @entries[@index] ? ''

  save: (entry) ->
    return unless entry
    @entries.unshift(entry)
    @entries = _.uniq(@entries)
    @entries.splice(@maxSize) if @entries.length > @maxSize

  reset: ->
    @index = -1

  destroy: ->
    @entries = null
