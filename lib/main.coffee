{CompositeDisposable} = require 'atom'
settings = require './settings'
UI = null
getCurrentWord = null # delay

module.exports =
  config: settings.config
  currentNarrowEditor: null
  providers: []

  activate: ->
    @subscriptions = new CompositeDisposable
    settings.removeDeprecated()

    @subscriptions.add atom.workspace.observeActivePaneItem (item) =>
      if atom.workspace.isTextEditor(item) and @isNarrowEditor(item)
        @currentNarrowEditor = item

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'narrow:lines': => @narrow('lines')
      'narrow:lines-by-current-word': => @narrow('lines', input: @getCurrentWord())

      'narrow:fold': => @narrow('fold')
      'narrow:fold-by-current-word': => @narrow('fold', input: @getCurrentWord())

      'narrow:symbols': => @narrow('symbols')
      'narrow:git-diff': => @narrow('git-diff')
      'narrow:bookmarks': => @narrow('bookmarks')

      'narrow:atom-scan': => @atomScan()
      'narrow:atom-scan-by-current-word': => @atomScan(@getCurrentWord())

      'narrow:search': => @search()
      'narrow:search-by-current-word': => @search(@getCurrentWord())

      'narrow:search-current-project': => @searchCurrentProject()
      'narrow:search-current-project-by-current-word': => @searchCurrentProject(@getCurrentWord())

      'narrow:focus': => @getUI()?.focus()
      'narrow:close': => @getUI()?.destroy()
      'narrow:next-item': => @getUI()?.nextItem()
      'narrow:previous-item': => @getUI()?.previousItem()

  getUI: (narrowEditor) ->
    UI ?= require './ui'
    UI.uiByNarrowEditor.get(@currentNarrowEditor)

  # Return currently selected text or word under cursor.
  getCurrentWord: ->
    getCurrentWord ?= require('./utils').getCurrentWord
    getCurrentWord(atom.workspace.getActiveTextEditor())

  narrow: (providerName, uiOptions, providerOptions) ->
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

  search: (word = null, projects = atom.project.getPaths()) ->
    if word?
      @narrow('search', initialKeyword: word, {word, projects})
    else
      @readInput().then (input) => @search(input, projects)

  atomScan: (word = null) ->
    if word?
      @narrow('atom-scan', initialKeyword: word, {word})
    else
      @readInput().then (input) => @atomScan(input)

  readInput: ->
    @input ?= new(require './input')
    @input.readInput()

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

      # @subscriptions.add vimState.modeManager.onDidActivateMode ({mode, submode}) ->
      #   if mode is 'insert' and editor.getCursorBufferPosition().row isnt 0
      #     editor.setCursorBufferPosition([0, Infinity]) # auto move to EOL of first line.

    confirmSearch = -> # return search text
      editor = atom.workspace.getActiveTextEditor()
      vimState = getEditorState(editor)
      text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      return text

    @subscriptions.add atom.commands.add 'atom-text-editor.vim-mode-plus-search',
      'vim-mode-plus-user:narrow-lines-from-search': => @narrow('lines', input: confirmSearch())
      'vim-mode-plus-user:narrow-search': => @search(confirmSearch())
      'vim-mode-plus-user:narrow-search-current-project': => @searchCurrentProject(confirmSearch())
