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
      # Shared commands
      'narrow:focus': => @getUi()?.focus()
      'narrow:close': => @getUi()?.destroy()
      'narrow:next-item': => @getUi()?.nextItem()
      'narrow:previous-item': => @getUi()?.previousItem()

      # Providers
      'narrow:lines': => @narrow('lines')
      'narrow:fold': => @narrow('fold')
      'narrow:symbols': => @narrow('symbols')
      'narrow:git-diff': => @narrow('git-diff')
      'narrow:bookmarks': => @narrow('bookmarks')
      'narrow:linter': => @narrow('linter')

      'narrow:lines-by-current-word': => @narrow('lines', uiInput: @getCurrentWord())
      'narrow:fold-by-current-word': => @narrow('fold', uiInput: @getCurrentWord())

      # search family
      'narrow:search': => @narrow('search')
      'narrow:search-by-current-word': => @narrow('search', currentWord: true)

      'narrow:search-current-project': => @narrow('search', currentProject: true)
      'narrow:search-current-project-by-current-word': => @narrow('search', currentProject: true, currentWord: true)

      'narrow:atom-scan': => @narrow('atom-scan')
      'narrow:atom-scan-by-current-word': => @narrow('atom-scan', currentWord: true)

  getUi: ->
    @getUiForEditor(@currentNarrowEditor)

  getUiForEditor: (editor) ->
    Ui ?= require './ui'
    Ui.uiByNarrowEditor.get(editor)

  # Return currently selected text or word under cursor.
  getCurrentWord: ->
    getCurrentWord ?= require('./utils').getCurrentWord
    getCurrentWord(atom.workspace.getActiveTextEditor())

  narrow: (providerName, options) ->
    klass = require("./provider/#{providerName}")
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
      if @isNarrowEditor(editor) and ui = @getUiForEditor(editor)
        if settings.get('vmpStartInInsertModeForUI')
          vimState.activate('insert') unless vimState.isMode('insert')

        if settings.get('vmpAutoChangeModeInUI')
          ui.autoChangeModeForVimState(vimState)

        atom.commands.add ui.editorElement,
          'vim-mode-plus-user:narrow-ui:move-to-prompt': ->
            ui.moveToPrompt()
            vimState.activate('insert') unless vimState.isMode('insert')

    confirmSearch = -> # return search text
      editor = atom.workspace.getActiveTextEditor()
      vimState = getEditorState(editor)
      text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      return text

    @subscriptions.add atom.commands.add 'atom-text-editor.vim-mode-plus-search',
      'vim-mode-plus-user:narrow:lines': => @narrow('lines', uiInput: confirmSearch())
      'vim-mode-plus-user:narrow:search': => @narrow('search', search: confirmSearch())
      'vim-mode-plus-user:narrow:atom-scan': => @narrow('atom-scan', search: confirmSearch())
      'vim-mode-plus-user:narrow:search-current-project': =>  @narrow('search', search: confirmSearch(), currentProject: true)
