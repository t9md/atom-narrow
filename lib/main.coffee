{CompositeDisposable, Disposable} = require 'atom'
settings = require './settings'
Ui = require './ui'
globalSubscriptions = require './global-subscriptions'
ProviderBase = require "./provider/provider-base"

{isNarrowEditor, getVisibleEditors, isTextEditor, suppressEvent} = require './utils'

module.exports =
  config: settings.config
  lastFocusedNarrowEditor: null
  serialize: ->
    {
      queryHistory: Ui.queryHistory.serialize()
    }

  activate: (restoredState) ->
    Ui.queryHistory.deserialize(restoredState.queryHistory)

    @subscriptions = subs = new CompositeDisposable

    subs.add(@observeStopChangingActivePaneItem())
    subs.add(@registerCommands())

    onMouseDown = @onMouseDown.bind(this)
    subs.add atom.workspace.observeTextEditors (editor) ->
      editor.element.addEventListener('mousedown', onMouseDown, true)
      removeListener = -> editor.element.removeEventListener('mousedown', onMouseDown, true)
      subs.add(sub = new Disposable(removeListener))
      editor.onDidDestroy -> subs.remove(sub)

  isControlBarElementClick: (event) ->
    editor = event.currentTarget.getModel()
    Ui.get(editor)?.controlBar.containsElement(event.target)

  onMouseDown: (event) ->
    return unless event.detail is 2 # handle double click only

    if not Ui.getSize()
      if settings.get('Search.startByDoubleClick')
        @narrow('Search', queryCurrentWord: true, focus: false)
        suppressEvent(event)
    else
      if settings.get('queryCurrentWordByDoubleClick') and not @isControlBarElementClick(event)
        suppressEvent(event)
        @getUi()?.queryCurrentWord()

  deactivate: ->
    globalSubscriptions.dispose()
    @subscriptions?.dispose()
    {@subscriptions} = {}

  registerCommands: ->
    atom.commands.add 'atom-text-editor',
      # Shared commands
      'narrow:focus': => @getUi()?.toggleFocus()
      'narrow:focus-prompt': => @getUi()?.focusPrompt()
      'narrow:refresh': => @getUi()?.refreshManually()
      'narrow:close': => @getUi(skipProtected: true)?.close()
      'narrow:next-item': => @getUi()?.confirmItemForDirection('next')
      'narrow:previous-item': => @getUi()?.confirmItemForDirection('previous')
      'narrow:next-query-history': => @getUi()?.setQueryFromHistroy('next')
      'narrow:previous-query-history': => @getUi()?.setQueryFromHistroy('previous')
      'narrow:reopen': => @reopen()
      'narrow:query-current-word': => @getUi()?.queryCurrentWord()

      # Providers
      # -------------------------
      'narrow:symbols': => @narrow('Symbols')
      'narrow:symbols-by-current-word': => @narrow('Symbols', queryCurrentWord: true)

      'narrow:project-symbols': => @narrow('ProjectSymbols')
      'narrow:project-symbols-by-current-word': => @narrow('ProjectSymbols', queryCurrentWord: true)

      'narrow:git-diff-all': => @narrow('GitDiffAll')

      'narrow:fold': => @narrow('Fold')
      'narrow:fold-by-current-word': => @narrow('Fold', queryCurrentWord: true)

      'narrow:scan': => @narrow('Scan')
      'narrow:scan-by-current-word': => @narrow('Scan', queryCurrentWord: true)

      # search family
      'narrow:search': => @narrow('Search')
      'narrow:search-by-current-word': => @narrow('Search', queryCurrentWord: true)
      'narrow:search-by-current-word-without-focus': => @narrow('Search', queryCurrentWord: true, focus: false)
      'narrow:search-current-project': => @narrow('Search', currentProject: true)
      'narrow:search-current-project-by-current-word': => @narrow('Search', currentProject: true, queryCurrentWord: true)

      'narrow:atom-scan': => @narrow('AtomScan')
      'narrow:atom-scan-by-current-word': => @narrow('AtomScan', queryCurrentWord: true)

      'narrow:toggle-search-start-by-double-click': -> settings.toggle('Search.startByDoubleClick')

  observeStopChangingActivePaneItem: ->
    atom.workspace.onDidStopChangingActivePaneItem (item) =>
      return unless isTextEditor(item)

      if isNarrowEditor(item)
        @lastFocusedNarrowEditor = item
        return

      Ui.forEach (ui, editor) ->
        # When non-narrow-editor editor was activated
        # no longer restore editor's state at cancel.
        ui.provider.needRestoreEditorState = false
        ui.startSyncToEditor(item) unless ui.isSamePaneItem(item)

        ui.highlighter.clearCurrentAndLineMarker()
        ui.highlighter.highlightEditor(item)

  getUi: ({skipProtected}={}) ->
    if ui = Ui.get(@lastFocusedNarrowEditor)
      if skipProtected
        return ui unless ui.protected
      else
        return ui

    visibleEditors = getVisibleEditors()
    invisibleNarrowEditor = null
    narrowEditors = atom.workspace.getTextEditors().filter (editor) -> isNarrowEditor(editor)
    if skipProtected
      narrowEditors = narrowEditors.filter (editor) -> not Ui.get(editor).protected

    for editor in narrowEditors
      if editor in visibleEditors
        return Ui.get(editor)
      else
        invisibleNarrowEditor ?= editor
    Ui.get(invisibleNarrowEditor) if invisibleNarrowEditor?

  reopen: ->
    ProviderBase.reopen()

  narrow: (args...) ->
    ProviderBase.start(args...)

  consumeVim: ({getEditorState, observeVimStates}) ->
    @subscriptions.add observeVimStates (vimState) ->
      if isNarrowEditor(vimState.editor)
        vimState.modeManager.onDidActivateMode ({mode, submode}) ->
          switch mode
            when 'insert'
              Ui.get(vimState.editor)?.setReadOnly(false)
            when 'normal'
              Ui.get(vimState.editor)?.setReadOnly(true)

    confirmSearch = -> # return search text
      editor = atom.workspace.getActiveTextEditor()
      vimState = getEditorState(editor)
      text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      atom.commands.dispatch(vimState.editorElement, 'vim-mode-plus:clear-highlight-search')
      return text

    @subscriptions.add atom.commands.add 'atom-text-editor.vim-mode-plus-search',
      'vim-mode-plus-user:narrow:scan': =>  @narrow('Scan', query: confirmSearch())
      'vim-mode-plus-user:narrow:search': => @narrow('Search', query: confirmSearch())
      'vim-mode-plus-user:narrow:atom-scan': => @narrow('AtomScan', query: confirmSearch())
      'vim-mode-plus-user:narrow:search-current-project': =>  @narrow('Search', query: confirmSearch(), currentProject: true)

  provideNarrow: ->
    ProviderBase: ProviderBase
    settings: settings
    narrow: @narrow.bind(this)
