const _ = require('underscore-plus')
const {CompositeDisposable} = require('atom')
const {
  saveEditorState,
  saveVmpPaneMaximizedState,
  isActiveEditor,
  paneForItem,
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  getCurrentWord,
  getActiveEditor
} = require('../utils')
const Ui = require('../ui')
const settings = require('../settings')
const SearchOptions = require('../search-options')
const ScopedConfig = require('../scoped-config')

const Config = {
  needRestoreEditorState: true,
  boundToSingleFile: false,

  showProjectHeader: false,
  showFileHeader: false,
  showColumnOnLineHeader: false,
  itemHaveRange: false,

  supportDirectEdit: false,
  supportCacheItems: false,
  supportReopen: true,
  supportFilePathOnlyItemsUpdate: false,

  refreshOnDidStopChanging: false,
  refreshOnDidSave: false,

  // used by scan, search, atom-scan,
  showSearchOption: false,

  queryWordBoundaryOnByCurrentWordInvocation: false,
  useFirstQueryAsSearchTerm: false
}

class Provider {
  static initClass () {
    this.destroyedProviderStates = []
    this.providerByName = new Map()
    this.reopenableMax = 10
    this.service = {}
  }

  // Keep service by name
  // service must be object like `{inlineGitDiff: service}`
  static setService (service) {
    Object.assign(this.service, service)
  }

  static reopen () {
    const stateAtDestroyed = this.destroyedProviderStates.shift()
    if (stateAtDestroyed) {
      const {name, options, state} = stateAtDestroyed
      return this.start(name, options, state)
    }
  }

  static create (options = {}) {
    const editor = getActiveEditor()
    return new Provider(editor, options)
  }

  static async start (name, options = {}, state) {
    if (!this.providerByName.has(name)) {
      this.providerByName.set(name, require(`./${name}`))
    }
    const Klass = this.providerByName.get(name)
    if (Klass) {
      return new Klass(state).start(options)
    } else {
      throw new Error(`Provier ${name} not available`)
    }
  }

  static registerProvider (name, provider) {
    if (typeof provider === 'function') {
      this.providerByName.set(name, provider)
    } else {
      throw new Error('provider must be or function')
    }
  }

  static saveState (state) {
    this.destroyedProviderStates.unshift(state)
    this.destroyedProviderStates.splice(this.reopenableMax)
  }

  getConfig (name) {
    return this.scopedConfig.get(name)
  }

  setConfig (name, value) {
    return this.scopedConfig.set(name, value)
  }

  getOnStartConditionValueFor (name) {
    const value = this.getConfig(name)
    if (value === 'never') return false
    if (value === 'always') return true
    if (value === 'on-input') return this.query
    if (value === 'no-input') return !this.query
  }

  needRevealOnStart () {
    return this.getOnStartConditionValueFor('revealOnStartCondition')
  }

  needFocusOnStart () {
    return this.getOnStartConditionValueFor('focusOnStartCondition')
  }

  buildSearchOptionsProps ({queryCurrentWord}) {
    return {
      searchWholeWord:
        (queryCurrentWord && this.clientEditor.getSelectedBufferRange().isEmpty()) || this.getConfig('searchWholeWord'),
      searchUseRegex: this.getConfig('searchUseRegex')
    }
  }

  bindEditor (editor) {
    if (editor === this.editor) return

    if (this.editorSubscriptions) this.editorSubscriptions.dispose()
    this.editorSubscriptions = new CompositeDisposable()
    const oldEditor = this.editor
    this.editor = editor
    this.callHook('didBindEditor', {
      newEditor: editor,
      oldEditor: oldEditor
    })
  }

  getPane () {
    // If editor was pending item, it will be destroyed on next pending-item opened
    const pane = paneForItem(this.editor)
    if (pane && pane.isAlive()) {
      this.lastPane = pane
    }

    if (this.lastPane && this.lastPane.isAlive()) {
      return this.lastPane
    }
  }

  isActive () {
    return isActiveEditor(this.editor)
  }

