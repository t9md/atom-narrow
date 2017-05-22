_ = require 'underscore-plus'
{getValidIndexForList} = require './utils'

class History
  maxSize: 100
  constructor: (@entries=[]) ->
    @index = -1

  get: (direction) ->
    switch direction
      when 'previous'
        @index = getValidIndexForList(@entries, @index + 1)
      when 'next'
        @index = getValidIndexForList(@entries, @index - 1)
    @entries[@index]

  save: (text) ->
    return unless text
    @entries.unshift(text)
    @entries = _.uniq(@entries, (entry) -> entry.toString())
    @entries.splice(@maxSize) if @entries.length > @maxSize

  reset: ->
    @index = -1

  destroy: ->
    @entries = null

class QueryHistory
  constructor: ->
    @historyByProviderName = {}

  deserialize: (state) ->
    for name, entries of state ? {}
      @historyByProviderName[name] = new History(entries)

  serialize: ->
    result = {}
    for name, history of @historyByProviderName
      result[name] = history.entries
    result

  save: (name, value) ->
    @historyByProviderName[name] ?= new History()
    @historyByProviderName[name].save(value)

  get: (name, direction) ->
    @historyByProviderName[name]?.get(direction) ? ""

  reset: (name) ->
    @historyByProviderName[name]?.reset()

  clear: (name) ->
    @historyByProviderName[name]?.clear()

module.exports = new QueryHistory
