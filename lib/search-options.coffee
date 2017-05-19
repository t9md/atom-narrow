{Emitter} = require 'atom'

module.exports =
class SearchOptions
  constructor: ->
    @emitter = new Emitter

    @searchUseRegex = false
    @searchRegex = false
    @searchTerm = false

  set: (params) ->
    for param, value of params
      this[param] = value

  pick: (names...) ->
    params = {}
    for name in names
      params[name] = this[name]
    params