  getState () {
    let providerState = {}
    if (this.searchOptions) {
      Object.assign(providerState, {
        searchOptionState: this.searchOptions.getState()
      })
    }
    Object.assign(providerState, this.callHook('willSaveState'))

    return {
      name: this.dashName,
      options: {query: this.ui.lastQuery},
      state: {
        provider: providerState,
        ui: this.ui.getState()
      }
    }
  }

  constructor (editor, options = {}) {
    this.clientEditor = editor

    Object.assign(this, Config, options.config)

    this.name = options.name
    this.dashName = _.dasherize(this.name)
    this.subscriptions = new CompositeDisposable()
    this.scopedConfig = new ScopedConfig(options.configScope || `narrow.${this.name}`)

    this.getItems = options.getItems
    this.updateItems = this.updateItems.bind(this)

    this.hook = {
      willOpenUi: options.willOpenUi,
      didOpenUi: options.didOpenUi,
      didBindEditor: options.didBindEditor, // called with {newEditor, oldEditor}
      didConfirmItem: options.didConfirmItem,
      didOpenItem: options.didOpenItem,
      willSaveState: options.willSaveState,
      didDestroy: options.didDestroy
    }

    this.restoredState = options.state
    this.reopened = !!this.restoredState

    if (this.restoredState) {
      const providerState = this.restoredState.provider
      this.searchOptionState = providerState.searchOptionState
      delete providerState.searchOptionState
      Object.assign(this, providerState)
    }
  }

  callHook (name, ...args) {
    const hook = this.hook[name]
    if (hook) {
      return hook(...args)
    }
  }

  async start (options = {}) {
    // If invoked from another Ui( narrow-editor ).
    // Bind to original Ui.provider.editor to behaves as if it invoked from normal-editor.
    if (Ui.has(this.clientEditor)) {
      this.bindEditor(Ui.get(this.clientEditor).provider.editor)
    } else {
      this.bindEditor(this.clientEditor)
    }
    this.restoreEditorState = saveEditorState(this.editor)

    if (settings.get('restoreVmpPaneMaximizedStateOnUiClosed')) {
      this.restoreVmpPaneMaximizedState = saveVmpPaneMaximizedState()
    }

    this.query = this.getInitialQuery(this.clientEditor, options)
    if (this.showSearchOption) {
      const props = this.searchOptionState || this.buildSearchOptionsProps(options)
      this.searchOptions = new SearchOptions(this, props)
    }

    const uiState = this.restoredState ? this.restoredState.ui : undefined
    this.ui = new Ui(this, {query: this.query}, uiState)

    this.callHook('willOpenUi')

    await this.ui.open({
      focus: this.needFocusOnStart()
    })

    // When ui was not focused on start(e.g. focusOnStartCondition was set to `never`).
    // We should not restore editor state when if at least some cursor movement happened in client-editor.
    // This observation must come after `this.getInitialQuery()` since it's change cursor position while
    // getting cursor word.
    if (this.ui.isActive()) {
      const clientEditorDisposable = this.clientEditor.onDidChangeCursorPosition(event => {
        clientEditorDisposable.dispose()
        this.needRestoreEditorState = false
      })
    }

    this.callHook('didOpenUi')
    return this
  }

  updateItems (items) {
    this.ui.emitDidUpdateItems(items)
  }

  getInitialQuery (editor, options) {
    let query = options.query || editor.getSelectedText()
    if (!query && options.queryCurrentWord) {
      query = getCurrentWord(editor)
      if (this.queryWordBoundaryOnByCurrentWordInvocation) {
        query = `>${query}<`
      }
    }
    return query
  }

  subscribeEditor (...args) {
    this.editorSubscriptions.add(...args)
  }

  restoreEditorStateIfNecessary (...args) {
    if (this.needRestoreEditorState) this.restoreEditorState(...args)
  }

  restoreVmpPaneMaximizedStateIfNecessary () {
    if (this.restoreVmpPaneMaximizedState) {
      this.restoreVmpPaneMaximizedState()
    }
  }

  destroy () {
    if (this.supportReopen) {
      Provider.saveState(this.getState())
    }

    this.subscriptions.dispose()
    this.editorSubscriptions.dispose()

    this.editor = null
    this.editorSubscriptions = null
    this.callHook('didDestroy')
  }

