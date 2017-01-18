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

    getCurrentWord = @getCurrentWord.bind(this)
    @subscriptions.add atom.commands.add 'atom-workspace',
      'narrow:lines': => @lines()
      'narrow:lines-by-current-word': => @lines(getCurrentWord())

      'narrow:fold': => @fold()
      'narrow:fold-by-current-word': => @fold(getCurrentWord())

      'narrow:search': => @search()
      'narrow:search-by-current-word': => @search(getCurrentWord())

      'narrow:search-current-project': => @searchCurrentProject()
      'narrow:search-current-project-by-current-word': => @searchCurrentProject(getCurrentWord())

      'narrow:focus': => @ui.focus()

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

  # narrow: (providerName, word=null) ->
  #   provider = require

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

  isNarrowEditor: (editor) ->
    editor.element.classList.contains('narrow')

  consumeVim: ({getEditorState, observeVimStates}) ->
    @subscriptions.add observeVimStates (vimState) =>
      {editor} = vimState
      return unless @isNarrowEditor(editor)

      if settings.get('vmpStartInInsertModeForUI') and not vimState.isMode('insert')
        vimState.activate('insert')

      @subscriptions.add vimState.modeManager.onDidActivateMode ({mode, submode}) ->
        if mode is 'insert' and editor.getCursorBufferPosition().row isnt 0
          editor.setCursorBufferPosition([0, Infinity]) # auto move to EOL of first line.

    confirmSearch = -> # return search text
      editor = atom.workspace.getActiveTextEditor()
      vimState = getEditorState(editor)
      text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      return text

    @subscriptions.add atom.commands.add 'atom-text-editor.vim-mode-plus-search',
      'vim-mode-plus-user:narrow-lines-from-search': => @lines(confirmSearch())
      'vim-mode-plus-user:narrow-search': => @search(confirmSearch())
      'vim-mode-plus-user:narrow-search-current-project': => @searchCurrentProject(confirmSearch())
