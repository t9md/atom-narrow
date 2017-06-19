const _ = require("underscore-plus")
const path = require("path")
const {Point, Range, CompositeDisposable, Disposable, Emitter} = require("atom")
const {
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  isActiveEditor,
  setBufferRow,
  paneForItem,
  isDefinedAndEqual,
  ensureNoConflictForChanges,
  isNormalItem,
  cloneRegExp,
  suppressEvent,
  startMeasureMemory,
  getCurrentWord,
  isExcludeFilter,
} = require("./utils")

const itemReducer = require("./item-reducer")
const settings = require("./settings")
const Highlighter = require("./highlighter")
const ControlBar = require("./control-bar")
const Items = require("./items")
const ItemIndicator = require("./item-indicator")
const queryHistory = require("./query-history")
const narrowGrammar = atom.grammars.grammarForScopeName("source.narrow")

let SelectFiles = null

class Ui {
  static initClass() {
    this.uiByEditor = new Map()
    this.queryHistory = queryHistory
  }

  static unregister(ui) {
    this.uiByEditor.delete(ui.editor)
    this.updateWorkspaceClassList()
  }

  static register(ui) {
    this.uiByEditor.set(ui.editor, ui)
    this.updateWorkspaceClassList()
  }

  static get(editor) {
    return this.uiByEditor.get(editor)
  }

  static getSize() {
    return this.uiByEditor.size
  }

  static forEach(fn) {
    this.uiByEditor.forEach(fn)
  }

  static updateWorkspaceClassList() {
    const view = atom.views.getView(atom.workspace)
    view.classList.toggle("has-narrow", this.uiByEditor.size)
  }

  static getNextTitleNumber() {
    const numbers = [0]
    this.uiByEditor.forEach(ui => numbers.push(ui.titleNumber))
    return Math.max(...numbers) + 1
  }

  onDidMoveToPrompt(fn) {
    return this.emitter.on("did-move-to-prompt", fn)
  }
  emitDidMoveToPrompt() {
    this.emitter.emit("did-move-to-prompt")
  }

  onDidMoveToItemArea(fn) {
    return this.emitter.on("did-move-to-item-area", fn)
  }
  emitDidMoveToItemArea() {
    this.emitter.emit("did-move-to-item-area")
  }

  onDidUpdateItems(fn) {
    return this.emitter.on("did-update-items", fn)
  }
  emitDidUpdateItems(event) {
    this.emitter.emit("did-update-items", event)
  }

  onFinishUpdateItems(fn) {
    return this.emitter.on("finish-update-items", fn)
  }
  emitFinishUpdateItems() {
    this.emitter.emit("finish-update-items")
  }

  onDidDestroy(fn) {
    return this.emitter.on("did-destroy", fn)
  }
  emitDidDestroy() {
    this.emitter.emit("did-destroy")
  }

  onDidRefresh(fn) {
    return this.emitter.on("did-refresh", fn)
  }
  emitDidRefresh() {
    this.emitter.emit("did-refresh")
  }

  onWillRefresh(fn) {
    return this.emitter.on("will-refresh", fn)
  }
  emitWillRefresh() {
    this.emitter.emit("will-refresh")
  }

  onWillRefreshManually(fn) {
    return this.emitter.on("will-refresh-manually", fn)
  }
  emitWillRefreshManually() {
    this.emitter.emit("will-refresh-manually")
  }

  onDidStopRefreshing(fn) {
    return this.emitter.on("did-stop-refreshing", fn)
  }
  emitDidStopRefreshing() {
    // Debounced, fired after 100ms delay
    if (!this._emitDidStopRefreshing) {
      this._emitDidStopRefreshing = _.debounce(() => {
        this.emitter.emit("did-stop-refreshing")
      }, 100)
    }
    this._emitDidStopRefreshing()
  }

  onDidPreview(fn) {
    return this.emitter.on("did-preview", fn)
  }
  emitDidPreview(event) {
    this.emitter.emit("did-preview", event)
  }

  onDidConfirm(fn) {
    return this.emitter.on("did-confirm", fn)
  }
  emitDidConfirm(event) {
    this.emitter.emit("did-confirm", event)
  }

  registerCommands() {
    return atom.commands.add(this.editorElement, {
      "core:confirm": () => this.confirm(),
      "core:move-up": event => this.moveUpOrDownWrap(event, "up"),
      "core:move-down": event => this.moveUpOrDownWrap(event, "down"),

      // HACK: PreserveGoalColumn when skipping header row.
      // Following command is earlily invoked than original move-up(down)-wrap,
      // because it's directly defined on @editorElement.
      // Actual movement is still done by original command since command event is propagated.
      "vim-mode-plus:move-up-wrap": () => this.preserveGoalColumn(),
      "vim-mode-plus:move-down-wrap": () => this.preserveGoalColumn(),

      "narrow-ui:confirm-keep-open": () => this.confirm({keepOpen: true}),
      "narrow-ui:protect": () => this.toggleProtected(),
      "narrow-ui:preview-item": () => this.preview(),
      "narrow-ui:preview-next-item": () => this.previewItemForDirection("next"),
      "narrow-ui:preview-previous-item": () => this.previewItemForDirection("previous"),
      "narrow-ui:toggle-auto-preview": () => this.toggleAutoPreview(),
      "narrow-ui:move-to-prompt-or-selected-item": () => this.moveToPromptOrSelectedItem(),
      "narrow-ui:move-to-prompt": () => this.moveToPrompt(),
      "narrow-ui:start-insert": () => this.setReadOnly(false),
      "narrow-ui:stop-insert": () => this.setReadOnly(true),
      "narrow-ui:update-real-file": () => this.updateRealFile(),
      "narrow-ui:exclude-file": () => this.excludeFile(),
      "narrow-ui:select-files": () => this.selectFiles(),
      "narrow-ui:clear-excluded-files": () => this.clearExcludedFiles(),
      "narrow-ui:move-to-next-file-item": () => this.moveToDifferentFileItem("next"),
      "narrow-ui:move-to-previous-file-item": () => this.moveToDifferentFileItem("previous"),
      "narrow-ui:toggle-search-whole-word": () => this.toggleSearchWholeWord(),
      "narrow-ui:toggle-search-ignore-case": () => this.toggleSearchIgnoreCase(),
      "narrow-ui:toggle-search-use-regex": () => this.toggleSearchUseRegex(),
      "narrow-ui:delete-to-end-of-search-term": () => this.deleteToEndOfSearchTerm(),
      "narrow-ui:clear-query-history": () => this.clearHistroy(),
    })
  }