  // When narrow was invoked from existing narrow-editor.
  //  ( e.g. `narrow:search-by-current-word` on narrow-editor. )
  // ui is opened at same pane of provider.editor( editor invoked narrow )
  // In this case item should be opened on adjacent pane, not on provider.pane.
  getPaneToOpenItem () {
    const pane = this.getPane()
    const paneForUi = this.ui.getPane()
    // const

    if (pane && pane !== paneForUi) {
      return pane
    } else {
      return (
        getPreviousAdjacentPaneForPane(paneForUi) ||
        getNextAdjacentPaneForPane(paneForUi) ||
        splitPane(paneForUi, {split: this.ui.directionToOpen})
      )
    }
  }

  async openFileForItem ({filePath}, {activatePane, pane} = {}) {
    if (!pane) pane = this.getPaneToOpenItem()

    let itemToOpen
    if (this.boundToSingleFile && this.editor.isAlive() && pane === paneForItem(this.editor)) {
      itemToOpen = this.editor
    }

    if (!filePath) filePath = this.editor.getPath()
    if (!itemToOpen) itemToOpen = pane.itemForURI(filePath)

    if (itemToOpen) {
      if (activatePane) pane.activate()
      pane.activateItem(itemToOpen)
    } else {
      itemToOpen = await atom.workspace.open(filePath, {
        pending: true,
        activatePane,
        activateItem: true,
        pane: pane
      })
    }

    this.callHook('didOpenItem', itemToOpen)
    return itemToOpen
  }

  async confirmed (item, openAtUiPane = false) {
    if (this.hook.didConfirmItem) {
      return this.hook.didConfirmItem(item, openAtUiPane)
    }

    let pane
    if (openAtUiPane) {
      pane = this.ui.getPane()
    } else {
      pane = this.getPaneToOpenItem()
      this.needRestoreEditorState = false
    }

    const editor = await this.openFileForItem(item, {
      activatePane: true,
      pane: pane
    })

    const {point} = item
    editor.setCursorBufferPosition(point, {autoscroll: false})
    editor.unfoldBufferRow(point.row)
    editor.scrollToBufferPosition(point, {center: true})
    return editor
  }

  // View
  // -------------------------
  viewForItem (item) {
    if (item.header) {
      return item.header
    } else {
      let text
      const threshold = settings.get('textTruncationThreshold')
      if (item.text.length > threshold) {
        const textToPrepend = settings.get('textPrependToTruncatedText') + ' '
        const textDisplayed = item.text.slice(0, threshold)
        item._truncationIndicator = textToPrepend // give hint to ui.highlighter
        item._textDisplayed = textDisplayed
        text = textToPrepend + textDisplayed
      } else {
        text = item.text
      }
      return (item._lineHeader || '') + text
    }
  }

  // Direct Edit
  // -------------------------
  async updateRealFile (changes) {
    if (this.boundToSingleFile) {
      // Intentionally avoid direct use of @editor to skip observation event
      // subscribed to @editor.
      // This prevent auto refresh, so undoable narrow-editor to last state.
      await this.applyChanges(this.editor.getPath(), changes)
    } else {
      const changesByFilePath = _.groupBy(changes, change => change.item.filePath)
      for (const filePath in changesByFilePath) {
        await this.applyChanges(filePath, changesByFilePath[filePath])
      }
    }
  }

  async applyChanges (filePath, changes) {
    const existingBuffer = atom.project.findBufferForPath(filePath)
    const buffer = existingBuffer || (await atom.project.buildBuffer(filePath))

    buffer.transact(() => {
      for (const {newText, item} of changes) {
        const range = buffer.rangeForRow(item.point.row)
        buffer.setTextInRange(range, newText)
        // Sync item's text state
        // To allow re-edit if not saved and non-boundToSingleFile provider
        item.text = newText
      }
    })
    await buffer.save()
    if (!existingBuffer) buffer.destroy()
  }
}
Provider.initClass()

module.exports = Provider
