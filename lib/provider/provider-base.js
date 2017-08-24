"use babel"

// NOTE
// this file(= provider-base.js) is NOT using babel specific feature.
// But intentinally use babel, dont remove this!!
// ProviderBase is base class extended by specific providers.
// If provider-A was written with babel and ProviderBase is not,
// it cause TypeError: Class constructor ProviderBase cannot be invoked without 'new'
// This is because Atom's babel transpiled `class` declaration is NOT ES6's class.
// I believe this mismatch wold be solved in future.
// And also with @babel, custom provider can written in CoffeeScript
const _ = require("underscore-plus")
const {Point, CompositeDisposable, Range, TextBuffer} = require("atom")
const {
  saveEditorState,
  isActiveEditor,
  paneForItem,
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  isNarrowEditor,
  getCurrentWord,
  cloneRegExp,
} = require("../utils")
const Ui = require("../ui")
const settings = require("../settings")
const FilterSpec = require("../filter-spec")
const SearchOptions = require("../search-options")

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
  useFirstQueryAsSearchTerm: false,
}

class ProviderBase {
  static initClass() {
    this.configScope = "narrow"
    this.destroyedProviderStates = []
    this.providersByName = {}
    this.providerPathsByName = {}
    this.reopenableMax = 10
  }

  static reopen() {
    const stateAtDestroyed = this.destroyedProviderStates.shift()
    if (stateAtDestroyed) {
      const {name, options, state} = stateAtDestroyed
      return this.start(name, options, state)
    }
  }

  static start(name, options = {}, state) {
    let klass = this.providersByName[name]
    if (!klass) klass = this.loadProvider(name)
    this.providersByName[name] = klass
    const editor = atom.workspace.getActiveTextEditor()
    return new klass(editor, options, state).start()
  }

  static loadProvider(name) {
    const filePath = this.providerPathsByName[name] || `./${_.dasherize(name)}`
    return require(filePath)
  }

  static registerProvider(name, klassOrFilePath) {
    switch (typeof klassOrFilePath) {
      case "string":
        return (this.providerPathsByName[name] = klassOrFilePath)
      case "function":
        return (this.providersByName[name] = klassOrFilePath)
      default:
        throw new Error("provider must be filePath or function")
    }
  }

  static saveState(provider) {
    this.destroyedProviderStates.unshift(provider.saveState())
    this.destroyedProviderStates.splice(this.reopenableMax)
  }

  static getConfig(name) {
    let value
    if (this.configScope === "narrow") {
      value = settings.get(`${this.name}.${name}`)
    } else {
      value = atom.config.get(`${this.configScope}.${name}`)
    }

    if (value === "inherit") {
      return settings.get(name)
    } else {
      return value
    }
  }

  getConfig(name) {
    return this.constructor.getConfig(name)
  }

  getOnStartConditionValueFor(name) {
    switch (this.getConfig(name)) {
      case "never":
        return false
      case "always":
        return true
      case "on-input":
        return this.query
      case "no-input":
        return !this.query
    }
  }

  needRevealOnStart() {
    return this.getOnStartConditionValueFor("revealOnStartCondition")
  }

  needActivateOnStart() {
    return this.getOnStartConditionValueFor("focusOnStartCondition")
  }

  // to override
  initialize() {}

  initializeSearchOptions(restoredState) {
    const editor = atom.workspace.getActiveTextEditor()
    const initialState = {}

    if (!restoredState) {
      if (this.options.queryCurrentWord && editor.getSelectedBufferRange().isEmpty()) {
        initialState.searchWholeWord = true
      } else {
        initialState.searchWholeWord = this.getConfig("searchWholeWord")
      }
      initialState.searchUseRegex = this.getConfig("searchUseRegex")
    }
    this.searchOptions = new SearchOptions(this, restoredState || initialState)
  }

  // Event is object contains {newEditor, oldEditor}
  // to override
  onBindEditor(event) {}

  checkReady() {
    return true
  }

  bindEditor(editor) {
    if (editor === this.editor) return

    if (this.editorSubscriptions) this.editorSubscriptions.dispose()
    this.editorSubscriptions = new CompositeDisposable()
    const event = {
      newEditor: editor,
      oldEditor: this.editor,
    }
    this.editor = editor
    this.onBindEditor(event)
  }

  getPane() {
    // If editor was pending item, it will be destroyed on next pending-item opened
    const pane = paneForItem(this.editor)
    if (pane && pane.isAlive) {
      this.lastPane = pane
    }

    if (this.lastPane && this.lastPane.isAlive()) {
      return this.lastPane
    } else {
      return null
    }
  }

  isActive() {
    return isActiveEditor(this.editor)
  }

  mergeState(stateA, stateB) {
    return Object.assign(stateA, stateB)
  }

  getState() {
    let state
    if (this.searchOptions) state = this.searchOptions.getState()
    return {searchOptionState: state}
  }

  saveState() {
    return {
      name: this.dashName,
      options: {
        query: this.ui.lastQuery,
      },
      state: {
        provider: this.getState(),
        ui: this.ui.getState(),
      },
    }
  }

  constructor(editor, options = {}, restoredState = null) {
    this.clientEditor = editor
    Object.assign(this, providerConfig)

    this.updateItems = this.updateItems.bind(this)
    this.finishUpdateItems = this.finishUpdateItems.bind(this)

    this.options = options
    this.restoredState = restoredState

    this.reopened = !!this.restoredState

    if (this.restoredState) {
      const providerState = this.restoredState.provider
      this.searchOptionState = providerState.searchOptionState
      delete providerState.searchOptionState
      this.mergeState(this, this.restoredState.provider)
    }

    this.name = this.constructor.name
    this.dashName = _.dasherize(this.name)
    this.subscriptions = new CompositeDisposable()

    // If invoked from another Ui( narrow-editor ).
    // Bind to original Ui.provider.editor to behaves as if it invoked from normal-editor.
    const editorToBind = isNarrowEditor(editor) ? Ui.get(editor).provider.editor : editor
    this.bindEditor(editorToBind)
    this.restoreEditorState = saveEditorState(this.editor)
  }

