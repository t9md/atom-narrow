{CompositeDisposable} = require 'atom'
Narrow = require './narrow'

module.exports =
  commandsDisposable: null

  activate: ->
    @subscriptions = new CompositeDisposable

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  provideNarrow: ->
    Narrow: Narrow
