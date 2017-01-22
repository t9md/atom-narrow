{CompositeDisposable} = require 'atom'
settings = require './settings'
UI = null
getCurrentWordAndBoundary = null # delay

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
      'narrow:lines-by-current-word': => @narrow('lines', uiInput: @getCurrentWord())

      'narrow:fold': => @narrow('fold')
      'narrow:fold-by-current-word': => @narrow('fold', uiInput: @getCurrentWord())

      'narrow:symbols': => @narrow('symbols')
      'narrow:git-diff': => @narrow('git-diff')
      'narrow:bookmarks': => @narrow('bookmarks')

      'narrow:search': => @search()
      'narrow:search-by-current-word': => @search(@searchOptionsForCurrentWord())

      'narrow:search-current-project': => @searchCurrentProject()
      'narrow:search-current-project-by-current-word': => @searchCurrentProject(@searchOptionsForCurrentWord())

      'narrow:atom-scan': => @atomScan()
      'narrow:atom-scan-by-current-word': => @atomScan(@searchOptionsForCurrentWord())

      'narrow:focus': => @getUI()?.focus()
      'narrow:close': => @getUI()?.destroy()
      'narrow:next-item': => @getUI()?.nextItem()
      'narrow:previous-item': => @getUI()?.previousItem()

  getUI: (narrowEditor) ->
    UI ?= require './ui'
    UI.uiByNarrowEditor.get(@currentNarrowEditor)

  # Return currently selected text or word under cursor.
  getCurrentWord: ->
    @getCurrentWordAndBoundary().word

  getCurrentWordAndBoundary: ->
    getCurrentWordAndBoundary ?= require('./utils').getCurrentWordAndBoundary
    getCurrentWordAndBoundary(atom.workspace.getActiveTextEditor())

  searchOptionsForCurrentWord: ->
    {word, boundary} = @getCurrentWordAndBoundary()
    {search: word, wordOnly: boundary}

  narrow: (providerName, options) ->
    if providerName not of @providers
      @providers[providerName] = require("./provider/#{providerName}")
    klass = @providers[providerName]
    new klass(options)

  searchCurrentProject: (options={}) ->
    projects = null
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    for dir in atom.project.getDirectories() when dir.contains(editor.getPath())
      projects = [dir.getPath()]
      break

    unless projects?
      message = "#{editor.getPath()} not belonging to any project"
      atom.notifications.addInfo(message, dismissable: true)
      return

    options.projects = projects
    @search(options)

  search: (options = {}) ->
    if options.search
      if options.useAtomScan
        delete options.useAtomScan
        @narrow('atom-scan', options)
      else
        @narrow('search', options)
    else
      @readInput().then (input) =>
        options.search = input
        @search(options)

  atomScan: (options = {}) ->
    options.useAtomScan = true
    @search(options)

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
