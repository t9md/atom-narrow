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
      'narrow:focus': => @getUi()?.toggleFocus()
      'narrow:focus-prompt': => @getUi()?.focusPrompt()
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
    (Ui ?= require './ui').get(editor)

  # Return currently selected text or word under cursor.
  getCurrentWord: ->
    getCurrentWord ?= require('./utils').getCurrentWord
    getCurrentWord(atom.workspace.getActiveTextEditor())

  narrow: (providerName, options) ->
    klass = require("./provider/#{providerName}")
    editor = atom.workspace.getActiveTextEditor()
    new klass(editor, options)

  deactivate: ->
    @subscriptions?.dispose()
    {@subscriptions} = {}

  isNarrowEditor: (item) ->
    atom.workspace.isTextEditor(item) and
      item.element.classList.contains('narrow-editor')

  consumeVim: ({getEditorState}) ->
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