  setQueryFromHistroy(direction, retry) {
    const text = queryHistory.get(this.provider.name, direction)
    if (!text) return

    if (text === this.getQuery()) {
      if (!retry) this.setQueryFromHistroy(direction, true) // retry
    } else {
      this.withIgnoreChange(() => this.setQuery(text))
      this.refreshWithDelay({force: true}, 100, () => {
        this.moveToSearchedWordOrBeginningOfSelectedItem()
        if (!this.isActive()) this.scrollToColumnZero()
        this.flashCursorLine()
      })
    }
  }

  clearHistroy() {
    queryHistory.clear(this.provider.name)
  }

  resetHistory() {
    queryHistory.reset(this.provider.name)
  }

  saveQueryHistory(text) {
    queryHistory.save(this.provider.name, text)
  }

  withIgnoreCursorMove(fn) {
    this.ignoreCursorMove = true
    fn()
    this.ignoreCursorMove = false
  }

  withIgnoreChange(fn) {
    this.ignoreChange = true
    fn()
    this.ignoreChange = false
  }

  isModified() {
    return this.modifiedState
  }

  getState() {
    return {
      excludedFiles: this.excludedFiles,
      queryForSelectFiles: this.queryForSelectFiles,
    }
  }

  getSearchTermFromQuery() {
    const range = this.getSearchTermRange()
    if (range) {
      return this.editor.getTextInBufferRange(range)
    }
  }

  getSearchTermRange() {
    if (this.useFirstQueryAsSearchTerm) {
      const match = /^\S*/.exec(this.getQuery())
      return new Range([0, 0], [0, match[0].length])
    }
  }

  deleteToEndOfSearchTerm() {
    if (!this.isAtPrompt()) return

    const searchTermRange = this.getSearchTermRange()
    if (!searchTermRange) {
      this.editor.deleteToBeginningOfLine()
    } else {
      const selection = this.editor.getLastSelection()
      const cursorPosition = selection.cursor.getBufferPosition()
      const searchTermEnd = searchTermRange.end
      const deleteStart = cursorPosition.isGreaterThan(searchTermEnd) ? searchTermEnd : [0, 0]

      selection.setBufferRange([deleteStart, cursorPosition])
      selection.delete()
    }
  }

  queryCurrentWord() {
    const word = getCurrentWord(atom.workspace.getActiveTextEditor()).trim()
    if (!word) return

    this.saveQueryHistory(word)
    this.withIgnoreChange(() => this.setQuery(word))
    this.refresh({force: true}).then(() => {
      this.moveToSearchedWordOrBeginningOfSelectedItem()
      if (!this.isActive()) this.scrollToColumnZero()
      this.flashCursorLine()
    })
  }

  scrollToColumnZero() {
    const {row} = this.editor.getCursorBufferPosition()
    this.editor.scrollToBufferPosition([row, 0], {center: true})
  }

  refreshPromptHighlight() {
    this.highlighter.highlightPrompt(this.parsePromptLine())
  }

  parsePromptLine() {
    const regex = /\S+/g
    let searchTerm, match
    const includeFilters = []
    const excludeFilters = []

    const text = this.getQuery()
    const {negateByEndingExclamation} = this

    while ((match = regex.exec(text))) {
      const range = new Range([0, match.index], [0, regex.lastIndex])
      if (this.useFirstQueryAsSearchTerm && !searchTerm) {
        searchTerm = range
      } else {
        if (isExcludeFilter(this.editor.getTextInBufferRange(range), negateByEndingExclamation)) {
          excludeFilters.push(range)
        } else {
          includeFilters.push(range)
        }
      }
    }

    return {searchTerm, includeFilters, excludeFilters}
  }

  setModifiedState(state) {
    if (state === this.modifiedState) return

    // HACK: overwrite TextBuffer:isModified to return static state.
    // This state is used by tabs package to show modified icon on tab.
    this.modifiedState = state
    this.editor.buffer.isModified = () => state
    this.editor.buffer.emitModifiedStatusChanged(state)
  }

  toggleSearchWholeWord(event) {
    suppressEvent(event)
    this.provider.toggleSearchWholeWord()
    this.refresh({force: true})
  }

  toggleSearchIgnoreCase(event) {
    suppressEvent(event)
    this.provider.toggleSearchIgnoreCase()
    this.refresh({force: true})
  }

  toggleSearchUseRegex(event) {
    suppressEvent(event)
    this.provider.toggleSearchUseRegex()
    this.refresh({force: true})
  }

  toggleProtected(event) {
    suppressEvent(event)
    this.protected = !this.protected
    this.itemIndicator.update({protected: this.protected})
    this.controlBar.updateElements({protected: this.protected})
  }

  toggleAutoPreview(event) {
    suppressEvent(event)
    this.autoPreview = !this.autoPreview
    this.controlBar.updateElements({autoPreview: this.autoPreview})
    this.highlighter.clearCurrentAndLineMarker()
    if (this.autoPreview) this.preview()
  }

