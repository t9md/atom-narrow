const {CompositeDisposable, Disposable} = require("atom")
const settings = require("./settings")
const Ui = require("./ui")
const globalSubscriptions = require("./global-subscriptions")
const ProviderBase = require("./provider/provider-base")

const {isNarrowEditor, getVisibleEditors, isTextEditor, suppressEvent} = require("./utils")
module.exports = {
  config: settings.config,
  lastFocusedNarrowEditor: null,

  serialize() {
    return {
      queryHistory: Ui.queryHistory.serialize(),
    }
  },

  activate(restoredState) {
    Ui.queryHistory.deserialize(restoredState.queryHistory)
    let subs = new CompositeDisposable()
    this.subscriptions = subs

    subs.add(this.observeStopChangingActivePaneItem())
    subs.add(this.registerCommands())

    const onMouseDown = this.onMouseDown.bind(this)
    subs.add(
      atom.workspace.observeTextEditors(editor => {
        let sub
        editor.element.addEventListener("mousedown", onMouseDown, true)
        const removeListener = () => editor.element.removeEventListener("mousedown", onMouseDown, true)
        subs.add((sub = new Disposable(removeListener)))
        editor.onDidDestroy(() => subs.remove(sub))
      })
    )
  },

  isControlBarElementClick(event) {
    const ui = Ui.get(event.currentTarget.getModel())
    return ui ? ui.controlBar.containsElement(event.target) : false
  },

  onMouseDown(event) {
    if (event.detail !== 2) return // handle double click only

    if (!Ui.getSize()) {
      if (settings.get("Search.startByDoubleClick")) {
        this.narrow("search", {queryCurrentWord: true, focus: false})
        suppressEvent(event)
      }
    } else {
      if (settings.get("queryCurrentWordByDoubleClick") && !this.isControlBarElementClick(event)) {
        suppressEvent(event)
        this.getUi().queryCurrentWord()
      }
    }
  },

  deactivate() {
    globalSubscriptions.dispose()
    if (this.subscriptions) this.subscriptions.dispose()
    this.subscriptions = null
  },

  registerCommands() {
    const getUi = fn => {
      const ui = this.getUi()
      if (ui) fn(ui)
    }

    // prettier-ignore
    return atom.commands.add("atom-text-editor", {
      // Shared commands
      "narrow:activate-package": () => {}, // HACK activate via atom.command.dispatch with the mechanism of activationCommands
      "narrow:focus": () => getUi(ui => ui.toggleFocus()),
      "narrow:focus-prompt": () => getUi(ui => ui.focusPrompt()),
      "narrow:refresh": () => getUi(ui => ui.refreshManually()),
      "narrow:close": () => {
        const ui = this.getUi({skipProtected: true})
        if (ui) ui.close()
      },
      "narrow:next-item": () => getUi(ui => ui.confirmItemForDirection("next")),
      "narrow:previous-item": () => getUi(ui => ui.confirmItemForDirection("previous")),
      "narrow:next-query-history": () => getUi(ui => ui.setQueryFromHistroy("next")),
      "narrow:previous-query-history": () => getUi(ui => ui.setQueryFromHistroy("previous")),
      "narrow:reopen": () => this.reopen(),
      "narrow:query-current-word": () => getUi(ui => ui.queryCurrentWord()),

      // Providers
      // -------------------------
      "narrow:symbols": () => this.narrow("symbols"),
      "narrow:symbols-by-current-word": () => this.narrow("symbols", {queryCurrentWord: true}),

      "narrow:project-symbols": () => this.narrow("project-symbols"),
      "narrow:project-symbols-by-current-word": () => this.narrow("project-symbols", {queryCurrentWord: true}),

      "narrow:git-diff-all": () => this.narrow("git-diff-all"),

      "narrow:fold": () => this.narrow("fold"),
      "narrow:fold-by-current-word": () => this.narrow("fold", {queryCurrentWord: true}),

      "narrow:scan": () => this.narrow("scan"),
      "narrow:scan-by-current-word": () => this.narrow("scan", {queryCurrentWord: true}),

      // search family
      "narrow:search": () => this.narrow("search"),
      "narrow:search-by-current-word": () => this.narrow("search", {queryCurrentWord: true}),
      "narrow:search-by-current-word-without-focus": () => this.narrow("search", {queryCurrentWord: true, focus: false}),
      "narrow:search-current-project": () => this.narrow("search", {currentProject: true}),
      "narrow:search-current-project-by-current-word": () => this.narrow("search", {currentProject: true, queryCurrentWord: true}),

      "narrow:atom-scan": () => this.narrow("atom-scan"),
      "narrow:atom-scan-by-current-word": () => this.narrow("atom-scan", {queryCurrentWord: true}),

      "narrow:toggle-search-start-by-double-click": () => settings.toggle("Search.startByDoubleClick"),
    })
  },

  observeStopChangingActivePaneItem() {
    return atom.workspace.onDidStopChangingActivePaneItem(item => {
      if (!isTextEditor(item)) return

      if (isNarrowEditor(item)) {
        this.lastFocusedNarrowEditor = item
        return
      }

      Ui.forEach((ui, editor) => {
        // When non-narrow-editor editor was activated
        // no longer restore editor's state at cancel.
        ui.provider.needRestoreEditorState = false
        if (!ui.isSamePaneItem(item)) ui.startSyncToEditor(item)

        ui.highlighter.clearCurrentAndLineMarker()
        ui.highlighter.highlightEditor(item)
      })
    })
  },

  getUi({skipProtected} = {}) {
    const ui = Ui.get(this.lastFocusedNarrowEditor)
    if (ui) {
      if (skipProtected) {
        if (!ui.protected) return ui
      } else {
        return ui
      }
    }

    const visibleEditors = getVisibleEditors()
    let invisibleNarrowEditor = null
    let narrowEditors = atom.workspace.getTextEditors().filter(isNarrowEditor)
    if (skipProtected) {
      const isNotProtected = editor => !Ui.get(editor).protected
      narrowEditors = narrowEditors.filter(isNotProtected)
    }

    for (const editor of narrowEditors) {
      if (visibleEditors.includes(editor)) {
        return Ui.get(editor)
      } else {
        if (!invisibleNarrowEditor) invisibleNarrowEditor = editor
      }
    }
    if (invisibleNarrowEditor) return Ui.get(invisibleNarrowEditor)
  },

  reopen() {
    ProviderBase.reopen()
  },

  narrow(...args) {
    ProviderBase.start(...args)
  },

  consumeVim({getEditorState, observeVimStates}) {
    if (!settings.get("notifiedVimModePlusSpecificDefaultKeymap")) {
      settings.set("notifiedVimModePlusSpecificDefaultKeymap", true)
      const message = [
        "## narrow",
        "- From v0.53.0, vim-mode-plus specific default keymaps are remove to avoid conflicts with vim-mode-plus's keymaps",
        "- You can restore older version keymap manually, see [wiki](https://github.com/t9md/atom-narrow/wiki/ExampleKeymap#restore-vim-mode-plus-specific-default-keymap-defined-old-version)",
      ].join("\n")
      atom.notifications.addWarning(message, {dismissable: true})
    }

    let ui
    this.subscriptions.add(
      observeVimStates(vimState => {
        if (!isNarrowEditor(vimState.editor)) return

        vimState.onDidActivateMode(({mode, submode}) => {
          switch (mode) {
            case "insert":
              ui = Ui.get(vimState.editor)
              if (ui) ui.setReadOnly(false)
              break
            case "normal":
              ui = Ui.get(vimState.editor)
              if (ui) ui.setReadOnly(true)
              break
          }
        })
      })
    )

    // return search text
    function confirmSearch() {
      const editor = atom.workspace.getActiveTextEditor()
      const vimState = getEditorState(editor)
      const text = vimState.searchInput.editor.getText()
      vimState.searchInput.confirm()
      atom.commands.dispatch(vimState.editorElement, "vim-mode-plus:clear-highlight-search")
      return text
    }

    // prettier-ignore
    return this.subscriptions.add(
      atom.commands.add("atom-text-editor.vim-mode-plus-search", {
        "vim-mode-plus-user:narrow:scan": () => this.narrow("scan", {query: confirmSearch()}),
        "vim-mode-plus-user:narrow:search": () => this.narrow("search", {query: confirmSearch()}),
        "vim-mode-plus-user:narrow:atom-scan": () => this.narrow("atom-scan", {query: confirmSearch()}),
        "vim-mode-plus-user:narrow:search-current-project": () => this.narrow("search", {query: confirmSearch(), currentProject: true}),
      })
    )
  },

  registerProvider(name, klassOrFilePath) {
    ProviderBase.registerProvider(name, klassOrFilePath)
  },

  provideNarrow() {
    return {
      ProviderBase,
      registerProvider: this.registerProvider.bind(this),
      narrow: this.narrow.bind(this),
    }
  },
}
