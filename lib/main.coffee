{CompositeDisposable} = require 'atom'
Narrow = require './narrow'
Lines = require './provider-lines'
Search = require './provider-search'
Fold = require './provider-fold'
Input = require './input'

module.exports =
  commandsDisposable: null

  activate: ->
    @subscriptions = new CompositeDisposable
    @input = new Input

    @subscribe atom.commands.add 'atom-workspace',
      'narrow:test': -> console.log(new Narrow().test())
      'narrow:lines': ->
        narrow = new Narrow()
        narrow.start(new Lines(narrow))
      'narrow:search': =>
        @input.readInput().then (input) =>
          return unless input
          @search(input)
      'narrow:fold': ->
        narrow = new Narrow()
        narrow.start(new Fold(narrow))

  subscribe: (arg) ->
    @subscriptions.add arg

  search: (word=null) ->
    narrow = new Narrow({initialKeyword: word})
    narrow.start(new Search(narrow, word))

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  provideNarrow: ->
    Narrow: Narrow
    search: @search.bind(this)