  setReadOnly(readOnly) {
    this.readOnly = readOnly
    const {component, classList} = this.editorElement
    if (readOnly) {
      if (component) component.setInputEnabled(false)
      classList.add("read-only")
      if (this.vmpIsInsertMode()) this.vmpActivateNormalMode()
    } else {
      if (component) component.setInputEnabled(true)
      classList.remove("read-only")
      if (this.vmpIsNormalMode()) this.vmpActivateInsertMode()
    }
  }

  constructor(provider, {query} = {}, restoredState) {
    this.autoPreview = null
    this.autoPreviewOnQueryChange = null
    this.inPreview = false
    this.suppressPreview = false
    this.ignoreChange = false
    this.ignoreCursorMove = false
    this.destroyed = false
    this.lastQuery = ""
    this.lastSearchTerm = ""
    this.modifiedState = null
    this.readOnly = false
    this.protected = false
    this.excludedFiles = null
    this.queryForSelectFiles = null
    this.delayedRefreshTimeout = null

    this.provider = provider
    this.query = query

    // This is `narrow:reopen`, to restore STATE properties.
    if (restoredState) Object.assign(this, restoredState)

    if (!SelectFiles) {
      SelectFiles = require("./provider/select-files")
    }

    // Pull never changing info-only-properties from provider.
    Object.assign(
      this,
      _.pick(this.provider, [
        "showSearchOption",
        "showProjectHeader",
        "showFileHeader",
        "showColumnOnLineHeader",
        "boundToSingleFile",
        "itemHaveRange",
        "supportDirectEdit",
        "supportCacheItems",
        "supportFilePathOnlyItemsUpdate",
        "useFirstQueryAsSearchTerm",
        "reopened",
        "refreshOnDidSave",
        "refreshOnDidStopChanging",
      ])
    )

    // Initial state asignment: start
    // -------------------------
    // NOTE: These state is restored when `narrow:reopen`
    // So assign initial value unless assigned.
    if (!this.queryForSelectFiles) {
      this.queryForSelectFiles = SelectFiles.getLastQuery(this.provider.name)
    }
    if (!this.excludedFiles) this.excludedFiles = []
    this.filePathsForAllItems = []
    if (!this.query) this.query = ""
    // Initial state asignment: end

    this.disposables = new CompositeDisposable()
    this.emitter = new Emitter()

    this.autoPreview = this.provider.getConfig("autoPreview")
    this.autoPreviewOnQueryChange = this.provider.getConfig("autoPreviewOnQueryChange")
    this.negateByEndingExclamation = this.provider.getConfig("negateNarrowQueryByEndingExclamation")
    this.showLineHeader = this.provider.getConfig("showLineHeader")

    this.itemAreaStart = Object.freeze(new Point(1, 0))

    this.toggleSearchWholeWord = this.toggleSearchWholeWord.bind(this)
    this.toggleSearchIgnoreCase = this.toggleSearchIgnoreCase.bind(this)
    this.toggleSearchUseRegex = this.toggleSearchUseRegex.bind(this)
    this.toggleProtected = this.toggleProtected.bind(this)
    this.toggleAutoPreview = this.toggleAutoPreview.bind(this)
    this.selectFiles = this.selectFiles.bind(this)
    this.filterItems = this.filterItems.bind(this)
    this.addItems = this.addItems.bind(this)
    this.refreshManually = this.refreshManually.bind(this)
    this.renderItems = this.renderItems.bind(this)
    this.preview = this.preview.bind(this)

    this.reducers = [
      itemReducer.spliceItemsForFilePath,
      this.showLineHeader ? itemReducer.injectLineHeader : undefined,
      itemReducer.collectAllItems,
      itemReducer.filterFilePath,
      this.filterItems,
      this.showProjectHeader ? itemReducer.insertProjectHeader : undefined,
      this.showFileHeader ? itemReducer.insertFileHeader : undefined,
      this.addItems,
      this.renderItems,
    ].filter(reducer => reducer)

    // Setup narrow-editor
    // -------------------------
    this.editor = atom.workspace.buildTextEditor({lineNumberGutterVisible: false, autoHeight: false})
    this.titleNumber = this.constructor.getNextTitleNumber()
    const title = this.provider.dashName + "-" + this.titleNumber
    this.editor.getTitle = () => title
    this.editor.onDidDestroy(this.destroy.bind(this))
    this.editorElement = this.editor.element
    this.editorElement.classList.add("narrow", "narrow-editor", this.provider.dashName)
    this.setModifiedState(false)
    this.editor.setGrammar(narrowGrammar)
    this.highlighter = new Highlighter(this)

    this.items = new Items(this)
    this.itemIndicator = new ItemIndicator(this.editor)

    this.items.onDidChangeSelectedItem(({row}) => this.itemIndicator.update({row}))

    this.onDidMoveToItemArea(() => {
      if (settings.get("autoShiftReadOnlyOnMoveToItemArea")) this.setReadOnly(true)
      this.editorElement.classList.remove("prompt")
    })

    this.onDidMoveToPrompt(() => {
      this.editorElement.classList.add("prompt")
    })

    // FIXME order dependent, must be at last.
    this.controlBar = new ControlBar(this)
    this.constructor.register(this)
  }

  getPaneToOpen() {
    const basePane = this.provider.getPane()

    const directionToOpen = this.provider.getConfig("directionToOpen")
    const [direction, adjacentPanePreference] = directionToOpen.split(":")

    const pane = (() => {
      switch (adjacentPanePreference) {
        case "always-new-pane":
          return null
        case "never-use-previous-adjacent-pane":
          return getNextAdjacentPaneForPane(basePane)
        default:
          return getNextAdjacentPaneForPane(basePane) || getPreviousAdjacentPaneForPane(basePane)
      }
    })()

    return pane || splitPane(basePane, {split: direction})
  }

