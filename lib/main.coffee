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
    settings.removeDeprecated()
    @input = new Input

    currentWord = @getCurrentWord.bind(this)
    @subscribe atom.commands.add 'atom-workspace',
      'narrow:lines': => @lines()
      'narrow:lines-by-current-word': => @lines(currentWord())

      'narrow:fold': => @fold()
      'narrow:fold-by-current-word': => @fold(currentWord())

      'narrow:search': => @search()
      'narrow:search-by-current-word': => @search(currentWord())

      'narrow:search-current-project': => @searchCurrentProject()
      'narrow:search-current-project-by-current-word': => @searchCurrentProject(currentWord())

      'narrow:focus': => @ui.focus()

  subscribe: (arg) ->
    @subscriptions.add arg

  # Return currently selected text or word under cursor.
  getCurrentWord: ->
    editor = atom.workspace.getActiveTextEditor()
    selection = editor.getLastSelection()
    {cursor} = selection

    if selection.isEmpty()
      point = cursor.getBufferPosition()
      selection.selectWord()
      text = selection.getText()
      cursor.setBufferPosition(point)
      text
    else
      selection.getText()

  lines: (initialInput) ->
    ui = @getUI({initialInput})
    new Lines(ui)

  fold: (initialInput) ->
    ui = @getUI({initialInput})
    new Fold(ui)

  searchCurrentProject: (word) ->
    projects = null
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    for dir in atom.project.getDirectories() when dir.contains(editor.getPath())
      projects = [dir.getPath()]
      break

    unless projects?
      message = "#{editor.getPath()} not belonging to any project"
      atom.notifications.addInfo message, dismissable: true
      return
    @search(word, projects)

  search: (word=null, projects=atom.project.getPaths()) ->
    unless word?
      @input.readInput().then (input) =>
        @search(input, projects)

    return unless word
    ui = @getUI(initialKeyword: word)
    new Search(ui, {word, projects})

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  getUI: (options={}) ->
    @ui = new UI(options)

  provideNarrow: ->
    getUI: @getUI.bind(this)
    search: @search.bind(this)
    lines: @lines.bind(this)

  isNarrowEditor: (editor) ->
    editor.element.classList.contains('narrow')

  consumeVim: ({getEditorState, observeVimStates}) ->
    subscribe = @subscribe.bind(this)

    @subscribe observeVimStates (vimState) =>
      {editor} = vimState
      return unless @isNarrowEditor(editor)

      if settings.get('vmpStartInInsertModeForUI') and not vimState.isMode('insert')
        vimState.activate('insert')

      subscribe vimState.modeManager.onDidActivateMode ({mode, submode}) ->
        if mode is 'insert' and editor.getCursorBufferPosition().row isnt 0
          editor.setCursorBufferPosition([0, Infinity]) # auto move to EOL of first line.

    confirmSearch = -> # return search text
      editor = atom.workspace.getActiveTextEditor()
      vimState = getEditorState(editor)
      text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      return text

    @subscribe atom.commands.add 'atom-text-editor.vim-mode-plus-search',
      'vim-mode-plus-user:narrow-lines-from-search': => @lines(confirmSearch())
      'vim-mode-plus-user:narrow-search': => @search(confirmSearch())
      'vim-mode-plus-user:narrow-search-current-project': => @searchCurrentProject(confirmSearch())
