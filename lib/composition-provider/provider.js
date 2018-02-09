'use babel'

// NOTE
// this file(= provider-base.js) is NOT using babel specific feature.
// But intentinally use babel, dont remove this!!
// Provider is base class extended by specific providers.
// If provider-A was written with babel and Provider is not,
// it cause TypeError: Class constructor Provider cannot be invoked without 'new'
// This is because Atom's babel transpiled `class` declaration is NOT ES6's class.
// I believe this mismatch wold be solved in future.
// And also with @babel, custom provider can written in CoffeeScript
const _ = require('underscore-plus')
const {CompositeDisposable} = require('atom')
const {
  saveEditorState,
  isActiveEditor,
  paneForItem,
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  isNarrowEditor,
  getCurrentWord
} = require('../utils')
const Ui = require('../ui')
const settings = require('../settings')
const FilterSpec = require('../filter-spec')
const SearchOptions = require('../search-options')

const providerConfig = {
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
  editor: null,
  refreshOnDidStopChanging: false,
  refreshOnDidSave: false,

  // used by scan, search, atom-scan,
  showSearchOption: false,

  queryWordBoundaryOnByCurrentWordInvocation: false,
  useFirstQueryAsSearchTerm: false
}

module.exports = class Provider {
  static configScope = 'narrow'
  static destroyedProviderStates = []
  static providersByName = {}
  static providerPathsByName = {}
  static reopenableMax = 10
  static service = {}

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
    const editor = atom.workspace.getActiveTextEditor()
    return new Provider(editor, options)
  }

  static start (props) {
    const provider = new Provider(editor, props)
    return provider.start(options)
  }

  static registerProvider (name, klassOrFilePath) {
    const type = typeof klassOrFilePath
    if (type === 'string') {
      this.providerPathsByName[name] = klassOrFilePath
    } else if (type === 'function') {
      this.providersByName[name] = klassOrFilePath
    } else {
      throw new Error('provider must be filePath or function')
    }
  }

  static saveState (provider) {
    this.destroyedProviderStates.unshift(provider.saveState())
    this.destroyedProviderStates.splice(this.reopenableMax)
  }

  static get settings () {
    return settings
  }

  static getSetting (providerName, name) {
    const value = settings.get(`${providerName}.${name}`)
    return value === 'inherit' ? settings.get(name) : value
  }
  static setSetting (providerName, name, value) {
    settings.set(`${providerName}.${name}`, value)
  }

  static getConfig (name) {
    const value =
      this.configScope === 'narrow'
        ? settings.get(`${this.name}.${name}`)
        : atom.config.get(`${this.configScope}.${name}`)

    console.log('getconfig', `${this.name}.${name}`, value)
    return value === 'inherit' ? settings.get(name) : value
  }

  getConfig (name) {
    const value =
      this.constructor.configScope === 'narrow'
        ? settings.get(`${this.name}.${name}`)
        : atom.config.get(`${this.configScope}.${name}`)

    return value === 'inherit' ? settings.get(name) : value
  }

  static setConfig (name, value) {
    if (this.configScope === 'narrow') {
      settings.set(`${this.name}.${name}`, value)
    } else {
      atom.config.set(`${this.configScope}.${name}`, value)
    }
  }

  setConfig (name, value) {
    return this.constructor.setConfig(name, value)
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

  needActivateOnStart () {
    return this.getOnStartConditionValueFor('focusOnStartCondition')
  }

  initializeSearchOptions (restoredState, options) {
    const editor = atom.workspace.getActiveTextEditor()
    let initialState

    if (!restoredState) {
      const queryWordWithoutSelection = options.queryCurrentWord && editor.getSelectedBufferRange().isEmpty()
      initialState = {
        searchWholeWord: queryWordWithoutSelection || this.getConfig('searchWholeWord'),
        searchUseRegex: this.getConfig('searchUseRegex')
      }
    }
    this.searchOptions = new SearchOptions(this, restoredState || initialState)
  }

  // Currently used only in git-diff-all
  onItemOpened (item) {}

  bindEditor (editor) {
    if (editor === this.editor) return

    if (this.editorSubscriptions) this.editorSubscriptions.dispose()
    this.editorSubscriptions = new CompositeDisposable()
    const oldEditor = this.editor
    this.editor = editor
    this.callHook('onBindEditor', {
      newEditor: editor,
      oldEditor: oldEditor
    })
  }

  getPane () {
    // If editor was pending item, it will be destroyed on next pending-item opened
    const pane = paneForItem(this.editor)
    if (pane && pane.isAlive) {
      this.lastPane = pane
    }

    if (this.lastPane && this.lastPane.isAlive()) {
      return this.lastPane
    }
  }

  isActive () {
    return isActiveEditor(this.editor)
  }

  mergeState (stateA, stateB) {
    return Object.assign(stateA, stateB)
  }

  getState () {
    let state
    if (this.searchOptions) state = this.searchOptions.getState()
    return {searchOptionState: state}
  }

  saveState () {
    return {
      name: this.dashName,
      options: {query: this.ui.lastQuery},
      state: {
        provider: this.getState(),
        ui: this.ui.getState()
      }
    }
  }

  constructor (editor, options = {}, restoredState = null) {
    this.clientEditor = editor
    Object.assign(this, providerConfig, options.config)

    this.name = options.name
    this.dashName = _.dasherize(this.name)
    this.subscriptions = new CompositeDisposable()

    this.getItems = options.getItems
    this.updateItems = this.updateItems.bind(this)
    this.finishUpdateItems = this.finishUpdateItems.bind(this)
    this.hook = {
      onUiCreated: options.onUiCreated,
      onBindEditor: options.onBindEditor, // called with {newEditor, oldEditor}
      onItemOpened: options.onItemOpened,
      onDestroyed: options.onDestroyed
    }

    this.restoredState = restoredState
    this.reopened = !!this.restoredState

    if (this.restoredState) {
      const providerState = this.restoredState.provider
      this.searchOptionState = providerState.searchOptionState
      delete providerState.searchOptionState
      this.mergeState(this, this.restoredState.provider)
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
    if (isNarrowEditor(this.clientEditor)) {
      this.bindEditor(Ui.get(this.clientEditor).provider.editor)
    } else {
      this.bindEditor(this.clientEditor)
    }
    this.restoreEditorState = saveEditorState(this.editor)

    this.query = this.getInitialQuery(this.clientEditor, options)
    if (this.showSearchOption) {
      this.initializeSearchOptions(this.searchOptionState, options)
    }

    const uiState = this.restoredState ? this.restoredState.ui : null
    this.ui = new Ui(this, {query: this.query}, uiState)
    this.callHook('onUiCreated', this.ui)
    const {pending, focus, pane} = options
    await this.ui.open({pending, focus, pane})
    return this
  }

  updateItems (items) {
    this.ui.emitDidUpdateItems(items)
  }

  finishUpdateItems (items) {
    if (items) this.updateItems(items)
    this.ui.emitDidFinishUpdateItems()
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

  destroy () {
    if (this.supportReopen) Provider.saveState(this)

    this.subscriptions.dispose()
    this.editorSubscriptions.dispose()

    this.editor = null
    this.editorSubscriptions = null
    this.callHook('onDestroyed')
  }

  // When narrow was invoked from existing narrow-editor.
  //  ( e.g. `narrow:search-by-current-word` on narrow-editor. )
  // ui is opened at same pane of provider.editor( editor invoked narrow )
  // In this case item should be opened on adjacent pane, not on provider.pane.
  getPaneToOpenItem () {
    const pane = this.getPane()
    const paneForUi = this.ui.getPane()

    if (pane && pane !== paneForUi) {
      return pane
    } else {
      return (
        getPreviousAdjacentPaneForPane(paneForUi) ||
        getNextAdjacentPaneForPane(paneForUi) ||
        splitPane(paneForUi, {split: this.getConfig('directionToOpen').split(':')[0]})
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

    this.callHook('onItemOpened', itemToOpen)
    return itemToOpen
  }

  async confirmed (item, openAtUiPane = false) {
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

  // Helpers
  // -------------------------
  getFilterSpec (filterQuery) {
    if (filterQuery) {
      return new FilterSpec(filterQuery, {
        negateByEndingExclamation: this.getConfig('negateNarrowQueryByEndingExclamation'),
        sensitivity: this.getConfig('caseSensitivityForNarrowQuery')
      })
    }
  }
}