  open({pending = false, focus = true} = {}) {
    // [NOTE] When new item is activated, existing PENDING item is destroyed.
    // So existing PENDING narrow-editor is destroyed at this timing.
    // And PENDING narrow-editor's provider's editor have foucsed.
    // So pane.activate must be called AFTER activateItem
    const pane = this.getPaneToOpen()
    // atom.workspace.open(this.editor, {pending, pane})
    pane.activateItem(this.editor, {pending})

    if (focus && this.provider.needActivateOnStart()) pane.activate()

    this.setQuery(this.query)

    if (!this.reopened) this.saveQueryHistory(this.query)

    this.controlBar.show()
    this.moveToPrompt()

    // prettier-ignore
    this.disposables.add(
      this.registerCommands(),
      this.observeChange(),
      this.observeCursorMove()
    )

    return this.refresh().then(() => {
      if (this.provider.needRevealOnStart()) {
        this.syncToEditor(this.provider.editor)
        if (this.items.hasSelectedItem()) {
          this.suppressPreview = true
          this.moveToSearchedWordOrBeginningOfSelectedItem()
          this.suppressPreview = false
          const previewPromise = this.preview()
          if (previewPromise) {
            return previewPromise.then(this.flashCursorLine.bind(this))
          }
        }
      } else if (this.query && this.autoPreviewOnQueryChange) {
        return this.preview()
      }
    })
  }

  flashCursorLine() {
    const itemCount = this.items.getCount()
    if (itemCount <= 5) return

    const flashSpec = itemCount < 10
      ? {duration: 1000, class: "narrow-cursor-line-flash-medium"}
      : {duration: 2000, class: "narrow-cursor-line-flash-long"}

    if (this.cursorLineFlashMarker) this.cursorLineFlashMarker.destroy()
    const point = this.editor.getCursorBufferPosition()
    this.cursorLineFlashMarker = this.editor.markBufferPosition(point)
    const decorationOptions = {type: "line", class: flashSpec.class}
    this.editor.decorateMarker(this.cursorLineFlashMarker, decorationOptions)

    const destroyMarker = () => {
      if (this.cursorLineFlashMarker) this.cursorLineFlashMarker.destroy()
      this.cursorLineFlashMarker = null
    }
    setTimeout(destroyMarker, flashSpec.duration)
  }

  getPane() {
    return paneForItem(this.editor)
  }

  isSamePaneItem(item) {
    return paneForItem(item) === this.getPane()
  }

  isActive() {
    return isActiveEditor(this.editor)
  }

  focus({autoPreview = this.autoPreview} = {}) {
    const pane = this.getPane()
    pane.activate()
    pane.activateItem(this.editor)
    if (autoPreview) this.preview()
  }

  focusPrompt() {
    if (this.isActive() && this.isAtPrompt()) {
      this.activateProviderPane()
    } else {
      if (!this.isActive()) this.focus()
      this.moveToPrompt()
    }
  }

  toggleFocus() {
    if (this.isActive()) {
      this.activateProviderPane()
    } else {
      this.focus()
    }
  }

  activateProviderPane() {
    const pane = this.provider.getPane()
    if (!pane) return

    // [BUG?] maybe upstream Atom-core bug?
    // In rare situation( I observed only in test-spec ), there is the situation
    // where pane.isAlive but paneContainer.getPanes() in pane return `false`
    // Without folowing guard "Setting active pane that is not present in pane container"
    // exception thrown.
    if (pane.getContainer().getPanes().includes(pane)) {
      pane.activate()
      const editor = pane.getActiveEditor()
      if (editor) editor.scrollToCursorPosition()
    }
  }

  isAlive() {
    return !this.destroyed
  }

  destroy() {
    if (this.destroyed) return

    this.destroyed = true
    this.saveQueryHistory(this.getQuery())
    this.resetHistory()

    // NOTE: Prevent delayed-refresh on destroyed editor.
    this.cancelDelayedRefresh()
    if (this.refreshDisposables) this.refreshDisposables.dispose()

    this.constructor.unregister(this)
    this.highlighter.destroy()
    if (this.syncSubcriptions) this.syncSubcriptions.dispose()
    this.disposables.dispose()
    this.editor.destroy()

    this.controlBar.destroy()
    if (this.provider) this.provider.destroy()
    this.items.destroy()
    this.itemIndicator.destroy()
    this.emitDidDestroy()
  }

  close() {
    this.provider.restoreEditorStateIfNecessary()
    this.getPane().destroyItem(this.editor, true)
  }

  resetQuery() {
    this.setQuery() // clear query
    this.moveToPrompt()
    this.controlBar.show()
  }

  preserveGoalColumn() {
    // HACK: In narrow-editor, header row is skipped onDidChangeCursorPosition event
    // But at this point, cursor.goalColumn is explicitly cleared by atom-core
    // I want use original goalColumn info within onDidChangeCursorPosition event
    // to keep original column when header item was auto-skipped.
    const cursor = this.editor.getLastCursor()
    this.goalColumn = cursor.goalColumn != null ? cursor.goalColumn : cursor.getBufferColumn()
  }

  // Line-wrapped version of 'core:move-up' override default behavior
  moveUpOrDownWrap(event, direction) {
    this.preserveGoalColumn()

    const cursor = this.editor.getLastCursor()
    const cursorRow = cursor.getBufferRow()
    const lastRow = this.editor.getLastBufferRow()

    if (direction === "up" && cursorRow === 0) {
      setBufferRow(cursor, lastRow)
      event.stopImmediatePropagation()
    } else if (direction === "down" && cursorRow === lastRow) {
      setBufferRow(cursor, 0)
      event.stopImmediatePropagation()
    }
  }

