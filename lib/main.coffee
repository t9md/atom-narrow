{CompositeDisposable} = require 'atom'

UI = require './ui'
Lines = require './provider/lines'
Search = require './provider/search'
Fold = require './provider/fold'
Input = require './input'
settings = require './settings'

module.exports =
  config: settings.config

  activate: ->
    @subscriptions = new CompositeDisposable
    @input = new Input

    @subscribe atom.commands.add 'atom-workspace',
      'narrow:lines': => @lines()
      'narrow:fold': => new Fold(@getUI())
      'narrow:search': =>
        @input.readInput().then (input) =>
          @search(input) if input
      'narrow:focus': =>
        @narrow.show()

  subscribe: (arg) ->
    @subscriptions.add arg

  lines: (word=null) ->
    ui = @getUI(initialInput: word)
    new Lines(ui)

  search: (word=null) ->
    reutrn unless word
    ui = @getUI(initialKeyword: word)
    new Search(ui, {word})

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  getUI: (options={}) ->
    new UI(options)

  provideNarrow: ->
    getUI: @getUI.bind(this)
    search: @search.bind(this)
    lines: @lines.bind(this)

  consumeVim: ({getEditorState}) ->
    narrowSearch = @search.bind(this)
    narrowLines = @lines.bind(this)

    confirmSearch = -> # return search text
      editor = atom.workspace.getActiveTextEditor()
      vimState = getEditorState(editor)
      text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      text

    @subscribe atom.commands.add 'atom-text-editor.vim-mode-plus-search',
      'vim-mode-plus-user:narrow-lines-from-search': -> narrowLines(confirmSearch())
      'vim-mode-plus-user:narrow-search-from-search': -> narrowSearch(confirmSearch())
