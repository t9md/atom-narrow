{CompositeDisposable} = require 'atom'
Narrow = require './narrow'
Lines = require './provider-lines'
Search = require './provider-search'
Fold = require './provider-fold'
Input = require './input'
settings = require './settings'

module.exports =
  config: settings.config

  activate: ->
    @subscriptions = new CompositeDisposable
    @input = new Input

    @subscribe atom.commands.add 'atom-workspace',
      'narrow:lines': => @lines()
      'narrow:fold': => new Fold(@getNarrow())
      'narrow:search': =>
        @input.readInput().then (input) =>
          @search(input) if input
      'narrow:focus': =>
        @narrow.show()

  subscribe: (arg) ->
    @subscriptions.add arg

  lines: (word=null) ->
    narrow = @getNarrow(initialInput: word)
    new Lines(narrow)

  search: (word=null) ->
    reutrn unless word
    narrow = @getNarrow(initialKeyword: word)
    new Search(narrow, {word})

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  getNarrow: (options={}) ->
    @narrow = new Narrow(options)
    return @narrow

  provideNarrow: ->
    getNarrow: @getNarrow.bind(this)
    search: @search.bind(this)
    lines: @lines.bind(this)