  // Even in movemnt not happens, it should confirm current item
  // This ensure next-item/previous-item always move to selected item.
  confirmItemForDirection(direction) {
    const point = this.provider.editor.getCursorBufferPosition()
    this.items.selectItemInDirection(point, direction)
    this.confirm({keepOpen: true, flash: true})
  }

  previewItemForDirection(direction) {
    const rowForSelectedItem = this.items.getRowForSelectedItem()
    // When initial invocation not cause preview(since initial query input was empty).
    // Don't want `tab` skip first seleted item.
    const firstTimeNext = !this.highlighter.hasLineMarker() && direction === "next"
    const row = firstTimeNext
      ? rowForSelectedItem
      : this.items.findRowForNormalItem(rowForSelectedItem, direction)

    if (row != null) {
      this.items.selectItemForRow(row)
      this.preview()
    }
  }

  getQuery() {
    return this.editor.getTextInBufferRange(this.getPromptRange())
  }

  getFilterQuery() {
    if (this.useFirstQueryAsSearchTerm) {
      // Extracet filterQuery by removing searchTerm part from query
      return this.getQuery().replace(/^.*?\S+\s*/, "")
    } else {
      return this.getQuery()
    }
  }

  excludeFile() {
    if (this.boundToSingleFile) return

    const selectedItem = this.items.getSelectedItem()
    if (!selectedItem) return
    const {filePath} = selectedItem
    if (filePath && !this.excludedFiles.includes(filePath)) {
      this.excludedFiles.push(filePath)
      this.moveToDifferentFileItem("next")
      this.refresh()
    }
  }

  selectFiles(event) {
    suppressEvent(event)
    if (this.boundToSingleFile) return

    return new SelectFiles(this.editor, {
      query: this.queryForSelectFiles,
      clientUi: this,
    }).start()
  }

  resetQueryForSelectFiles(queryForSelectFiles) {
    this.queryForSelectFiles = queryForSelectFiles
    this.excludedFiles = []
    this.focus({autoPreview: false})
    this.refresh()
  }

  clearExcludedFiles() {
    if (this.boundToSingleFile) return

    this.excludedFiles = []
    this.queryForSelectFiles = ""
    this.refresh()
  }

  requestItems(event = {}) {
    const {cachedItems} = this.items
    if (cachedItems) {
      this.emitDidUpdateItems(cachedItems)
      this.emitFinishUpdateItems()
    } else {
      this.provider.getItems(event)
    }
  }

  // reducer
  filterItems({items, filterSpec}) {
    if (filterSpec) {
      return {
        items: this.provider.filterItems(items, filterSpec),
      }
    }
  }

  // reducer
  addItems({items}) {
    this.items.addItems(items)
  }

  reduceItems(state, items) {
    this.reducers.reduce(
      (state, reducer) => Object.assign(state, reducer(state)),
      Object.assign(state, {items, reduced: true})
    )
  }

  createStateToReduce() {
    return {
      reduced: false,
      hasCachedItems: this.items.cachedItems != null,
      showColumn: this.showColumnOnLineHeader,
      maxRow: this.boundToSingleFile ? this.provider.editor.getLastBufferRow() : undefined,
      boundToSingleFile: this.boundToSingleFile,
      projectHeadersInserted: {},
      fileHeadersInserted: {},
      allItems: [],
      filterSpec: this.provider.getFilterSpec(this.getFilterQuery()),
      filterSpecForSelectFiles: SelectFiles.prototype.getFilterSpec(this.queryForSelectFiles),
      fileExcluded: false,
      excludedFiles: this.excludedFiles,
      renderStartPosition: this.itemAreaStart,
    }
  }

  startUpdateItemCount() {
    const intervalID = setInterval(() => {
      this.controlBar.updateElements({itemCount: this.items.getCount()})
    }, 500)
    return new Disposable(() => clearInterval(intervalID))
  }

  getFilePathsForAllItems() {
    return this.filePathsForAllItems
  }

  updateControlBarRefreshElement() {
    const updateRefreshRunningElement = () => {
      this.controlBar.updateElements({refresh: true})
    }

    if (this.query) {
      const cursor = this.editor.getLastCursor()
      if (cursor.setVisible) cursor.setVisible(false)
      const timeoutID = setTimeout(updateRefreshRunningElement, 300)
      return new Disposable(() => {
        if (cursor.setVisible) cursor.setVisible(true)
        clearTimeout(timeoutID)
      })
    } else {
      updateRefreshRunningElement()
      return new Disposable()
    }
  }

  cancelRefresh() {
    if (this.refreshDisposables) {
      this.refreshDisposables.dispose()
      this.refreshDisposables = null
    }
  }

