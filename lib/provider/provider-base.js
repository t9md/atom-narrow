/** @babel */

// NOTE
// this file(= provider-base.js) is NOT using babel specific feature.
// But intentinally use babel, dont remove this!!
// ProviderBase is base class extended by specific providers.
// If provider-A was written with babel and ProviderBase is not,
// it cause TypeError: Class constructor ProviderBase cannot be invoked without 'new'
// This is because Atom's babel transpiled `class` declaration is NOT ES6's class.
// I believe this mismatch wold be solved in future.
// And also with @babel, custom provider can written in CoffeeScript
const WorkspaceOpenAcceptPaneOption = atom.workspace.getCenter != null

const _ = require("underscore-plus")
const {Point, CompositeDisposable, Range} = require("atom")
const {
  saveEditorState,
  isActiveEditor,
  paneForItem,
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  getFirstCharacterPositionForBufferRow,
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
      // prettier-ignore
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
    let editorToBind
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

    if (isNarrowEditor(editor)) {
      // Invoked from another Ui( narrow-editor ).
      // Bind to original Ui.provider.editor to behaves like it invoked from normal-editor.
      editorToBind = Ui.get(editor).provider.editor
    } else {
      editorToBind = editor
    }

    this.bindEditor(editorToBind)
    this.restoreEditorState = saveEditorState(this.editor)
    this.query = this.getInitialQuery(editor)
  }

  // return promise
  start() {
    const checkReady = Promise.resolve(this.checkReady())
    return checkReady.then(ready => {
      if (ready) {
        if (this.showSearchOption) {
          this.initializeSearchOptions(this.searchOptionState)
        }

        const uiState = this.restoredState && this.restoredState.ui
        this.ui = new Ui(this, {query: this.query}, uiState)
        this.initialize()
        const {pending, focus} = this.options
        return this.ui.open({pending, focus}).then(() => this.ui)
      }
    })
  }

  updateItems(items) {
    this.ui.emitDidUpdateItems(items)
  }

  finishUpdateItems(items) {
    if (items) this.updateItems(items)
    this.ui.emitFinishUpdateItems()
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

  filterItems(items, filterSpec) {
    return filterSpec.filterItems(items, "text")
  }

  restoreEditorStateIfNecessary() {
    if (this.needRestoreEditorState) this.restoreEditorState()
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

  openFileForItem({filePath}, {activatePane} = {}) {
    const pane = this.getPaneToOpenItem()

    let itemToOpen = null
    if (this.boundToSingleFile && this.editor.isAlive() && pane === paneForItem(this.editor)) {
      itemToOpen = this.editor
    }

    if (!filePath) filePath = this.editor.getPath()
    if (!itemToOpen) itemToOpen = pane.itemForURI(filePath)

    if (itemToOpen) {
      if (activatePane) pane.activate()
      pane.activateItem(itemToOpen)
      return Promise.resolve(itemToOpen)
    }

    const openOptions = {pending: true, activatePane, activateItem: true}
    if (WorkspaceOpenAcceptPaneOption) {
      openOptions.pane = pane
      return atom.workspace.open(filePath, openOptions)
    } else {
      // NOTE: See #107
      // In Atom v1.16.0 or older, `workspace.open` doesn't allow to specify target pane to open file.
      // So need to activate target pane first.
      // Otherwise, when original pane have item for same path(URI), it opens on CURRENT pane.
      let originalActivePane
      if (!activatePane) {
        originalActivePane = atom.workspace.getActivePane()
      }
      pane.activate()
      return atom.workspace.open(filePath, openOptions).then(editor => {
        if (originalActivePane) originalActivePane.activate()
        return editor
      })
    }
  }

  confirmed(item) {
    this.needRestoreEditorState = false
    return this.openFileForItem(item, {activatePane: true}).then(editor => {
      const {point} = item
      editor.setCursorBufferPosition(point, {autoscroll: false})
      editor.unfoldBufferRow(point.row)
      editor.scrollToBufferPosition(point, {center: true})
      return editor
    })
  }

  // View
  // -------------------------
  viewForItem(item) {
    if (item.header) {
      return item.header
    } else {
      return (item._lineHeader || "") + item.text
    }
  }

  // Direct Edit
  // -------------------------
  updateRealFile(changes) {
    if (this.boundToSingleFile) {
      // Intentionally avoid direct use of @editor to skip observation event
      // subscribed to @editor.
      // This prevent auto refresh, so undoable narrow-editor to last state.
      this.applyChanges(this.editor.getPath(), changes)
    } else {
      const changesByFilePath = _.groupBy(changes, ({item}) => item.filePath)
      for (let filePath in changesByFilePath) {
        this.applyChanges(filePath, changesByFilePath[filePath])
      }
    }
  }

  applyChanges(filePath, changes) {
    atom.workspace.open(filePath, {activateItem: false}).then(editor => {
      editor.transact(() => {
        for (let {newText, item} of changes) {
          const range = editor.bufferRangeForBufferRow(item.point.row)
          editor.setTextInBufferRange(range, newText)

          // Sync item's text state
          // To allow re-edit if not saved and non-boundToSingleFile provider
          item.text = newText
        }
      })

      return editor.save()
    })
  }

  toggleSearchWholeWord() {
    return this.searchOptions.toggle("searchWholeWord")
  }

  toggleSearchIgnoreCase() {
    return this.searchOptions.toggle("searchIgnoreCase")
  }

  toggleSearchUseRegex() {
    return this.searchOptions.toggle("searchUseRegex")
  }

  // Helpers
  // -------------------------
  getFirstCharacterPointOfRow(row) {
    return getFirstCharacterPositionForBufferRow(this.editor, row)
  }

  getFilterSpec(filterQuery) {
    if (filterQuery) {
      const negateByEndingExclamation = this.getConfig("negateNarrowQueryByEndingExclamation")
      const sensitivity = this.getConfig("caseSensitivityForNarrowQuery")

      return new FilterSpec(filterQuery, {
        negateByEndingExclamation,
        sensitivity,
      })
    }
  }

  updateSearchState() {
    this.searchOptions.setSearchTerm(this.ui.getSearchTermFromQuery())
    this.ui.highlighter.setRegExp(this.searchOptions.searchRegex)

    const states = this.searchOptions.pick(
      "searchRegex",
      "searchWholeWord",
      "searchIgnoreCase",
      "searchTerm",
      "searchUseRegex"
    )
    this.ui.controlBar.updateElements(states)
  }

  scanItemsForBuffer(buffer, regex) {
    const items = []
    const filePath = buffer.getPath()
    regex = cloneRegExp(regex)
    const lines = buffer.getLines()
    for (let row = 0; row < lines.length; row++) {
      let match
      const lineText = lines[row]
      regex.lastIndex = 0
      while ((match = regex.exec(lineText))) {
        const point = new Point(row, match.index)
        const range = new Range(point, [row, regex.lastIndex])
        items.push({text: lineText, point, range, filePath})
        // Avoid infinite loop in zero length match when regex is /^/
        if (!match[0]) break
      }
    }
    return items
  }

  scanItemsForFilePath(filePath, regex) {
    return atom.workspace.open(filePath, {activateItem: false}).then(editor => {
      return this.scanItemsForBuffer(editor.buffer, regex)
    })
  }
}

ProviderBase.initClass()

module.exports = ProviderBase
