'use babel'

const _ = require('underscore-plus')
const {Point, Range, CompositeDisposable, Disposable, Emitter} = require('atom')
const {
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  isActiveEditor,
  setBufferRow,
  paneForItem,
  cloneRegExp,
  suppressEvent,
  getCurrentWord,
  parsePromptLine
} = require('./utils')

const itemReducer = require('./item-reducer')
const settings = require('./settings')
const Highlighter = require('./highlighter')
const ControlBar = require('./control-bar')
const Items = require('./items')
const ItemIndicator = require('./item-indicator')
const queryHistory = require('./query-history')
const updateRealFile = require('./update-real-file')
let SelectFiles

const PROMPT_RANGE = Object.freeze(new Range([0, 0], [0, Infinity]))
const ITEM_START_POINT = Object.freeze(new Point(1, 0))

function rangeIntersectsWithPrompt (range) {
  return range.intersectsWith(PROMPT_RANGE)
}

module.exports = class Ui {
  static uiByEditor = new Map()
  static queryHistory = queryHistory

  static unregister (ui) {
    this.uiByEditor.delete(ui.editor)
    this.updateWorkspaceClassList()
  }

  static register (ui) {
    this.uiByEditor.set(ui.editor, ui)
    this.updateWorkspaceClassList()
  }

  static get (editor) {
    return this.uiByEditor.get(editor)
  }

  static getSize () {
    return this.uiByEditor.size
  }

  static forEach (fn) {
    this.uiByEditor.forEach(fn)
  }

  static updateWorkspaceClassList () {
    const view = atom.views.getView(atom.workspace)
    view.classList.toggle('has-narrow', this.uiByEditor.size)
  }

  static getNextTitleNumber () {
    const numbers = [0]
    this.uiByEditor.forEach(ui => numbers.push(ui.titleNumber))
    return Math.max(...numbers) + 1
  }

  onDidMoveToPrompt (fn) { return this.emitter.on('did-move-to-prompt', fn) } // prettier-ignore
  emitDidMoveToPrompt () { this.emitter.emit('did-move-to-prompt') } // prettier-ignore
  onDidMoveToItemArea (fn) { return this.emitter.on('did-move-to-item-area', fn) } // prettier-ignore
  emitDidMoveToItemArea () { this.emitter.emit('did-move-to-item-area') } // prettier-ignore
  onDidUpdateItems (fn) { return this.emitter.on('did-update-items', fn) } // prettier-ignore
  emitDidUpdateItems (event) { this.emitter.emit('did-update-items', event) } // prettier-ignore
  onDidFinishUpdateItems (fn) { return this.emitter.on('did-finish-update-items', fn) } // prettier-ignore
  emitDidFinishUpdateItems () { this.emitter.emit('did-finish-update-items') } // prettier-ignore
  onDidDestroy (fn) { return this.emitter.on('did-destroy', fn) } // prettier-ignore
  emitDidDestroy () { this.emitter.emit('did-destroy') } // prettier-ignore
  onDidRefresh (fn) { return this.emitter.on('did-refresh', fn) } // prettier-ignore
  emitDidRefresh () { this.emitter.emit('did-refresh') } // prettier-ignore
  onWillRefresh (fn) { return this.emitter.on('will-refresh', fn) } // prettier-ignore
  emitWillRefresh () { this.emitter.emit('will-refresh') } // prettier-ignore
  onWillRefreshManually (fn) { return this.emitter.on('will-refresh-manually', fn) } // prettier-ignore
  emitWillRefreshManually () { this.emitter.emit('will-refresh-manually') } // prettier-ignore
  onDidPreview (fn) { return this.emitter.on('did-preview', fn) } // prettier-ignore
  emitDidPreview (event) { this.emitter.emit('did-preview', event) } // prettier-ignore
  onDidConfirm (fn) { return this.emitter.on('did-confirm', fn) } // prettier-ignore
  emitDidConfirm (event) { this.emitter.emit('did-confirm', event) } // prettier-ignore

  onDidStopRefreshing (fn) {
    return this.emitter.on('did-stop-refreshing', fn)
  }

  emitDidStopRefreshing () {
    // Debounced, fired after 100ms delay
    if (!this._emitDidStopRefreshing) {
      this._emitDidStopRefreshing = _.debounce(() => {
        this.emitter.emit('did-stop-refreshing')
      }, 100)
    }
    this._emitDidStopRefreshing()
  }

  registerCommands () {
    return atom.commands.add(this.editorElement, {
      'core:confirm': () => this.confirm(),
      'core:move-up': event => this.moveUpOrDownWrap(event, 'up'),
      'core:move-down': event => this.moveUpOrDownWrap(event, 'down'),

      // HACK: PreserveGoalColumn when skipping header row.
      // Following command is earlily invoked than original move-up(down)-wrap,
      // because it's directly defined on @editorElement.
      // Actual movement is still done by original command since command event is propagated.
      'vim-mode-plus:move-up-wrap': () => this.preserveGoalColumn(),
      'vim-mode-plus:move-down-wrap': () => this.preserveGoalColumn(),

      'narrow-ui:confirm-keep-open': () => this.confirm({keepOpen: true}),
      'narrow-ui:open-here': () => this.confirm({openAtUiPane: true}),

      'narrow-ui:protect': () => this.toggleProtected(),
      'narrow-ui:preview-item': () => this.preview(),
      'narrow-ui:preview-next-item': () => this.previewItemForDirection('next'),
      'narrow-ui:preview-previous-item': () => this.previewItemForDirection('previous'),
      'narrow-ui:toggle-auto-preview': () => this.toggleAutoPreview(),
      'narrow-ui:move-to-prompt-or-selected-item': () => this.moveToPromptOrSelectedItem(),
      'narrow-ui:move-to-prompt': () => this.moveToPrompt(),
      'narrow-ui:start-insert': () => this.setReadOnly(false),
      'narrow-ui:stop-insert': () => this.setReadOnly(true),
      'narrow-ui:update-real-file': () => this.updateRealFile(),
      'narrow-ui:exclude-file': () => this.excludeFile(),
      'narrow-ui:select-files': () => this.selectFiles(),
      'narrow-ui:clear-excluded-files': () => this.clearExcludedFiles(),
      'narrow-ui:move-to-next-file-item': () => this.moveToDifferentFileItem('next'),
      'narrow-ui:move-to-previous-file-item': () => this.moveToDifferentFileItem('previous'),
      'narrow-ui:toggle-search-whole-word': () => this.toggleSearchWholeWord(),
      'narrow-ui:toggle-search-ignore-case': () => this.toggleSearchIgnoreCase(),
      'narrow-ui:toggle-search-use-regex': () => this.toggleSearchUseRegex(),
      'narrow-ui:delete-to-end-of-search-term': () => this.deleteToEndOfSearchTerm(),
      'narrow-ui:clear-query-history': () => this.clearHistroy()
    })
  }

  setQueryFromHistroy (direction, retry) {
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

  clearHistroy () {
    queryHistory.clear(this.provider.name)
  }

  resetHistory () {
    queryHistory.reset(this.provider.name)
  }

  saveQueryHistory (text) {
    queryHistory.save(this.provider.name, text)
  }

  withIgnoreCursorMove (fn) {
    this.ignoreCursorMove = true
    fn()
    this.ignoreCursorMove = false
  }

  withIgnoreChange (fn) {
    this.ignoreChange = true
    fn()
    this.ignoreChange = false
  }

  isModified () {
    return this.modifiedState
  }

  getState () {
    return {
      excludedFiles: this.excludedFiles,
      queryForSelectFiles: this.queryForSelectFiles
    }
  }

  getSearchTermFromQuery () {
    const range = this.parsePromptLine().searchTerm
    return this.editor.getTextInBufferRange(range)
  }

  deleteToEndOfSearchTerm () {
    if (!this.isAtPrompt()) return

    const searchTermRange = this.parsePromptLine().searchTerm
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

  async queryCurrentWord () {
    const word = getCurrentWord(atom.workspace.getActiveTextEditor()).trim()
    if (!word) return

    this.saveQueryHistory(word)
    this.withIgnoreChange(() => this.setQuery(word))
    await this.refresh({force: true})
    this.moveToSearchedWordOrBeginningOfSelectedItem()
    if (!this.isActive()) this.scrollToColumnZero()
    this.flashCursorLine()
  }

  scrollToColumnZero () {
    const {row} = this.editor.getCursorBufferPosition()
    this.editor.scrollToBufferPosition([row, 0], {center: true})
  }

  refreshPromptHighlight () {
    this.highlighter.highlightPrompt(this.parsePromptLine())
  }

  // Return range for {searchTerm, includeFilters, excludeFilters}
  parsePromptLine () {
    return parsePromptLine(this.getQuery(), {
      negateByEndingExclamation: this.negateByEndingExclamation,
      useFirstQueryAsSearchTerm: this.useFirstQueryAsSearchTerm
    })
  }

  setModifiedState (state) {
    if (state === this.modifiedState) return

    // HACK: overwrite TextBuffer:isModified to return static state.
    // This state is used by tabs package to show modified icon on tab.
    this.modifiedState = state
    this.editor.buffer.isModified = () => state
    this.editor.buffer.emitModifiedStatusChanged(state)
  }

  toggleSearchWholeWord (event) {
    suppressEvent(event)
    this.provider.searchOptions.toggle('searchWholeWord')
    this.refresh({force: true})
  }

  toggleSearchIgnoreCase (event) {
    suppressEvent(event)
    this.provider.searchOptions.toggle('searchIgnoreCase')
    this.refresh({force: true})
  }

  toggleSearchUseRegex (event) {
    suppressEvent(event)
    this.provider.searchOptions.toggle('searchUseRegex')
    this.refresh({force: true})
  }

  toggleProtected (event) {
    suppressEvent(event)
    this.protected = !this.protected
    this.itemIndicator.update({protected: this.protected})
    this.controlBar.updateElements({protected: this.protected})
  }

  toggleAutoPreview (event) {
    suppressEvent(event)
    this.autoPreview = !this.autoPreview
    this.controlBar.updateElements({autoPreview: this.autoPreview})
    this.highlighter.clearCurrentAndLineMarker()
    if (this.autoPreview) this.preview()
  }

  setReadOnly (readOnly) {
    this.readOnly = readOnly
    const {component, classList} = this.editorElement
    if (readOnly) {
      if (component) component.setInputEnabled(false)
      classList.add('read-only')
      if (this.vmpIsInsertMode()) this.vmpActivateNormalMode()
    } else {
      if (component) component.setInputEnabled(true)
      classList.remove('read-only')
      if (this.vmpIsNormalMode()) this.vmpActivateInsertMode()
    }
  }

  constructor (provider, {query = ''} = {}, restoredState) {
    if (!SelectFiles) {
      SelectFiles = require('./provider/select-files')
    }
    this.provider = provider
    this.query = query

    // Pull never changing info-only-properties from provider.
    this.showSearchOption = provider.showSearchOption
    this.showProjectHeader = provider.showProjectHeader
    this.showFileHeader = provider.showFileHeader
    this.showColumnOnLineHeader = provider.showColumnOnLineHeader
    this.boundToSingleFile = provider.boundToSingleFile
    this.itemHaveRange = provider.itemHaveRange
    this.supportDirectEdit = provider.supportDirectEdit
    this.supportCacheItems = provider.supportCacheItems
    this.supportFilePathOnlyItemsUpdate = provider.supportFilePathOnlyItemsUpdate
    this.useFirstQueryAsSearchTerm = provider.useFirstQueryAsSearchTerm
    this.reopened = provider.reopened
    this.refreshOnDidSave = provider.refreshOnDidSave
    this.refreshOnDidStopChanging = provider.refreshOnDidStopChanging

    // Initial state
    this.inPreview = false
    this.suppressPreview = false
    this.ignoreChange = false
    this.ignoreCursorMove = false
    this.destroyed = false
    this.lastQuery = ''
    this.lastSearchTerm = ''
    this.modifiedState = null
    this.readOnly = false
    this.protected = false
    this.excludedFiles = []
    this.queryForSelectFiles = null
    this.delayedRefreshTimeout = null
    this.queryForSelectFiles = SelectFiles.getLastQuery(this.provider.name)

    // This is `narrow:reopen`, to restore STATE properties.
    if (restoredState) Object.assign(this, restoredState)

    this.disposables = new CompositeDisposable()
    this.emitter = new Emitter()

    this.autoPreview = this.provider.getConfig('autoPreview')
    this.autoPreviewOnQueryChange = this.provider.getConfig('autoPreviewOnQueryChange')
    this.negateByEndingExclamation = this.provider.getConfig('negateNarrowQueryByEndingExclamation')
    this.showLineHeader = this.provider.getConfig('showLineHeader')

    this.toggleSearchWholeWord = this.toggleSearchWholeWord.bind(this)
    this.toggleSearchIgnoreCase = this.toggleSearchIgnoreCase.bind(this)
    this.toggleSearchUseRegex = this.toggleSearchUseRegex.bind(this)
    this.toggleProtected = this.toggleProtected.bind(this)
    this.toggleAutoPreview = this.toggleAutoPreview.bind(this)
    this.selectFiles = this.selectFiles.bind(this)
    this.refreshManually = this.refreshManually.bind(this)
    this.renderItems = this.renderItems.bind(this)
    this.preview = this.preview.bind(this)

    this.reducers = [
      itemReducer.spliceItemsForFilePath,
      this.showLineHeader && itemReducer.injectLineHeader,
      itemReducer.collectAllItems,
      itemReducer.filterFilePath,
      itemReducer.filterItems,
      this.showProjectHeader && itemReducer.insertProjectHeader,
      this.showFileHeader && itemReducer.insertFileHeader,
      this.renderItems
    ].filter(reducer => reducer)

    // Setup narrow-editor
    // -------------------------
    this.editor = atom.workspace.buildTextEditor({
      lineNumberGutterVisible: false,
      autoHeight: false
    })
    this.titleNumber = this.constructor.getNextTitleNumber()
    const title = this.provider.dashName + '-' + this.titleNumber
    this.editor.getTitle = () => title
    this.editor.onDidDestroy(this.destroy.bind(this))
    this.editorElement = this.editor.element
    this.editorElement.classList.add('narrow', 'narrow-editor', this.provider.dashName)
    this.setModifiedState(false)
    this.highlighter = new Highlighter(this)

    this.items = new Items(this)
    this.itemIndicator = new ItemIndicator(this.editor, this.items)

    this.onDidMoveToItemArea(() => {
      if (settings.get('autoShiftReadOnlyOnMoveToItemArea')) this.setReadOnly(true)
      this.editorElement.classList.remove('prompt')
    })

    this.onDidMoveToPrompt(() => {
      this.editorElement.classList.add('prompt')
    })

    this.editorElement.onDidChangeScrollTop(scrollTop => {
      this.highlighter.clearItemsHighlightOnNarrowEditor()
      this.highlighter.highlightItemsOnNarrowEditor(this.items.getVisibleItems(), this.filterSpec)
    })

    // FIXME order dependent, must be at last.
    this.controlBar = new ControlBar(this)
    this.constructor.register(this)
  }

  getPaneToOpen () {
    const basePane = this.provider.getPane()
    const directionToOpen = this.provider.getConfig('directionToOpen')
    const [direction, preference] = directionToOpen.split(':')

    let pane
    if (preference === 'always-new-pane') {
      pane = null
    } else if (preference === 'never-use-previous-adjacent-pane') {
      pane = getNextAdjacentPaneForPane(basePane)
    } else {
      pane = getNextAdjacentPaneForPane(basePane) || getPreviousAdjacentPaneForPane(basePane)
    }

    return pane || splitPane(basePane, {split: direction})
  }

  async open ({pending = false, focus = true, pane = null} = {}) {
    // [NOTE] When new item is activated, existing PENDING item is destroyed.
    // So existing PENDING narrow-editor is destroyed at this timing.
    // And PENDING narrow-editor's provider's editor have foucsed.
    // So pane.activate must be called AFTER activateItem
    if (!pane) {
      pane = this.getPaneToOpen()
    }
    // atom.workspace.open(this.editor, {pending, pane})
    pane.activateItem(this.editor, {pending})
    this.editor.setGrammar(atom.grammars.grammarForScopeName('source.narrow'))

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

    await this.refresh()

    if (this.provider.needRevealOnStart()) {
      this.syncToEditor(this.provider.editor)
      if (this.items.hasSelectedItem()) {
        this.suppressPreview = true
        this.moveToSearchedWordOrBeginningOfSelectedItem()
        this.suppressPreview = false
        const previewd = await this.preview()
        if (previewd) this.flashCursorLine()
      }
    } else if (this.query && this.autoPreviewOnQueryChange) {
      await this.preview()
    }
  }

  flashCursorLine () {
    const itemCount = this.items.getNormalItemCount()
    if (itemCount <= 5) return

    const flashSpec =
      itemCount < 10
        ? {duration: 1000, class: 'narrow-cursor-line-flash-medium'}
        : {duration: 2000, class: 'narrow-cursor-line-flash-long'}

    if (this.cursorLineFlashMarker) this.cursorLineFlashMarker.destroy()
    const point = this.editor.getCursorBufferPosition()
    this.cursorLineFlashMarker = this.editor.markBufferPosition(point)
    const decorationOptions = {type: 'line', class: flashSpec.class}
    this.editor.decorateMarker(this.cursorLineFlashMarker, decorationOptions)

    const destroyMarker = () => {
      if (this.cursorLineFlashMarker) this.cursorLineFlashMarker.destroy()
      this.cursorLineFlashMarker = null
    }
    setTimeout(destroyMarker, flashSpec.duration)
  }

  getPane () {
    return paneForItem(this.editor)
  }

  isSamePaneItem (item) {
    return paneForItem(item) === this.getPane()
  }

  isActive () {
    return isActiveEditor(this.editor)
  }

  focus ({autoPreview = this.autoPreview} = {}) {
    const pane = this.getPane()
    pane.activate()
    pane.activateItem(this.editor)
    if (autoPreview) this.preview()
  }

  focusPrompt () {
    if (this.isActive() && this.isAtPrompt()) {
      this.activateProviderPane()
    } else {
      if (!this.isActive()) this.focus()
      this.moveToPrompt()
    }
  }

  toggleFocus () {
    if (this.isActive()) {
      this.activateProviderPane()
    } else {
      this.focus()
    }
  }

  activateProviderPane () {
    const pane = this.provider.getPane()
    if (!pane) return

    // [BUG?] maybe upstream Atom-core bug?
    // In rare situation( I observed only in test-spec ), there is the situation
    // where pane.isAlive but paneContainer.getPanes() in pane return `false`
    // Without folowing guard "Setting active pane that is not present in pane container"
    // exception thrown.
    const panes = pane.getContainer().getPanes()
    if (panes.includes(pane)) {
      pane.activate()
      const editor = pane.getActiveEditor()
      if (editor) editor.scrollToCursorPosition()
    }
  }

  isAlive () {
    return !this.destroyed
  }

  destroy () {
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

  close () {
    this.provider.restoreEditorStateIfNecessary()
    this.getPane().destroyItem(this.editor, true)
  }

  resetQuery () {
    this.setQuery('')
    this.moveToPrompt()
    this.controlBar.show()
  }

  preserveGoalColumn () {
    // HACK: In narrow-editor, header row is skipped onDidChangeCursorPosition event
    // But at this point, cursor.goalColumn is explicitly cleared by atom-core
    // I want use original goalColumn info within onDidChangeCursorPosition event
    // to keep original column when header item was auto-skipped.
    const cursor = this.editor.getLastCursor()
    this.goalColumn = cursor.goalColumn != null ? cursor.goalColumn : cursor.getBufferColumn()
  }

  // Line-wrapped version of 'core:move-up' override default behavior
  moveUpOrDownWrap (event, direction) {
    this.preserveGoalColumn()

    const cursor = this.editor.getLastCursor()
    const cursorRow = cursor.getBufferRow()
    const lastRow = this.editor.getLastBufferRow()

    if (direction === 'up' && cursorRow === 0) {
      setBufferRow(cursor, lastRow)
      event.stopImmediatePropagation()
    } else if (direction === 'down' && cursorRow === lastRow) {
      setBufferRow(cursor, 0)
      event.stopImmediatePropagation()
    }
  }

  // Even in movemnt not happens, it should confirm current item
  // This ensure next-item/previous-item always move to selected item.
  confirmItemForDirection (direction) {
    this.items.selectRelativeItem(this.provider.editor, direction)
    this.confirm({keepOpen: true, flash: true})
  }

  previewItemForDirection (direction) {
    if (!this.items.hasSelectedItem()) {
      return
    }
    const selectedItem = this.items.getSelectedItem()

    // When initial invocation not cause preview(since initial query input was empty).
    // Don't want `tab` skip first seleted item.
    const firstTimeNext = !this.highlighter.hasLineMarker() && direction === 'next'
    const itemToSelect = firstTimeNext ? selectedItem : this.items.findNormalItem(selectedItem._row, {direction})
    if (itemToSelect) {
      this.items.selectItem(itemToSelect)
      this.preview()
    }
  }

  getQuery () {
    return this.editor.getTextInBufferRange(PROMPT_RANGE)
  }

  getFilterQuery () {
    if (this.useFirstQueryAsSearchTerm) {
      // Extracet filterQuery by removing searchTerm part from query
      return this.getQuery().replace(/^.*?\S+\s*/, '')
    } else {
      return this.getQuery()
    }
  }

  excludeFile () {
    if (this.boundToSingleFile) return

    const selectedItem = this.items.getSelectedItem()
    if (!selectedItem) return
    const {filePath} = selectedItem
    if (filePath && !this.excludedFiles.includes(filePath)) {
      this.excludedFiles.push(filePath)
      this.moveToDifferentFileItem('next')
      this.refresh()
    }
  }

  selectFiles (event) {
    suppressEvent(event)
    if (this.boundToSingleFile) return

    return new SelectFiles(this.editor, {
      query: this.queryForSelectFiles,
      pane: this.getPane(),
      clientUi: this
    }).start()
  }

  async resetQueryForSelectFiles (queryForSelectFiles) {
    this.queryForSelectFiles = queryForSelectFiles
    this.excludedFiles = []
    this.focus({autoPreview: false})
    await this.refresh()
  }

  clearExcludedFiles () {
    if (this.boundToSingleFile) return

    this.excludedFiles = []
    this.queryForSelectFiles = ''
    this.refresh()
  }

  updateSearchOptions (searchTerm) {
    const {searchOptions} = this.provider
    searchOptions.setSearchTerm(searchTerm)

    this.highlighter.setRegExp(searchOptions.searchRegex)

    this.controlBar.updateElements({
      searchRegex: searchOptions.searchRegex,
      searchWholeWord: searchOptions.searchWholeWord,
      searchIgnoreCase: searchOptions.searchIgnoreCase,
      searchTerm: searchOptions.searchTerm,
      searchUseRegex: searchOptions.searchUseRegex
    })
  }

  reduceItems (state, items) {
    this.reducers.reduce(
      (state, reducer) => Object.assign(state, reducer(state)),
      Object.assign(state, {items, reduced: true})
    )
  }

  createStateToReduce () {
    return {
      reduced: false,
      hasCachedItems: this.items.cachedItems != null,
      showColumn: this.showColumnOnLineHeader,
      maxRow: this.boundToSingleFile ? this.provider.editor.getLastBufferRow() : undefined,
      boundToSingleFile: this.boundToSingleFile,
      projectHeadersInserted: new Set(),
      fileHeadersInserted: new Set(),
      allItems: [],
      filterSpec: this.provider.getFilterSpec(this.getFilterQuery()),
      filterSpecForSelectFiles: SelectFiles.prototype.getFilterSpec(this.queryForSelectFiles),
      fileExcluded: false,
      excludedFiles: this.excludedFiles,
      renderStartPosition: ITEM_START_POINT
    }
  }

  startUpdateItemCount () {
    const intervalID = setInterval(() => {
      this.controlBar.updateElements({itemCount: this.items.getNormalItemCount()})
    }, 500)
    return new Disposable(() => clearInterval(intervalID))
  }

  getFilePathsForAllItems () {
    return this.filePathsForAllItems
  }

  updateFilePathsFromState (state) {
    this.filePathsForAllItems = _.chain(state.allItems)
      .pluck('filePath')
      .uniq()
      .value()
  }

  updateControlBarRefreshElement () {
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

  cancelRefresh () {
    if (this.refreshDisposables) {
      this.refreshDisposables.dispose()
      this.refreshDisposables = null
    }
  }

  // Return promise
  async refresh ({force, selectFirstItem, event = {}} = {}) {
    this.highlighter.clearItemsHighlightOnNarrowEditor()
    this.cancelRefresh()

    this.filePathsForAllItems = []
    this.highlighter.clearCurrentAndLineMarker()
    this.emitWillRefresh()

    this.lastQuery = this.getQuery()

    let searchTerm
    if (this.useFirstQueryAsSearchTerm) {
      searchTerm = this.getSearchTermFromQuery()
      if (this.lastSearchTerm !== searchTerm) {
        this.lastSearchTerm = searchTerm
        force = true
      }
    }

    const spliceFilePath = event.filePath
    let cachedNormalItems
    if (this.supportFilePathOnlyItemsUpdate && spliceFilePath && this.items.cachedItems) {
      cachedNormalItems = this.items.cachedItems.filter(item => !item.skip)
    }

    if (force) this.items.clearCachedItems()

    let resolveGetItem
    const getItemPromise = new Promise(resolve => {
      resolveGetItem = resolve
    })

    const state = this.createStateToReduce()
    Object.assign(state, {cachedNormalItems, spliceFilePath})
    this.filterSpec = state.filterSpec // preserve to use for highlight narrow-editor

    const reduceItems = this.reduceItems.bind(this, state)

    const onFinish = () => {
      // When no items set via onDidUpdateItems after after requestItems, manually update with empty items.
      // e.g.
      //   1. search `editor` found 100 items
      //   2. search `editorX` found 0 items (clear items via emitDidUpdateItems([]))
      if (!state.reduced) reduceItems([])
      this.cancelRefresh()

      if (!this.boundToSingleFile) {
        this.updateFilePathsFromState(state)
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
        itemCount: this.items.getNormalItemCount(),
        refresh: false
      })
      resolveGetItem()
    }

    this.refreshDisposables = new CompositeDisposable(
      this.updateControlBarRefreshElement(),
      this.startUpdateItemCount(),
      this.onDidUpdateItems(reduceItems),
      this.onDidFinishUpdateItems(onFinish)
    )

    // Preserve oldSelectedItem before calling @items.reset()
    const oldSelectedItem = this.items.getSelectedItem()
    const oldColumn = this.editor.getCursorBufferPosition().column

    this.items.reset()

    if (this.items.cachedItems) {
      this.emitDidUpdateItems(this.items.cachedItems)
      this.emitDidFinishUpdateItems()
    } else {
      if (searchTerm != null) {
        this.updateSearchOptions(searchTerm)
      }
      this.provider.getItems(event)
    }

    await getItemPromise
    this.emitDidRefresh()
    this.emitDidStopRefreshing()
  }

  refreshManually (event) {
    suppressEvent(event)
    this.emitWillRefreshManually()
    this.refresh({force: true})
  }

  // reducer
  // -------------------------
  renderItems ({renderStartPosition, items, filterSpec}) {
    const firstRender = renderStartPosition.isEqual(ITEM_START_POINT)
    // avoid rendering empty line when no items(= all items this chunks are filtered).
    if (!items.length && !firstRender) return

    this.items.addItems(items)

    const firstItemRow = renderStartPosition.row

    const texts = items.map(item => this.provider.viewForItem(item))
    this.withIgnoreChange(() => {
      if (this.editor.getLastBufferRow() === 0) {
        this.resetQuery()
      }

      const eof = this.editor.getEofBufferPosition()
      let text = (firstRender ? '' : '\n') + texts.join('\n')
      const range = [renderStartPosition, eof]
      renderStartPosition = this.editor.setTextInBufferRange(range, text, {undo: 'skip'}).end
      this.editorLastRow = renderStartPosition.row
      this.setModifiedState(false)
    })

    const firstVisibleScreenRow = this.editor.getFirstVisibleScreenRow()
    if (Number.isInteger(firstVisibleScreenRow)) {
      const firstVisibleRow = this.editor.bufferRowForScreenRow(firstVisibleScreenRow)
      const start = firstVisibleRow - firstItemRow
      const visibleCount = start + this.editor.getRowsPerPage()
      if (visibleCount > 0) {
        const visibleItems = items.slice(Math.max(start, 0), visibleCount)
        this.highlighter.highlightItemsOnNarrowEditor(visibleItems, filterSpec)
      }
    }
    return {renderStartPosition}
  }

  destroyPromptSelections () {
    let destroyed = false
    for (const selection of this.editor.getSelections()) {
      if (rangeIntersectsWithPrompt(selection.getBufferRange())) {
        destroyed = true
        selection.destroy()
      }
    }
    if (destroyed) {
      this.controlBar.show()
      this.withIgnoreChange(() => this.setQuery(this.lastQuery)) // Recover query
    }
  }

  observeChange () {
    return this.editor.buffer.onDidChange(event => {
      if (this.ignoreChange) return

      const isQueryModified =
        (!event.newRange.isEmpty() && rangeIntersectsWithPrompt(event.newRange)) ||
        (!event.oldRange.isEmpty() && rangeIntersectsWithPrompt(event.oldRange))

      if (!isQueryModified) {
        this.setModifiedState(true) // Item area modified, direct-edit so don't refresh editor!
        return
      }

      if (this.editor.hasMultipleCursors()) {
        // Destroy cursors on prompt to protect query from mutation on 'find-and-replace:select-all'( cmd-alt-g ).
        this.destroyPromptSelections()
      } else {
        if (this.lastQuery.trim() === this.getQuery().trim()) return
        const delay =
          this.useFirstQueryAsSearchTerm && this.getSearchTermFromQuery() !== this.lastSearchTerm
            ? this.provider.getConfig('refreshDelayOnSearchTermChange')
            : this.boundToSingleFile ? 0 : 100
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
  refreshWithDelay (options, delay, onRefresh) {
    this.cancelDelayedRefresh()
    this.delayedRefreshTimeout = setTimeout(() => {
      this.delayedRefreshTimeout = null
      this.refresh(options).then(onRefresh)
    }, delay)
  }

  cancelDelayedRefresh () {
    if (this.delayedRefreshTimeout) {
      clearTimeout(this.delayedRefreshTimeout)
      this.delayedRefreshTimeout = null
    }
  }

  observeCursorMove () {
    return this.editor.onDidChangeCursorPosition(event => {
      if (this.ignoreCursorMove) return

      const {oldBufferPosition, newBufferPosition, textChanged, cursor} = event

      // Clear preserved @goalColumn as early as possible to not affect other movement commands.
      const goalColumn = this.goalColumn != null ? this.goalColumn : newBufferPosition.column
      this.goalColumn = null

      if (textChanged || !cursor.selection.isEmpty() || oldBufferPosition.row === newBufferPosition.row) {
        return
      }

      const newRow = newBufferPosition.row
      const oldRow = oldBufferPosition.row
      const direction = newRow > oldRow ? 'next' : 'previous'
      const itemToSelect = this.items.findPromptOrNormalItem(newRow, {direction, includeStartRow: true})
      const rowToSelect = itemToSelect._row
      const headerWasSkipped = newRow !== rowToSelect

      if (this.isPromptRow(rowToSelect)) {
        if (headerWasSkipped) {
          this.withIgnoreCursorMove(() => this.editor.setCursorBufferPosition([rowToSelect, goalColumn]))
        }
        this.emitDidMoveToPrompt()
      } else {
        this.items.selectItem(itemToSelect)
        if (headerWasSkipped) this.moveToSelectedItem({column: goalColumn})
        if (this.isPromptRow(oldRow)) this.emitDidMoveToItemArea()
        if (this.autoPreview) this.previewWithDelay()
      }
    })
  }

  selectedItemFileHaveAlreadyOpened () {
    if (this.boundToSingleFile) {
      return true
    } else {
      const pane = this.provider.getPane()
      const selectedItem = this.items.getSelectedItem()
      return pane && selectedItem && pane.itemForURI(selectedItem.filePath)
    }
  }

  previewWithDelay () {
    this.cancelDelayedPreview()
    const preview = () => {
      this.delayedPreviewTimeout = null
      this.preview()
    }
    this.delayedPreviewTimeout = setTimeout(preview, this.selectedItemFileHaveAlreadyOpened() ? 0 : 20)
  }

  cancelDelayedPreview () {
    if (this.delayedPreviewTimeout) {
      clearTimeout(this.delayedPreviewTimeout)
      this.delayedPreviewTimeout = null
    }
  }

  syncToEditor (editor) {
    if (this.inPreview) return

    const point = editor.getCursorBufferPosition()
    const options = this.boundToSingleFile ? undefined : {filePath: editor.getPath()}
    const item = this.items.findClosestItemForBufferPosition(point, options)

    if (item) {
      this.items.selectItem(item)
      const wasAtPrompt = this.isAtPrompt()
      this.moveToSelectedItem()
      this.scrollToColumnZero()
      if (wasAtPrompt) this.emitDidMoveToItemArea()
    }
  }

  isInSyncToProviderEditor () {
    return this.boundToSingleFile || this.items.getSelectedItem().filePath === this.provider.editor.getPath()
  }

  moveToSelectedItem ({ignoreCursorMove = true, column} = {}) {
    const item = this.items.getSelectedItem()
    if (!item) {
      return
    }
    if (column == null) {
      column = this.editor.getCursorBufferPosition().column
    }
    const point = [item._row, column]
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

  async preview () {
    if (this.suppressPreview) return
    if (!this.isActive()) return
    const item = this.items.getSelectedItem()
    if (!item) return

    this.inPreview = true
    const editor = await this.provider.openFileForItem(item, {activatePane: false})
    editor.scrollToBufferPosition(item.point, {center: true})
    this.inPreview = false

    this.emitDidPreview({editor, item})
    return true
  }

  async confirm ({keepOpen, flash, openAtUiPane} = {}) {
    const item = this.items.getSelectedItem()
    if (!item) return

    const editor = await this.provider.confirmed(item, openAtUiPane)
    if (editor) {
      const needDestroy = !keepOpen && !this.protected && this.provider.getConfig('closeOnConfirm')
      if (needDestroy) {
        // when editor.destroyed here, setScrollTop request done at @provider.confirmed is
        // not correctly respected unless updateSyncing here.
        editor.element.component.updateSync()
        if (openAtUiPane) {
          this.provider.restoreEditorStateIfNecessary({activatePane: false})
        }

        this.editor.destroy()
      } else {
        if (flash) this.highlighter.flashItem(editor, item)
        this.emitDidConfirm({editor, item})
      }
    }
  }

  // Cursor move and position status
  // ------------------------------
  isAtSelectedItem () {
    const selectedItem = this.items.getSelectedItem()
    return selectedItem && this.editor.getCursorBufferPosition().row === selectedItem._row
  }

  moveToDifferentFileItem (direction) {
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

  moveToItemForFilePath (filePath) {
    const item = this.items.findNextItemForFilePath(filePath)
    if (item) {
      this.items.selectItem(item)
      this.moveToSelectedItem({ignoreCursorMove: false})
    }
  }

  moveToPromptOrSelectedItem () {
    if (this.isAtSelectedItem()) {
      this.moveToPrompt()
    } else {
      this.moveToBeginningOfSelectedItem()
    }
  }

  moveToSearchedWordOrBeginningOfSelectedItem () {
    const {searchOptions} = this.provider
    if (searchOptions && searchOptions.searchRegex) {
      this.moveToSearchedWordAtSelectedItem(this.provider.searchOptions.searchRegex)
    } else {
      this.moveToBeginningOfSelectedItem()
    }
  }

  moveToBeginningOfSelectedItem () {
    if (this.items.hasSelectedItem()) {
      this.editor.setCursorBufferPosition(this.items.getFirstPositionForSelectedItem())
    }
  }

  moveToSearchedWordAtSelectedItem (searchRegex) {
    const item = this.items.getSelectedItem()
    if (!item) return
    const columnDelta = this.isInSyncToProviderEditor()
      ? this.provider.editor.getCursorBufferPosition().column
      : cloneRegExp(searchRegex).exec(item.text).index
    const point = this.items.getFirstPositionForItem(item).translate([0, columnDelta])
    this.editor.setCursorBufferPosition(point)
  }

  moveToPrompt () {
    this.withIgnoreCursorMove(() => {
      this.editor.setCursorBufferPosition(PROMPT_RANGE.end)
      this.setReadOnly(false)
      this.emitDidMoveToPrompt()
    })
  }

  isPromptRow (row) {
    return PROMPT_RANGE.start.row === row
  }

  isAtPrompt () {
    return this.isPromptRow(this.editor.getCursorBufferPosition().row)
  }

  getTextForItem (item) {
    return this.editor.lineTextForBufferRow(item._row)
  }

  getNormalItemsForEditor (editor) {
    return this.items.getNormalItems(this.boundToSingleFile ? null : editor.getPath())
  }

  // Return range
  setQuery (text = '') {
    if (this.editor.getLastBufferRow() === 0) {
      this.editor.setTextInBufferRange([[0, 0], ITEM_START_POINT], text + '\n')
    } else {
      this.editor.setTextInBufferRange(PROMPT_RANGE, text)
    }
    this.refreshPromptHighlight()
  }

  startSyncToEditor (editor) {
    if (this.syncSubcriptions) this.syncSubcriptions.dispose()
    const oldFilePath = this.provider.editor.getPath()
    const newFilePath = editor.getPath()

    this.provider.bindEditor(editor)
    this.syncToEditor(editor)

    if (this.boundToSingleFile && (oldFilePath != null && oldFilePath === newFilePath)) {
      this.refresh({force: true})
    }

    this.syncSubcriptions = new CompositeDisposable(
      editor.onDidChangeCursorPosition(event => {
        if (event.textChanged) return
        if (!this.itemHaveRange && event.oldBufferPosition.row === event.newBufferPosition.row) return
        if (isActiveEditor(editor)) {
          this.syncToEditor(editor)
        }
      }),
      this.onDidRefresh(() => {
        if (isActiveEditor(editor)) this.syncToEditor(editor)
      })
    )
    if (this.refreshOnDidStopChanging) {
      this.syncSubcriptions.add(
        editor.onDidStopChanging(() => {
          if (!this.isActive()) {
            this.refresh({force: true, event: {filePath: editor.getPath()}})
          }
        })
      )
    }
    if (this.refreshOnDidSave) {
      this.syncSubcriptions.add(
        editor.onDidSave(event => {
          if (!this.isActive()) {
            setTimeout(() => this.refresh({force: true, event: {filePath: event.path}}), 0)
          }
        })
      )
    }
  }

  // vim-mode-plus integration
  // -------------------------
  vmpActivateNormalMode () { atom.commands.dispatch(this.editorElement, 'vim-mode-plus:activate-normal-mode') } // prettier-ignore
  vmpActivateInsertMode () { atom.commands.dispatch(this.editorElement, 'vim-mode-plus:activate-insert-mode') } // prettier-ignore
  vmpIsInsertMode () { return this.vmpIsEnabled() && this.editorElement.classList.contains('insert-mode') } // prettier-ignore
  vmpIsNormalMode () { return this.vmpIsEnabled() && this.editorElement.classList.contains('normal-mode') } // prettier-ignore
  vmpIsEnabled () { return this.editorElement.classList.contains('vim-mode-plus') } // prettier-ignore

  // Direct-edit related
  // -------------------------
  updateRealFile () {
    return updateRealFile(this)
  }
}