  // Return promise
  refresh({force, selectFirstItem, event = {}} = {}) {
    this.cancelRefresh()
    this.highlighter.clearNarrowEditorHighlight()

    this.refreshDisposables = new CompositeDisposable()
    this.filePathsForAllItems = []
    this.highlighter.clearCurrentAndLineMarker()
    this.emitWillRefresh()

    // prettier-ignore
    this.refreshDisposables.add(
      this.updateControlBarRefreshElement(),
      this.startUpdateItemCount()
    )

    this.lastQuery = this.getQuery()

    if (this.useFirstQueryAsSearchTerm) {
      const searchTerm = this.getSearchTermFromQuery()
      if (this.lastSearchTerm !== searchTerm) {
        this.lastSearchTerm = searchTerm
        force = true
      }
    }

    const spliceFilePath = event.filePath
    const cachedNormalItems = (() => {
      if (this.supportFilePathOnlyItemsUpdate) {
        if (spliceFilePath && this.items.cachedItems) {
          return this.items.cachedItems.filter(isNormalItem)
        }
      }
    })()

    if (force) this.items.clearCachedItems()

    let resolveGetItem
    const getItemPromise = new Promise(resolve => {
      resolveGetItem = resolve
    })

    const state = this.createStateToReduce()
    Object.assign(state, {cachedNormalItems, spliceFilePath})

    const reduceItems = this.reduceItems.bind(this, state)

    const onFinish = () => {
      // After requestItems, no items sent via @onDidUpdateItems.
      // manually update with empty items.
      // e.g.
      //   1. search `editor` found 100 items
      //   2. search `editorX` found 0 items (clear items via emitDidUpdateItems([]))
      if (!state.reduced) this.emitDidUpdateItems([])
      this.cancelRefresh()

      if (!this.boundToSingleFile) {
        this.filePathsForAllItems = _.chain(state.allItems).pluck("filePath").uniq().value()
      }

      if (this.supportCacheItems) this.items.setCachedItems(state.allItems)

      if (!selectFirstItem && oldSelectedItem) {
        this.items.selectEqualLocationItem(oldSelectedItem)
        if (!this.items.hasSelectedItem()) {
          this.items.selectFirstNormalItem()
        }

        if (!this.isAtPrompt()) {
          this.moveToSelectedItem({ignoreCursorMove: !this.isActive(), column: oldColumn})
        }
      } else {
        // when originally selected item cannot be selected because of excluded.
        this.items.selectFirstNormalItem()
        if (!this.isAtPrompt()) this.moveToPrompt()
      }

      this.controlBar.updateElements({
        selectFiles: state.fileExcluded,
        itemCount: this.items.getCount(),
        refresh: false,
      })
      return resolveGetItem()
    }

    this.refreshDisposables.add(this.onDidUpdateItems(reduceItems))
    this.refreshDisposables.add(this.onFinishUpdateItems(onFinish))

    // Preserve oldSelectedItem before calling @items.reset()
    const oldSelectedItem = this.items.getSelectedItem()
    const oldColumn = this.editor.getCursorBufferPosition().column

    this.items.reset()
    this.requestItems(event)

    return getItemPromise.then(() => {
      this.emitDidRefresh()
      this.emitDidStopRefreshing()
    })
  }

  refreshManually(event) {
    suppressEvent(event)
    this.emitWillRefreshManually()
    this.refresh({force: true})
  }

  // reducer
  // -------------------------
  renderItems({renderStartPosition, items, filterSpec}) {
    let visibleItems
    const firstRender = renderStartPosition.isEqual(this.itemAreaStart)
    // avoid rendering empty line when no items(= all items this chunks are filtered).
    if (!items.length && !firstRender) return

    // FIXME: use provider.editor's info since narrow-editor's editor mesurement
    // is not correct because of bug. atom/atom#14817
    const rowsPerPage = this.provider.editor.getRowsPerPage()
    if (renderStartPosition.row <= rowsPerPage) {
      visibleItems = items.slice(0, rowsPerPage - renderStartPosition.row)
    }

    const texts = items.map(item => this.provider.viewForItem(item))
    this.withIgnoreChange(() => {
      if (this.editor.getLastBufferRow() === 0) {
        this.resetQuery()
      }

      const eof = this.editor.getEofBufferPosition()
      let text = (firstRender ? "" : "\n") + texts.join("\n")
      const range = [renderStartPosition, eof]
      renderStartPosition = this.editor.setTextInBufferRange(range, text, {undo: "skip"}).end
      this.editorLastRow = renderStartPosition.row
      this.setModifiedState(false)
    })

    if (visibleItems) this.highlighter.highlightNarrowEditorForItems(visibleItems, filterSpec)

    return {renderStartPosition}
  }

  observeChange() {
    const onPrompt = range => range.intersectsWith(this.getPromptRange())
    const isQueryModified = (newRange, oldRange) =>
      (!newRange.isEmpty() && onPrompt(newRange)) || (!oldRange.isEmpty() && onPrompt(oldRange))

    const destroyPromptSelection = () => {
      let selectionDestroyed = false
      for (const selection of this.editor.getSelections()) {
        if (onPrompt(selection.getBufferRange())) {
          selectionDestroyed = true
          selection.destroy()
        }
      }
      if (selectionDestroyed) this.controlBar.show()
      this.withIgnoreChange(() => this.setQuery(this.lastQuery)) // Recover query
    }

    return this.editor.buffer.onDidChange(event => {
      if (this.ignoreChange) return

      if (!isQueryModified(event.newRange, event.oldRange)) {
        this.setModifiedState(true) // Item area modified, direct editor
        return
      }

      if (this.editor.hasMultipleCursors()) {
        // Destroy cursors on prompt to protect query from mutation on 'find-and-replace:select-all'( cmd-alt-g ).
        destroyPromptSelection()
      } else {
        let delay
        if (this.lastQuery.trim() === this.getQuery().trim()) return

        if (
          this.useFirstQueryAsSearchTerm &&
          this.getSearchTermFromQuery() !== this.lastSearchTerm
        ) {
          delay = this.provider.getConfig("refreshDelayOnSearchTermChange")
        } else {
          delay = this.boundToSingleFile ? 0 : 100
        }

        this.refreshPromptHighlight()

        this.refreshWithDelay({selectFirstItem: true}, delay, () => {
          if (this.autoPreviewOnQueryChange && this.isActive()) {
            this.preview()
          }
        })
      }
    })
  }

  // Delayed-refresh
  refreshWithDelay(options, delay, onRefresh) {
    this.cancelDelayedRefresh()
    this.delayedRefreshTimeout = setTimeout(() => {
      this.delayedRefreshTimeout = null
      this.refresh(options).then(onRefresh)
    }, delay)
  }

  cancelDelayedRefresh() {
    if (this.delayedRefreshTimeout) {
      clearTimeout(this.delayedRefreshTimeout)
      this.delayedRefreshTimeout = null
    }
  }

