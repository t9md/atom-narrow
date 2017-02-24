_ = require 'underscore-plus'
{getValidIndexForList} = require './utils'

module.exports =
class InputHistoryManager
  maxSize: 100
  constructor: ->
    @index = -1
    @entries = []

  get: (direction) ->
    switch direction
      when 'next'
        @index = getValidIndexForList(@entries, @index + 1)
      when 'previous'
        @index = getValidIndexForList(@entries, @index - 1)

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
