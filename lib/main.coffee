{CompositeDisposable} = require 'atom'
Narrow = require './narrow'

module.exports =
  commandsDisposable: null

  activate: ->
    @subscriptions = new CompositeDisposable
    atom.commands.add 'atom-workspace',
      'narrow:test': ->
        console.log(new Narrow().test())

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  provideNarrow: ->
    return {Narrow}
