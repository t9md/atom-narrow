{CompositeDisposable} = require 'atom'
settings = require './settings'
Ui = null
getCurrentWord = null # delay

module.exports =
  config: settings.config
  currentNarrowEditor: null
  providers: []

  activate: ->
    @subscriptions = new CompositeDisposable
    settings.removeDeprecated()

    @subscriptions.add atom.workspace.observeActivePaneItem (item) =>
      if @isNarrowEditor(item)
        @currentNarrowEditor = item

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'narrow:lines': => @narrow('lines')
      'narrow:lines-by-current-word': => @narrow('lines', uiInput: @getCurrentWord())

      'narrow:fold': => @narrow('fold')
      'narrow:fold-by-current-word': => @narrow('fold', uiInput: @getCurrentWord())

      'narrow:symbols': => @narrow('symbols')
      'narrow:git-diff': => @narrow('git-diff')
      'narrow:bookmarks': => @narrow('bookmarks')

      'narrow:search': => @narrow('search')
      'narrow:search-by-current-word': => @narrow('search', currentWord: true)

      'narrow:search-current-project': => @narrow('search', currentProject: true)
      'narrow:search-current-project-by-current-word': => @narrow('search', currentProject: true, currentWord: true)

      'narrow:atom-scan': => @narrow('atom-scan')
      'narrow:atom-scan-by-current-word': => @narrow('atom-scan', currentWord: true)

      'narrow:focus': => @getUi()?.focus()
      'narrow:close': => @getUi()?.destroy()
      'narrow:next-item': => @getUi()?.nextItem()
      'narrow:previous-item': => @getUi()?.previousItem()

  getUi: ->
    Ui ?= require './ui'
    Ui.uiByNarrowEditor.get(@currentNarrowEditor)

  # Return currently selected text or word under cursor.
  getCurrentWord: ->
    getCurrentWord ?= require('./utils').getCurrentWord
    getCurrentWord(atom.workspace.getActiveTextEditor())

  narrow: (providerName, options) ->
    if providerName not of @providers
      @providers[providerName] = require("./provider/#{providerName}")
    klass = @providers[providerName]
    new klass(options)

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  isNarrowEditor: (item) ->
    atom.workspace.isTextEditor(item) and
      item.element.classList.contains('narrow-editor')

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
      'vim-mode-plus-user:narrow-lines-from-search': => @narrow('lines', uiInput: confirmSearch())
      'vim-mode-plus-user:narrow-search': => @narrow('search', search: confirmSearch())
      'vim-mode-plus-user:narrow-search-current-project': =>  @narrow('search', search: confirmSearch(), currentProject: true)
