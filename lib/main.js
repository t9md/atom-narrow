const {CompositeDisposable, Disposable} = require('atom')
const settings = require('./settings')
const Ui = require('./ui')
const globalSubscriptions = require('./global-subscriptions')
const Provider = require('./provider/provider')

const {getVisibleEditors, suppressEvent, isTextEditor, paneForItem} = require('./utils')
module.exports = {
  config: settings.config,

  serialize () {
    return Ui.serialize()
  },

  activate (state) {
    Ui.deserialize(state)
    const onMouseDown = this.onMouseDown.bind(this)
    this.subscriptions = new CompositeDisposable()
    this.subscriptions.add(
      ...this.observeAddItemToPane(),
      this.observeStopChangingActivePaneItem(),
      this.registerCommands(),
      atom.workspace.observeTextEditors(editor => {
        let sub
        editor.element.addEventListener('mousedown', onMouseDown, true)
        const removeListener = () => editor.element.removeEventListener('mousedown', onMouseDown, true)
        this.subscriptions.add((sub = new Disposable(removeListener)))
        editor.onDidDestroy(() => this.subscriptions.remove(sub))
      })
    )
  },

  observeAddItemToPane () {
    const containers = [atom.workspace.getCenter(), atom.workspace.getBottomDock()]
    return containers.map(paneContainer =>
      paneContainer.onDidChangeActivePaneItem(item => {
        if (Ui.has(item)) {
          Ui.get(item).onDidBecomeActivePaneItem()
        }
      })
    )
  },

  isControlBarElementClick (event) {
    const ui = Ui.get(event.currentTarget.getModel())
    return ui ? ui.controlBar.containsElement(event.target) : false
  },

  onMouseDown (event) {
    if (event.detail !== 2) return // handle double click only

    if (!Ui.getSize()) {
      if (settings.get('Search.startByDoubleClick')) {
        suppressEvent(event)
        this.narrow('search', {queryCurrentWord: true, focus: false})
      }
    } else {
      if (settings.get('queryCurrentWordByDoubleClick') && !this.isControlBarElementClick(event)) {
        suppressEvent(event)
        this.getUi().setQueryFromCurrentWord()
      }
    }
  },

  deactivate () {
    globalSubscriptions.dispose()
    if (this.subscriptions) this.subscriptions.dispose()
  },

  registerCommands () {
    const getUi = fn => {
      const ui = this.getUi()
      if (ui) fn(ui)
    }

    // prettier-ignore
    return atom.commands.add('atom-text-editor', {
      // Shared commands
      'narrow:activate-package': () => {}, // HACK activate via atom.command.dispatch with the mechanism of activationCommands
      'narrow:focus': () => getUi(ui => ui.toggleFocus()),
      'narrow:focus-prompt': () => getUi(ui => ui.focusPrompt()),
      'narrow:refresh': () => getUi(ui => ui.refreshManually()),
      'narrow:close': () => {
        const ui = this.getUi({skipProtected: true})
        if (ui) ui.close()
      },
      'narrow:next-item': () => getUi(ui => ui.confirmItemForDirection('next')),
      'narrow:previous-item': () => getUi(ui => ui.confirmItemForDirection('previous')),
      'narrow:next-query-history': () => getUi(ui => ui.setQueryFromHistroy('next')),
      'narrow:previous-query-history': () => getUi(ui => ui.setQueryFromHistroy('previous')),
      'narrow:reopen': () => this.reopen(),
      'narrow:query-current-word': () => getUi(ui => ui.setQueryFromCurrentWord()),

      // Providers
      // -------------------------
      'narrow:symbols': () => this.narrow('symbols'),
      'narrow:symbols-by-current-word': () => this.narrow('symbols', {queryCurrentWord: true}),

      'narrow:project-symbols': () => this.narrow('project-symbols'),
      'narrow:project-symbols-by-current-word': () => this.narrow('project-symbols', {queryCurrentWord: true}),

      'narrow:git-diff-all': () => this.narrow('git-diff-all'),

      'narrow:fold': () => this.narrow('fold'),
      'narrow:fold-by-current-word': () => this.narrow('fold', {queryCurrentWord: true}),

      'narrow:scan': () => this.narrow('scan'),
      'narrow:scan-by-current-word': () => this.narrow('scan', {queryCurrentWord: true}),

      // search family
      'narrow:search': () => this.narrow('search'),
      'narrow:search-by-current-word': () => this.narrow('search', {queryCurrentWord: true}),
      'narrow:search-by-current-word-without-focus': () => this.narrow('search', {queryCurrentWord: true, focus: false}),
      'narrow:search-current-project': () => this.narrow('search', {currentProject: true}),
      'narrow:search-current-project-by-current-word': () => this.narrow('search', {currentProject: true, queryCurrentWord: true}),

      'narrow:atom-scan': () => this.narrow('atom-scan'),
      'narrow:atom-scan-by-current-word': () => this.narrow('atom-scan', {queryCurrentWord: true}),

      'narrow:toggle-search-start-by-double-click': () => settings.toggle('Search.startByDoubleClick')
    })
  },

  observeStopChangingActivePaneItem () {
    return atom.workspace.onDidStopChangingActivePaneItem(item => {
      if (!isTextEditor(item)) return

      if (Ui.has(item)) {
        const ui = Ui.get(item)
        this.lastFocusedUi = ui
        if (!ui.isOpening() && !ui.narrowEditor.isAtPrompt() && ui.autoPreview) {
          ui.previewWithDelay()
        }
      } else {
        // Normal text-editor was focused
        Ui.forEach(ui => {
          ui.provider.needRestoreEditorState = false
          if (paneForItem(item) !== ui.getPane()) {
            ui.startSyncToEditor(item)
          }
          ui.highlighter.clearCurrentAndLineMarker()
          ui.highlighter.highlightEditor(item)
        })
      }
    })
  },

  // Return Ui exists in workspace in follwing order
  //  1. Last focused
  //  2. Visible
  //  3. Invisisible
  getUi ({skipProtected} = {}) {
    const ui = this.lastFocusedUi
    if (ui && ui.isAlive() && !(skipProtected && ui.protected)) {
      return ui
    }

    let invisibleUi
    const narrowEditors = atom.workspace.getTextEditors().filter(editor => Ui.has(editor))
    const visibleEditors = getVisibleEditors()
    for (const editor of narrowEditors) {
      const ui = Ui.get(editor)
      if (skipProtected && ui.protected) {
        continue
      }

      if (visibleEditors.includes(editor)) {
        return ui
      }
      if (!invisibleUi) {
        invisibleUi = ui
      }
    }
    if (invisibleUi) {
      return invisibleUi
    }
  },

  reopen () {
    Provider.reopen()
  },

  // Return promise
  narrow (name, options) {
    return Provider.start(name, options)
  },

  consumeVim ({getEditorState, observeVimStates}) {
    this.subscriptions.add(
      observeVimStates(vimState => {
        // Why `Ui.has` check here to determine if it's narrow-editor is OK?
        // Ui.register(ui) is always called before creating vimState from ui.editor.
        // Thus, if editor is narrow-editor, it should be registered at this timing.
        if (!Ui.has(vimState.editor)) return

        vimState.onDidActivateMode(({mode, submode}) => {
          if (mode === 'insert') {
            const ui = Ui.get(vimState.editor)
            if (ui) ui.narrowEditor.setReadOnly(false)
          } else if (mode === 'normal') {
            const ui = Ui.get(vimState.editor)
            if (ui) ui.narrowEditor.setReadOnly(true)
          }
        })
      })
    )

    // return search text
    function confirmSearch () {
      const editor = atom.workspace.getActiveTextEditor()
      const vimState = getEditorState(editor)
      const text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      atom.commands.dispatch(vimState.editorElement, 'vim-mode-plus:clear-highlight-search')
      return text
    }

    this.subscriptions.add(
      atom.commands.add('atom-text-editor.vim-mode-plus-search', {
        'vim-mode-plus-user:narrow:scan': () => this.narrow('scan', {query: confirmSearch()}),
        'vim-mode-plus-user:narrow:search': () => this.narrow('search', {query: confirmSearch()}),
        'vim-mode-plus-user:narrow:atom-scan': () => this.narrow('atom-scan', {query: confirmSearch()}),
        'vim-mode-plus-user:narrow:search-current-project': () =>
          this.narrow('search', {query: confirmSearch(), currentProject: true})
      })
    )
  },

  consumeInlineGitDiff (service) {
    Provider.setService({inlineGitDiff: service})
  },

  registerProvider (name, klass) {
    Provider.registerProvider(name, klass)
  },

  provideNarrow () {
    return {
      Provider: Provider,
      registerProvider: this.registerProvider.bind(this),
      narrow: this.narrow.bind(this)
    }
  }
}
