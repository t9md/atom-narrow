const _ = require('underscore-plus')
const {Point, CompositeDisposable, Disposable, Emitter} = require('atom')
const {
  getNextAdjacentPaneForPane,
  getPreviousAdjacentPaneForPane,
  splitPane,
  isActiveEditor,
  cloneRegExp,
  getCurrentWord,
  redrawPoint,
  getActiveEditor,
  getVisibleEditors,
  suppressEvent
} = require('./utils')

const ItemReducer = require('./item-reducer')
const NarrowEditor = require('./narrow-editor')
const Highlighter = require('./highlighter')
const ControlBar = require('./control-bar')
const Items = require('./items')
const queryHistory = require('./query-history')
const updateRealFile = require('./update-real-file')
const FilterSpec = require('./filter-spec')
const ScopedConfig = require('./scoped-config')
const scopedConfigForSelectFiles = new ScopedConfig('narrow.SelectFiles')
const settings = require('./settings')

let SelectFiles

const ITEM_START_POINT = Object.freeze(new Point(1, 0))

class Ui {
  static initClass () {
    this.uiByEditor = new Map()
    this.queryHistory = queryHistory
    this.lastLocationByProviderName = {}
    this.lastFocusedUi = null
  }

  static reset () {
    this.lastLocationByProviderName = {}
  }

  static serialize () {
    return {
      queryHistory: this.queryHistory.serialize()
    }
  }

  static deserialize (state) {
    this.queryHistory.deserialize(state.queryHistory)
  }

  static unregister (ui) {
    this.uiByEditor.delete(ui.editor)
    this.updateWorkspaceClassList()
  }

  static register (ui) {
    this.uiByEditor.set(ui.editor, ui)
    this.updateWorkspaceClassList()
  }

  static get (editor) { return this.uiByEditor.get(editor) } // prettier-ignore
  static has (editor) { return this.uiByEditor.has(editor) } // prettier-ignore
  static getSize () { return this.uiByEditor.size } // prettier-ignore
  static forEach (fn) { this.uiByEditor.forEach(fn) } // prettier-ignore

  static updateWorkspaceClassList () {
    atom.workspace.getElement().classList.toggle('has-narrow', this.uiByEditor.size)
  }

  static getNextTitleNumber () {
    const numbers = [0]
    this.uiByEditor.forEach(ui => numbers.push(ui.titleNumber))
    return Math.max(...numbers) + 1
  }

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

  onDidStopRefreshing (fn) { return this.emitter.on('did-stop-refreshing', fn) } // prettier-ignore

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
      'core:close': () => this.destroy(),
      'core:move-up': event => this.narrowEditor.moveUpOrDownWrap(event, 'up'),
      'core:move-down': event => this.narrowEditor.moveUpOrDownWrap(event, 'down'),

      // HACK: PreserveGoalColumn when skipping header row.
      // Following command is earlily invoked than original move-up(down)-wrap,
      // because it's directly defined on @editorElement.
      // Actual movement is still done by original command since command event is propagated.
      'vim-mode-plus:move-up-wrap': () => this.narrowEditor.preserveGoalColumn(),
      'vim-mode-plus:move-down-wrap': () => this.narrowEditor.preserveGoalColumn(),

      'narrow-ui:confirm-keep-open': () => this.confirm({keepOpen: true}),
      'narrow-ui:open-here': () => this.confirm({openAtUiPane: true}),