  observeCursorMove() {
    return this.editor.onDidChangeCursorPosition(event => {
      if (this.ignoreCursorMove) return

      const {oldBufferPosition, newBufferPosition, textChanged, cursor} = event

      // Clear preserved @goalColumn as early as possible to not affect other movement commands.
      const goalColumn = this.goalColumn != null ? this.goalColumn : newBufferPosition.column
      this.goalColumn = null

      if (
        textChanged ||
        !cursor.selection.isEmpty() ||
        oldBufferPosition.row === newBufferPosition.row
      ) {
        return
      }

      let newRow = newBufferPosition.row
      const oldRow = oldBufferPosition.row
      const isHeaderRow = !this.isPromptRow(newRow) && !this.items.isNormalItemRow(newRow)

      let headerWasSkipped
      if (isHeaderRow) {
        headerWasSkipped = true
        const direction = newRow > oldRow ? "next" : "previous"
        newRow = this.items.findRowForNormalOrPromptItem(newRow, direction)
      }

      if (this.isPromptRow(newRow)) {
        if (headerWasSkipped) {
          this.withIgnoreCursorMove(() => this.editor.setCursorBufferPosition([newRow, goalColumn]))
        }
        this.emitDidMoveToPrompt()
      } else {
        this.items.selectItemForRow(newRow)
        if (headerWasSkipped) {
          this.moveToSelectedItem({column: goalColumn})
        }
        if (this.isPromptRow(oldRow)) this.emitDidMoveToItemArea()
        if (this.autoPreview) this.previewWithDelay()
      }
    })
  }

  // itemHaveAlreadyOpened: ->
  selectedItemFileHaveAlreadyOpened() {
    if (this.boundToSingleFile) {
      return true
    } else {
      const pane = this.provider.getPane()
      const selectedItem = this.items.getSelectedItem()
      return pane && selectedItem && pane.itemForURI(selectedItem.filePath)
    }
  }

  previewWithDelay() {
    this.cancelDelayedPreview()
    const delay = this.selectedItemFileHaveAlreadyOpened() ? 0 : 20
    const preview = () => {
      this.delayedPreviewTimeout = null
      this.preview()
    }
    this.delayedPreviewTimeout = setTimeout(preview, delay)
  }

  cancelDelayedPreview() {
    if (this.delayedPreviewTimeout) {
      clearTimeout(this.delayedPreviewTimeout)
      this.delayedPreviewTimeout = null
    }
  }

  syncToEditor(editor) {
    if (this.inPreview) return

    const point = editor.getCursorBufferPosition()
    const findOption = this.boundToSingleFile ? undefined : {filePath: editor.getPath()}

    const item = this.items.findClosestItemForBufferPosition(point, findOption)

    if (item) {
      this.items.selectItem(item)
      const wasAtPrompt = this.isAtPrompt()
      this.moveToSelectedItem()
      this.scrollToColumnZero()
      if (wasAtPrompt) this.emitDidMoveToItemArea()
    }
  }

  isInSyncToProviderEditor() {
    return (
      this.boundToSingleFile ||
      this.items.getSelectedItem().filePath === this.provider.editor.getPath()
    )
  }

  moveToSelectedItem({ignoreCursorMove = true, column} = {}) {
    const row = this.items.getRowForSelectedItem()
    if (row === -1) return

    column = column != null ? column : this.editor.getCursorBufferPosition().column
    const point = [row, column]
    const moveAndScroll = () => {
      // Manually set cursor to center to avoid scrollTop drastically changes
      // when refresh and auto-sync.
      this.editor.setCursorBufferPosition(point, {autoscroll: false})
      this.editor.scrollToBufferPosition(point, {center: true})
    }

    if (ignoreCursorMove) {
      this.withIgnoreCursorMove(moveAndScroll)
    } else {
      moveAndScroll()
    }
  }

  preview() {
    if (this.suppressPreview) return
    if (!this.isActive()) return
    const item = this.items.getSelectedItem()
    if (!item) return

    this.inPreview = true
    return this.provider.openFileForItem(item, {activatePane: false}).then(editor => {
      editor.scrollToBufferPosition(item.point, {center: true})
      this.inPreview = false
      this.emitDidPreview({editor, item})
    })
  }

  confirm({keepOpen, flash} = {}) {
    const item = this.items.getSelectedItem()
    if (!item) return

    const needDestroy = !keepOpen && !this.protected && this.provider.getConfig("closeOnConfirm")
    const onConfirm = editor => {
      if (!editor) return
      if (needDestroy) {
        // when editor.destroyed here, setScrollTop request done at @provider.confirmed is
        // not correctly respected unless updateSyncing here.
        editor.element.component.updateSync()
        this.editor.destroy()
      } else {
        if (flash) this.highlighter.flashItem(editor, item)
        this.emitDidConfirm({editor, item})
      }
    }
    return this.provider.confirmed(item).then(onConfirm)
  }

  // Cursor move and position status
  // ------------------------------
  isAtSelectedItem() {
    return this.editor.getCursorBufferPosition().row === this.items.getRowForSelectedItem()
  }

  moveToDifferentFileItem(direction) {
    if (!this.isAtSelectedItem()) {
      this.moveToSelectedItem({ignoreCursorMove: false})
      return
    }

    // Fallback to selected item in case there is only single filePath in all items
    // But want to move to item from query-prompt.
    const item = this.items.findDifferentFileItem(direction) || this.items.getSelectedItem()
    if (item) {
      this.items.selectItem(item)
      this.moveToSelectedItem({ignoreCursorMove: false})
    }
  }

  moveToPromptOrSelectedItem() {
    if (this.isAtSelectedItem()) {
      this.moveToPrompt()
    } else {
      this.moveToBeginningOfSelectedItem()
    }
  }

