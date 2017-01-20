{CompositeDisposable} = require 'atom'

Search = require './provider/search'
Input = require './input'
settings = require './settings'
UI = null

module.exports =
  config: settings.config
  currentNarrowEditor: null
  providers: []

  activate: ->
    @subscriptions = new CompositeDisposable
    settings.removeDeprecated()
    @input = new Input

    getUiOptions = =>
      uiOptions:
        initialInput: @getCurrentWord()

    getCurrentWord = @getCurrentWord.bind(this)
    @subscriptions.add atom.workspace.observeActivePaneItem (item) =>
      if atom.workspace.isTextEditor(item) and @isNarrowEditor(item)
        @currentNarrowEditor = item

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'narrow:lines': => @narrow('lines')
      'narrow:lines-by-current-word': => @narrow('lines', getUiOptions())

      'narrow:fold': => @narrow('fold')
      'narrow:fold-by-current-word': => @narrow('fold', getUiOptions())

      'narrow:symbols': => @narrow('symbols')
      'narrow:git-diff': => @narrow('git-diff')
      'narrow:bookmarks': => @narrow('bookmarks')

      'narrow:search': => @search()
      'narrow:search-by-current-word': => @search(getCurrentWord())

      'narrow:search-current-project': => @searchCurrentProject()
      'narrow:search-current-project-by-current-word': => @searchCurrentProject(getCurrentWord())

      'narrow:focus': => @getUI()?.focus()
      'narrow:next-item': => @getUI()?.nextItem()
      'narrow:previous-item': => @getUI()?.previousItem()

  getUI: (narrowEditor) ->
    UI ?= require './ui'
    UI.uiByNarrowEditor.get(@currentNarrowEditor)

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

  narrow: (providerName, {uiOptions, providerOptions}={}) ->
    if providerName not of @providers
      @providers[providerName] = require("./provider/#{providerName}")
    klass = @providers[providerName]
    new klass(uiOptions, providerOptions)

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
    new Search(initialKeyword: word, {word, projects})

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

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

    getUiOptions = ->
      uiOptions:
        initialInput: confirmSearch()

    @subscriptions.add atom.commands.add 'atom-text-editor.vim-mode-plus-search',
      'vim-mode-plus-user:narrow-lines-from-search': => @narrow('lines', getUiOptions())
      'vim-mode-plus-user:narrow-search': => @search(confirmSearch())
      'vim-mode-plus-user:narrow-search-current-project': => @searchCurrentProject(confirmSearch())