      'narrow-ui:protect': () => this.toggleProtected(),
      'narrow-ui:preview-item': () => this.preview(),
      'narrow-ui:preview-next-item': () => this.previewItemForDirection('next'),
      'narrow-ui:preview-previous-item': () => this.previewItemForDirection('previous'),
      'narrow-ui:toggle-auto-preview': () => this.toggleAutoPreview(),
      'narrow-ui:move-to-prompt-or-selected-item': () => this.narrowEditor.moveToPromptOrSelectedItem(),
      'narrow-ui:move-to-prompt': () => this.moveToPrompt({appendSpaceAfterQuery: true}),
      'narrow-ui:start-insert': () => this.narrowEditor.setReadOnly(false),
      'narrow-ui:stop-insert': () => this.narrowEditor.setReadOnly(true),
      'narrow-ui:update-real-file': () => this.updateRealFile(),
      'narrow-ui:exclude-file': () => this.excludeFile(),
      'narrow-ui:refresh': () => this.refreshManually(),
      'narrow-ui:select-files': () => this.selectFiles(),
      'narrow-ui:clear-excluded-files': () => this.clearExcludedFiles(),
      'narrow-ui:move-to-next-file-item': () => this.narrowEditor.moveToDifferentFileItem('next'),
      'narrow-ui:move-to-previous-file-item': () => this.narrowEditor.moveToDifferentFileItem('previous'),
      'narrow-ui:toggle-search-whole-word': () => this.toggleSearchOptionAndRefresh('searchWholeWord'),
      'narrow-ui:toggle-search-ignore-case': () => this.toggleSearchOptionAndRefresh('searchIgnoreCase'),
      'narrow-ui:toggle-search-use-regex': () => this.toggleSearchOptionAndRefresh('searchUseRegex'),
      'narrow-ui:delete-to-end-of-search-term': () => this.narrowEditor.deleteToEndOfSearchTerm(),
      'narrow-ui:clear-query-history': () => this.clearHistroy(),
      'narrow-ui:relocate': () => this.relocate(),
      'narrow-ui:switch-ui-location': () => this.switchUiLocation()
    })
  }

  setQueryFromCurrentWord () {
    const word = getCurrentWord(getActiveEditor()).trim()
    if (word) {
      this.saveQueryHistory(word)
      this.setQueryAndRefreshWithDelay(word, 0)
    }
  }

  setQueryFromHistroy (direction, retry) {
    const text = queryHistory.get(this.provider.name, direction)
    if (text) {
      if (text === this.getQuery()) {
        if (!retry) this.setQueryFromHistroy(direction, true) // retry
        return
      }
      if (text) {
        this.setQueryAndRefreshWithDelay(text, 100)
      }
    }
  }

  setQueryAndRefreshWithDelay (text, delay) {
    this.narrowEditor.withIgnoreChange(() => this.setQuery(text))
    this.refreshWithDelay({force: true}, delay, () => {
      if (!this.isActive()) this.scrollToColumnZero()
      if (!this.narrowEditor.isAtPrompt()) {
        this.moveToSearchedWordOrBeginningOfSelectedItem()
        this.narrowEditor.flashCurrentRow()
      }
    })
  }

  clearHistroy () { queryHistory.clear(this.provider.name) } // prettier-ignore
  resetHistory () { queryHistory.reset(this.provider.name) } // prettier-ignore
  saveQueryHistory (text) { queryHistory.save(this.provider.name, text) } // prettier-ignore

  getState () {
    return {
      excludedFiles: this.excludedFiles,
      queryForSelectFiles: this.queryForSelectFiles
    }
  }

  scrollToColumnZero () {
    const {row} = this.editor.getCursorBufferPosition()
    this.editor.scrollToBufferPosition([row, 0], {center: true})
  }

  toggleSearchOptionAndRefresh (name) {
    if (this.provider.searchOptions) {
      this.provider.searchOptions.toggle(name)
      this.refresh({force: true})
    }
  }

  toggleProtected () {
    this.protected = !this.protected
    this.narrowEditor.updateItemIndicator({protected: this.protected})
    this.controlBar.updateElements({protected: this.protected})
  }

  toggleAutoPreview () {
    this.autoPreview = !this.autoPreview
    this.controlBar.updateElements({autoPreview: this.autoPreview})
    this.highlighter.clearCurrentAndLineMarker()
    if (this.autoPreview) this.preview()
  }

  constructor (provider, {query = ''} = {}, restoredState) {
    if (!SelectFiles) {
      SelectFiles = require('./provider/select-files')
    }
    this.provider = provider
    this.query = query

    this.onTabBarDoubleClick = this.onTabBarDoubleClick.bind(this)

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

    this.autoPreview = this.provider.getConfig('autoPreview')
    this.autoPreviewOnQueryChange = this.provider.getConfig('autoPreviewOnQueryChange')
    this.negateByEndingExclamation = this.provider.getConfig('negateNarrowQueryByEndingExclamation')
    this.showLineHeader = this.provider.getConfig('showLineHeader')
    this.drawItemAtUpperMiddleOnPreview = this.provider.getConfig('drawItemAtUpperMiddleOnPreview')
    this.locationToOpen = this.provider.getConfig('locationToOpen')

    const [directionToOpen, openPreference] = this.provider.getConfig('directionToOpen').split(':')
    this.directionToOpen = directionToOpen
    this.openPreference = openPreference
    this.refreshDelayOnSearchTermChange = this.provider.getConfig('refreshDelayOnSearchTermChange')

    // Initial state
    this.inPreview = false
    this.suppressPreview = false
    this.ignoreChange = false
    this.destroyed = false
    this.lastQuery = ''
    this.lastSearchTerm = ''
    this.protected = false
    this.excludedFiles = []
    this.delayedRefreshTimeout = null
    this.queryForSelectFiles = SelectFiles.getLastQuery(this.provider.name)

    // This is `narrow:reopen`, to restore STATE properties.
    if (restoredState) Object.assign(this, restoredState)

    this.itemReducer = new ItemReducer({
      showLineHeader: this.showLineHeader,
      showProjectHeader: this.showProjectHeader,
      showFileHeader: this.showFileHeader,
      renderItems: this.renderItems.bind(this)
    })

    this.disposables = new CompositeDisposable()
    this.emitter = new Emitter()
    this.items = new Items({boundToSingleFile: this.boundToSingleFile})

    // Setup narrow-editor
    // -------------------------
    this.titleNumber = Ui.getNextTitleNumber()
    this.narrowEditor = new NarrowEditor({
      items: this.items,
      titleNumber: this.titleNumber,
      dashName: this.provider.dashName,
      negateByEndingExclamation: this.negateByEndingExclamation,
      useFirstQueryAsSearchTerm: this.useFirstQueryAsSearchTerm
    })
    this.narrowEditor.onDidMoveToItem(item => {
      if (this.autoPreview && this.isActive()) {
        this.previewWithDelay()
      }
    })

    this.editor = this.narrowEditor.editor
    this.editor.onDidDestroy(this.destroy.bind(this))
    this.editorElement = this.editor.element
    this.highlighter = new Highlighter(this)
    this.subscribeHighlightEvent()

    this.editorElement.onDidChangeScrollTop(scrollTop => {
      this.narrowEditor.clearItemHighlight()
      this.narrowEditor.highlightItems(this.getVisibleItems(), this.filterSpec)
    })

    this.controlBar = new ControlBar(this)
    Ui.register(this)
  }

  subscribeHighlightEvent () {
    this.onDidRefresh(() => {
      if (this.itemHaveRange) {
        this.highlighter.refreshAll()
      }
    })
    this.onDidConfirm(() => {
      this.highlighter.clearCurrentAndLineMarker()
    })
    this.onDidPreview(({editor, item}) => {
      this.highlighter.clearCurrentAndLineMarker()
      this.highlighter.drawLineMarker(editor, item)
      if (this.itemHaveRange) {
        this.highlighter.highlightEditor(editor)
        this.highlighter.highlightCurrentItem(editor, item)
      }
    })
  }

  getCenterPaneToOpen () {
    const basePane = this.provider.getPane()
    let pane
    switch (this.openPreference) {
      case 'always-new-pane':
        pane = null
        break
      case 'never-use-previous-adjacent-pane':
        pane = getNextAdjacentPaneForPane(basePane)
        break
      default:
        pane = getNextAdjacentPaneForPane(basePane) || getPreviousAdjacentPaneForPane(basePane)
    }

    return pane || splitPane(basePane, {split: this.directionToOpen})
  }

  updateLastLocation () {
    Ui.lastLocationByProviderName[this.provider.name] = this.narrowEditor.getLocation()
  }

  getLocationToOpen () {
    return Ui.lastLocationByProviderName[this.provider.name] || this.locationToOpen
  }

  async open ({focus = true} = {}) {
    this.opening = true

    let location = this.getLocationToOpen()
    if (location === 'center') {
      const pane = this.getCenterPaneToOpen()
      await atom.workspace.open(this.editor, {pane, activatePane: false})
    } else {
      await atom.workspace.open(this.editor, {location, activatePane: false})
      atom.workspace.paneContainerForItem(this.editor).show()
    }
    if (focus) {
      this.narrowEditor.activatePane()
    }

    this.narrowEditor.initialize()

    this.narrowEditor.withIgnoreChange(() => this.setQuery(this.query))
    if (!this.reopened && this.query) {
      this.saveQueryHistory(this.query)
    }

    this.disposables.add(this.registerCommands())
    this.disposables.add(this.observeItemEditor())
    this.moveToPrompt()

    await this.refresh()
    this.controlBar.show()

    if (this.provider.needRevealOnStart()) {
      this.syncToEditor(this.provider.editor)
      if (this.items.hasSelectedItem()) {
        this.suppressPreview = true
        this.moveToSearchedWordOrBeginningOfSelectedItem()
        this.suppressPreview = false
        this.narrowEditor.flashCurrentRow()
      }
    } else if (this.query && this.autoPreviewOnQueryChange) {
      await this.preview()
    }

    if (this.isActive()) {
      // Ignore first event after open.
      // To avoid previewWithDelay being called multiple time on startup.
      const disposable = atom.workspace.onDidStopChangingActivePaneItem(() => {
        disposable.dispose()
        this.opening = false
      })
    } else {
      this.opening = false
    }
  }

  isOpening () {
    return this.opening
  }

  onDidBecomeActivePaneItem () {
    this.updateLastLocation()
    if (settings.get('relocateUiByTabBarDoubleClick')) {
      this.setRelocateUiByTabBarDoubleClick()
    }
  }

  onTabBarDoubleClick (event) {
    if (!event.target.classList.contains('close-icon')) {
      suppressEvent(event)
      this.relocate()
    }
  }

  setRelocateUiByTabBarDoubleClick () {
    const pane = this.getPane()
    const tabElements = pane.getElement().getElementsByClassName('tab')
    if (tabElements.length) {
      const index = pane.items.indexOf(this.editor)
      tabElements[index].addEventListener('dblclick', this.onTabBarDoubleClick)
    }
  }

  // TODO: Remove this oldd method: Grimed at 2018.3.1 in v0.64.0-dev.
  switchUiLocation () {
    const Grim = require('grim')
    Grim.deprecate('`ui:switch-ui-location` is renamed to `ui:relocate`. Use `ui:relocate` in your `keymap.cson`')
    this.relocate()
  }

  relocate () {
    if (this.narrowEditor.getLocation() === 'center') {
      this.moveNarrowEditorTo('bottom')
    } else {
      this.moveNarrowEditorTo('center')
    }
  }

  moveNarrowEditorTo (location) {
    let destinationPane
    switch (location) {
      case 'center':
        destinationPane = this.getCenterPaneToOpen()
        break
      case 'bottom':
        destinationPane = atom.workspace.getBottomDock().getActivePane()
        break
    }
    this.getPane().moveItemToPane(this.editor, destinationPane)

    this.editor.component.getNextUpdatePromise().then(() => {
      this.editor.component.measureClientContainerHeight()
      this.narrowEditor.centerCursorPosition()
      if (!this.narrowEditor.isAtPrompt()) {
        this.narrowEditor.flashCurrentRow()
      }
    })
    destinationPane.activateItem(this.editor)
    destinationPane.activate()
  }

  observeItemEditor () {
    return new CompositeDisposable(
      this.narrowEditor.onDidDestroyPromptSelection(() => {
        this.controlBar.show()
        this.narrowEditor.withIgnoreChange(() => this.setQuery(this.lastQuery)) // Recover query
      }),
      this.narrowEditor.onDidChangeQuery(() => {
        if (this.lastQuery.trim() === this.getQuery().trim()) {
          return
        }
        this.narrowEditor.refreshPromptHighlight()

        const delay =
          this.useFirstQueryAsSearchTerm && this.narrowEditor.getSearchTerm() !== this.lastSearchTerm
            ? this.refreshDelayOnSearchTermChange
            : this.boundToSingleFile ? 0 : 100
        this.refreshWithDelay({selectFirstItem: true}, delay, () => {
          if (this.autoPreviewOnQueryChange && this.isActive()) {
            this.preview()
          }
        })
      })
    )
  }

  getPane () { return this.narrowEditor.getPane() } // prettier-ignore
  isActive () { return this.narrowEditor.isActive() } // prettier-ignore

  focus ({autoPreview = this.autoPreview} = {}) {
    const pane = this.getPane()
    pane.activate()
    pane.activateItem(this.editor)
    if (autoPreview) this.preview()
  }

  focusPrompt () {
    if (this.isActive() && this.narrowEditor.isAtPrompt()) {
      this.activateProviderPane()
    } else {
      if (!this.isActive()) this.focus()
      this.moveToPrompt({appendSpaceAfterQuery: true})
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

  isAlive () { return !this.destroyed } // prettier-ignore

  destroy () {
    if (this.destroyed) return

    this.destroyed = true
    this.resetHistory()

    // NOTE: Prevent delayed-refresh on destroyed editor.
    this.cancelDelayedRefresh()
    if (this.refreshDisposables) this.refreshDisposables.dispose()

    Ui.unregister(this)
    this.highlighter.destroy()
    if (this.syncSubcriptions) this.syncSubcriptions.dispose()
    this.disposables.dispose()
    this.editor.destroy()

    this.controlBar.destroy()
    if (this.provider) this.provider.destroy()
    this.items.destroy()

    this.provider.restoreVmpPaneMaximizedStateIfNecessary()

    this.emitDidDestroy()
  }

  close () {
    this.provider.restoreEditorStateIfNecessary()
    this.destroy()
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
    return this.narrowEditor.getQuery()
  }

  setQuery (text) {
    this.narrowEditor.setQuery(text)
    this.narrowEditor.refreshPromptHighlight()
  }

  resetQuery () {
    this.setQuery('')
    this.moveToPrompt()
    this.controlBar.show()
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
    if (this.boundToSingleFile || !this.items.hasSelectedItem()) {
      return
    }

    const {filePath} = this.items.getSelectedItem()
    if (filePath && !this.excludedFiles.includes(filePath)) {
      this.excludedFiles.push(filePath)
      this.narrowEditor.moveToDifferentFileItem('next')
      this.refresh()
    }
  }

  selectFiles () {
    if (this.boundToSingleFile) return

    return new SelectFiles(this).start({
      query: this.queryForSelectFiles,
      pane: this.getPane()
    })
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

  createStateToReduce () {
    return {
      searchTerm: this.useFirstQueryAsSearchTerm ? this.narrowEditor.getSearchTerm() : undefined,
      showColumn: this.showColumnOnLineHeader,
      maxRow: this.boundToSingleFile ? this.provider.editor.getLastBufferRow() : undefined,
      boundToSingleFile: this.boundToSingleFile,
      projectHeadersInserted: new Set(),
      fileHeadersInserted: new Set(),
      allItems: [],
      filterSpec: this.getFilterSpec(this.getFilterQuery(), this.provider.scopedConfig),
      filterSpecForSelectFiles: this.getFilterSpec(this.queryForSelectFiles, scopedConfigForSelectFiles),
      fileExcluded: false,
      excludedFiles: this.excludedFiles,
      renderStartPosition: ITEM_START_POINT
    }
  }

  getFilterSpec (filterQuery, scopedConfig) {
    if (filterQuery) {
      return new FilterSpec(filterQuery, {
        negateByEndingExclamation: scopedConfig.get('negateNarrowQueryByEndingExclamation'),
        sensitivity: scopedConfig.get('caseSensitivityForNarrowQuery')
      })
    }
  }

  startUpdateControlBar () {
    const setRefresh = () => this.controlBar.updateElements({refresh: true})
    const updateItemCount = () => this.controlBar.updateElements({itemCount: this.items.getNormalItemCount()})

    const timeoutID = setTimeout(setRefresh, this.query ? 300 : 0)
    const intervalID = setInterval(updateItemCount, 500)

    this.editor.element.classList.add('hide-cursor')
    return new Disposable(() => {
      this.editor.element.classList.remove('hide-cursor')
      clearTimeout(timeoutID)
      clearInterval(intervalID)
    })
  }

  // Used by SelectFiles
  getFilePathsForAllItems () {
    return this.filePathsForAllItems
  }

  updateFilePathsForAllItemsFromState (state) {
    this.filePathsForAllItems = _.chain(state.allItems)
      .pluck('filePath')
      .uniq()
      .value()
  }

  cancelRefresh () {
    if (this.refreshDisposables) {
      this.refreshDisposables.dispose()
      this.refreshDisposables = null
    }
  }

  renderItems ({renderStartPosition, items, filterSpec}) {
    const firstRender = renderStartPosition.isEqual(ITEM_START_POINT)
    // avoid rendering empty line when no items(= all items this chunks are filtered).
    if (!items.length && !firstRender) return

    this.items.addItems(items)

    const firstItemRow = renderStartPosition.row

    const texts = items.map(item => this.provider.viewForItem(item))
    const editor = this.editor

    this.narrowEditor.withIgnoreChange(() => {
      if (editor.getLastBufferRow() === 0) {
        this.resetQuery() // recover control bar?
      }

      const eof = editor.getEofBufferPosition()
      const text = (firstRender ? '' : '\n') + texts.join('\n')
      const range = [renderStartPosition, eof]
      renderStartPosition = editor.setTextInBufferRange(range, text, {undo: 'skip'}).end
      this.narrowEditor.setModifiedState(false)
    })

    const firstVisibleScreenRow = editor.getFirstVisibleScreenRow()
    if (Number.isInteger(firstVisibleScreenRow)) {
      const firstVisibleRow = editor.bufferRowForScreenRow(firstVisibleScreenRow)
      const start = firstVisibleRow - firstItemRow
      const visibleCount = start + editor.getRowsPerPage()
      if (visibleCount > 0) {
        const visibleItems = items.slice(Math.max(start, 0), visibleCount)
        this.narrowEditor.highlightItems(visibleItems, filterSpec)
      }
    }
    return {renderStartPosition}
  }

  async refresh ({force, selectFirstItem, event = {}} = {}) {
    this.cancelRefresh()
    this.narrowEditor.clearItemHighlight()

    this.filePathsForAllItems = []
    this.highlighter.clearCurrentAndLineMarker()
    this.emitWillRefresh()

    this.lastQuery = this.getQuery()

    const state = this.createStateToReduce()
    this.filterSpec = state.filterSpec // preserve to use for highlight narrow-editor
    if (this.supportFilePathOnlyItemsUpdate && event.filePath && this.items.cachedItems) {
      Object.assign(state, {
        existingItems: this.items.cachedItems.filter(item => !item.skip),
        spliceFilePath: event.filePath
      })
    }

    if (state.searchTerm != null && this.lastSearchTerm !== state.searchTerm) {
      this.lastSearchTerm = state.searchTerm
      force = true
    }
    if (force) {
      this.items.clearCachedItems()
    }

    this.refreshDisposables = new CompositeDisposable(
      this.startUpdateControlBar(),
      this.onDidUpdateItems(items => {
        state.items = items
        this.itemReducer.reduce(state)
      })
    )

    // Main
    // =======================
    // Preserve oldSelectedItem before calling this.items.reset()
    const oldSelectedItem = this.items.getSelectedItem()
    const oldColumn = this.editor.getCursorBufferPosition().column
    const wasAtPrompt = this.narrowEditor.isAtPrompt()

    this.items.reset()

    let success = false
    if (this.items.cachedItems) {
      this.emitDidUpdateItems(this.items.cachedItems)
      success = true
    } else {
      if (state.searchTerm != null) {
        this.updateSearchOptions(state.searchTerm)
      }
      const items = await this.provider.getItems(event)
      if (items) {
        this.emitDidUpdateItems(items)
        success = true
      }
    }

    this.cancelRefresh()

    if (success) {
      if (!this.boundToSingleFile) this.updateFilePathsForAllItemsFromState(state)
      if (this.supportCacheItems) this.items.setCachedItems(state.allItems)

      if (selectFirstItem || !oldSelectedItem) {
        this.items.selectFirstNormalItem()
        this.moveToPrompt()
      } else {
        this.items.selectEqualLocationItem(oldSelectedItem)
        if (!this.items.hasSelectedItem()) {
          this.items.selectFirstNormalItem()
        }
        if (!wasAtPrompt) {
          this.narrowEditor.moveToItem(this.items.getSelectedItem(), oldColumn)
        }
      }

      this.controlBar.updateElements({
        selectFiles: state.fileExcluded,
        itemCount: this.items.getNormalItemCount(),
        refresh: false
      })

      this.emitDidRefresh()
      this.emitDidStopRefreshing()
    }
  }

  refreshManually () {
    this.emitWillRefreshManually()
    this.refresh({force: true})
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

  previewWithDelay () {
    if (this.delayedPreviewTimeout) {
      clearTimeout(this.delayedPreviewTimeout)
      this.delayedPreviewTimeout = null
    }

    const timeout = this.workspaceHasSelectedItem() ? 0 : 20
    this.delayedPreviewTimeout = setTimeout(() => {
      this.delayedPreviewTimeout = null
      this.preview()
    }, timeout)
  }

  workspaceHasSelectedItem () {
    if (this.boundToSingleFile) {
      return true
    } else {
      const pane = this.provider.getPane()
      const selectedItem = this.items.getSelectedItem()
      return pane && selectedItem && pane.itemForURI(selectedItem.filePath)
    }
  }

  syncToEditor (editor) {
    if (this.inPreview) return

    const point = editor.getCursorBufferPosition()
    const item = this.items.findClosestItemForBufferPosition(point, {filePath: editor.getPath()})
    if (item) {
      this.narrowEditor.moveToItem(item)
      this.scrollToColumnZero()
    }
  }

  async preview () {
    if (this.suppressPreview) return
    if (this.inPreview) {
      throw new Error('preview requested while in preview')
    }

    if (!this.isActive()) return
    const item = this.items.getSelectedItem()
    if (!item) return

    this.inPreview = true
    const editor = await this.provider.openFileForItem(item, {activatePane: false})
    if (!getVisibleEditors().includes(editor)) {
      throw new Error(`trying to preview on invisiblie editor, ${editor.getPath}`)
    }
    if (this.drawItemAtUpperMiddleOnPreview) {
      redrawPoint(editor, item.point, 'upper-middle')
    } else {
      editor.scrollToBufferPosition(item.point, {center: true})
    }
    this.inPreview = false

    this.emitDidPreview({editor, item})
    return true
  }

  async confirm ({keepOpen, flash, openAtUiPane} = {}) {
    if (this.useFirstQueryAsSearchTerm) {
      if (this.lastSearchTerm) {
        this.saveQueryHistory(this.lastSearchTerm)
      }
    }
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
        if (flash && this.itemHaveRange) {
          this.highlighter.flashItem(editor, item)
        }
        this.emitDidConfirm({editor, item})
      }
    }
  }

  moveToSearchedWordOrBeginningOfSelectedItem () {
    if (!this.items.hasSelectedItem()) return

    const {searchOptions} = this.provider
    if (searchOptions && searchOptions.searchRegex) {
      this.moveToSearchedWordAtSelectedItem(this.provider.searchOptions.searchRegex)
    } else {
      this.narrowEditor.moveToBeginningOfSelectedItem()
    }
    this.narrowEditor.centerCursorPosition()
  }

  moveToSearchedWordAtSelectedItem (searchRegex) {
    const item = this.items.getSelectedItem()
    if (!item) return

    const inSyncWithProviderEditor =
      this.boundToSingleFile || this.items.getSelectedItem().filePath === this.provider.editor.getPath()

    const columnDelta = inSyncWithProviderEditor
      ? this.provider.editor.getCursorBufferPosition().column
      : cloneRegExp(searchRegex).exec(item.text).index
    const point = this.items.getFirstPositionForItem(item).translate([0, columnDelta])
    this.editor.setCursorBufferPosition(point)
  }

  moveToPrompt (options) {
    this.narrowEditor.moveToPrompt(options)
  }

  startSyncToEditor (editor) {
    if (this.syncSubcriptions) this.syncSubcriptions.dispose()
    const oldFilePath = this.provider.editor.getPath()
    const newFilePath = editor.getPath()

    this.provider.bindEditor(editor)
    this.syncToEditor(editor)

    if (this.boundToSingleFile && (!oldFilePath || oldFilePath !== newFilePath)) {
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
        if (isActiveEditor(editor)) {
          this.syncToEditor(editor)
        }
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

  getVisibleItems () {
    const [startRow, endRow] = this.editorElement.getVisibleRowRange()
    return this.items.getItemsInRowRange(startRow, endRow)
  }

  // Direct-edit related
  // -------------------------
  updateRealFile () {
    updateRealFile(this)
  }
}
Ui.initClass()

module.exports = Ui