  // return promise
  async start() {
    this.query = this.getInitialQuery(this.clientEditor)
    const ready = await this.checkReady()
    if (ready) {
      if (this.showSearchOption) {
        this.initializeSearchOptions(this.searchOptionState)
      }

      const uiState = this.restoredState ? this.restoredState.ui : null
      this.ui = new Ui(this, {query: this.query}, uiState)
      this.initialize()
      const {pending, focus, pane} = this.options
      await this.ui.open({pending, focus, pane})
      return this.ui
    }
  }

  updateItems(items) {
    this.ui.emitDidUpdateItems(items)
  }

  finishUpdateItems(items) {
    if (items) this.updateItems(items)
    this.ui.emitDidFinishUpdateItems()
  }

  getInitialQuery(editor) {
    let query = this.options.query || editor.getSelectedText()
    if (!query && this.options.queryCurrentWord) {
      query = getCurrentWord(editor)
      if (this.queryWordBoundaryOnByCurrentWordInvocation) {
        query = `>${query}<`
      }
    }
    return query
  }

  subscribeEditor(...args) {
    this.editorSubscriptions.add(...args)
  }

  restoreEditorStateIfNecessary(...args) {
    if (this.needRestoreEditorState) this.restoreEditorState(...args)
  }

  destroy() {
    if (this.supportReopen) ProviderBase.saveState(this)

    this.subscriptions.dispose()
    this.editorSubscriptions.dispose()

    this.editor = null
    this.editorSubscriptions = null
  }

  // When narrow was invoked from existing narrow-editor.
  //  ( e.g. `narrow:search-by-current-word` on narrow-editor. )
  // ui is opened at same pane of provider.editor( editor invoked narrow )
  // In this case item should be opened on adjacent pane, not on provider.pane.
  getPaneToOpenItem() {
    const pane = this.getPane()
    const paneForUi = this.ui.getPane()

    if (pane && pane !== paneForUi) {
      return pane
    } else {
      return (
        getPreviousAdjacentPaneForPane(paneForUi) ||
        getNextAdjacentPaneForPane(paneForUi) ||
        splitPane(paneForUi, {
          split: this.getConfig("directionToOpen").split(":")[0],
        })
      )
    }
  }

  async openFileForItem({filePath}, {activatePane, pane} = {}) {
    if (!pane) pane = this.getPaneToOpenItem()

    let itemToOpen = null
    if (this.boundToSingleFile && this.editor.isAlive() && pane === paneForItem(this.editor)) {
      itemToOpen = this.editor
    }

    if (!filePath) filePath = this.editor.getPath()
    if (!itemToOpen) itemToOpen = pane.itemForURI(filePath)

    if (itemToOpen) {
      if (activatePane) pane.activate()
      pane.activateItem(itemToOpen)
      return itemToOpen
    }

    return await atom.workspace.open(filePath, {
      pending: true,
      activatePane,
      activateItem: true,
      pane: pane,
    })
  }

  async confirmed(item, openAtUiPane = false) {
    if (!openAtUiPane) {
      this.needRestoreEditorState = false
    }

    const editor = await this.openFileForItem(item, {
      activatePane: true,
      pane: openAtUiPane ? this.ui.getPane() : this.getPaneToOpenItem(),
    })

    const {point} = item
    editor.setCursorBufferPosition(point, {autoscroll: false})
    editor.unfoldBufferRow(point.row)
    editor.scrollToBufferPosition(point, {center: true})
    return editor
  }

  // View
  // -------------------------
  viewForItem(item) {
    if (item.header) {
      return item.header
    } else {
      const threshold = settings.get("textTruncationThreshold")
      if (item.text.length > threshold) {
        const textToPrepend = settings.get("textPrependToTruncatedText") + " "
        const textDisplayed = item.text.slice(0, threshold)
        item._truncationIndicator = textToPrepend // give hint to ui.highlighter
        item._textDisplayed = textDisplayed
        text = textToPrepend + textDisplayed
      } else {
        text = item.text
      }
      return (item._lineHeader || "") + text
    }
  }

  // Direct Edit
  // -------------------------
  async updateRealFile(changes) {
    if (this.boundToSingleFile) {
      // Intentionally avoid direct use of @editor to skip observation event
      // subscribed to @editor.
      // This prevent auto refresh, so undoable narrow-editor to last state.
      await this.applyChanges(this.editor.getPath(), changes)
    } else {
      const changesByFilePath = _.groupBy(changes, ({item}) => item.filePath)
      for (let filePath in changesByFilePath) {
        await this.applyChanges(filePath, changesByFilePath[filePath])
      }
    }
  }

  async applyChanges(filePath, changes) {
    const existingBuffer = atom.project.findBufferForPath(filePath)
    const buffer = existingBuffer || (await atom.project.buildBuffer(filePath))

    buffer.transact(() => {
      for (let {newText, item} of changes) {
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
  getFilterSpec(filterQuery) {
    if (filterQuery) {
      const negateByEndingExclamation = this.getConfig("negateNarrowQueryByEndingExclamation")
      const sensitivity = this.getConfig("caseSensitivityForNarrowQuery")

      return new FilterSpec(filterQuery, {negateByEndingExclamation, sensitivity})
    }
  }
}

ProviderBase.initClass()
module.exports = ProviderBase