  moveToSearchedWordOrBeginningOfSelectedItem() {
    const {searchOptions} = this.provider
    if (searchOptions && searchOptions.searchRegex) {
      this.moveToSearchedWordAtSelectedItem(this.provider.searchOptions.searchRegex)
    } else {
      this.moveToBeginningOfSelectedItem()
    }
  }

  moveToBeginningOfSelectedItem() {
    if (this.items.hasSelectedItem()) {
      const point = this.items.getFirstPositionForSelectedItem()
      this.editor.setCursorBufferPosition(point)
    }
  }

  moveToSearchedWordAtSelectedItem(searchRegex) {
    const item = this.items.getSelectedItem()
    if (!item) return

    const cursorPosition = this.provider.editor.getCursorBufferPosition()
    const {row, column} = this.items.getFirstPositionForItem(item)
    const columnDelta = this.isInSyncToProviderEditor()
      ? cursorPosition.column
      : cloneRegExp(searchRegex).exec(item.text).index
    this.editor.setCursorBufferPosition([row, column + columnDelta])
  }

  moveToPrompt() {
    this.withIgnoreCursorMove(() => {
      this.editor.setCursorBufferPosition(this.getPromptRange().end)
      this.setReadOnly(false)
      this.emitDidMoveToPrompt()
    })
  }

  isPromptRow(row) {
    return row === 0
  }

  isAtPrompt() {
    return this.isPromptRow(this.editor.getCursorBufferPosition().row)
  }

  getTextForItem(item) {
    return this.editor.lineTextForBufferRow(this.items.getRowForItem(item))
  }

  getNormalItemsForEditor(editor) {
    if (this.boundToSingleFile) {
      return this.items.getNormalItems()
    } else {
      return this.items.getNormalItems(editor.getPath())
    }
  }

  getPromptRange() {
    return this.editor.bufferRangeForBufferRow(0)
  }

  // Return range
  setQuery(text = "") {
    if (this.editor.getLastBufferRow() === 0) {
      this.editor.setTextInBufferRange([[0, 0], this.itemAreaStart], text + "\n")
    } else {
      this.editor.setTextInBufferRange([[0, 0], [0, Infinity]], text)
    }
    this.refreshPromptHighlight()
  }

  startSyncToEditor(editor) {
    if (this.syncSubcriptions) this.syncSubcriptions.dispose()
    this.syncSubcriptions = new CompositeDisposable()
    const oldFilePath = this.provider.editor.getPath()
    const newFilePath = editor.getPath()

    this.provider.bindEditor(editor)
    this.syncToEditor(editor)

    this.syncSubcriptions.add(
      editor.onDidChangeCursorPosition(event => {
        if (event.textChanged) return

        if (!this.itemHaveRange && event.oldBufferPosition.row === event.newBufferPosition.row) {
          return
        }
        if (isActiveEditor(editor)) this.syncToEditor(editor)
      })
    )

    this.syncSubcriptions.add(
      this.onDidRefresh(() => {
        if (isActiveEditor(editor)) this.syncToEditor(editor)
      })
    )

    if (this.boundToSingleFile && !isDefinedAndEqual(oldFilePath, newFilePath)) {
      this.refresh({force: true})
    }

    if (this.refreshOnDidStopChanging) {
      this.syncSubcriptions.add(
        editor.onDidStopChanging(({changes}) => {
          if (this.isActive()) return
          this.refresh({force: true, event: {changes, filePath: editor.getPath()}})
        })
      )
    }

    if (this.refreshOnDidSave) {
      this.syncSubcriptions.add(
        editor.onDidSave(event => {
          if (this.isActive()) return
          setTimeout(() => {
            this.refresh({force: true, event: {filePath: event.path}})
          }, 0)
        })
      )
    }
  }

  // vim-mode-plus integration
  // -------------------------
  vmpActivateNormalMode() {
    atom.commands.dispatch(this.editorElement, "vim-mode-plus:activate-normal-mode")
  }

  vmpActivateInsertMode() {
    atom.commands.dispatch(this.editorElement, "vim-mode-plus:activate-insert-mode")
  }

  vmpIsInsertMode() {
    return this.vmpIsEnabled() && this.editorElement.classList.contains("insert-mode")
  }

  vmpIsNormalMode() {
    return this.vmpIsEnabled() && this.editorElement.classList.contains("normal-mode")
  }

  vmpIsEnabled() {
    return this.editorElement.classList.contains("vim-mode-plus")
  }

  // Direct-edit related
  // -------------------------
  updateRealFile() {
    if (!this.supportDirectEdit) return
    if (!this.isModified()) return

    if (settings.get("confirmOnUpdateRealFile")) {
      const options = {message: "Update real file?", buttons: ["Update", "Cancel"]}
      if (atom.confirm(options) !== 0) return
    }

    if (this.editorLastRow !== this.editor.getLastBufferRow()) return

    // Ensure all item have valid line header
    if (this.showLineHeader) {
      const itemHaveOriginalLineHeader = item => {
        return this.editor
          .lineTextForBufferRow(this.items.getRowForItem(item))
          .startsWith(item._lineHeader)
      }

      if (!this.items.getNormalItems().every(itemHaveOriginalLineHeader)) return
    }

    const changes = []
    const lines = this.editor.buffer.getLines()
    for (let row = 0; row < lines.length; row++) {
      const item = this.items.getItemForRow(row)
      if (!isNormalItem(item)) continue
      const lineHeaderEnd = item._lineHeader != null ? item._lineHeader.length : 0
      const line = lines[row].slice(lineHeaderEnd)
      if (line !== item.text) {
        changes.push({newText: line, item})
      }
    }

    if (!changes.length) return

    const {success, message} = ensureNoConflictForChanges(changes)
    if (!success) {
      atom.notifications.addWarning(message, {dismissable: true})
      return
    }

    this.provider.updateRealFile(changes)
    this.setModifiedState(false)
  }
}
Ui.initClass()

module.exports = Ui
