const {Point, Range, CompositeDisposable, Emitter} = require('atom')
const {isActiveEditor, parsePromptLine} = require('./utils')

const settings = require('./settings')
const ItemIndicator = require('./item-indicator')

const PROMPT_RANGE = Object.freeze(new Range([0, 0], [0, Infinity]))
const PROMPT_ROW = 0
const ITEM_START_POINT = Object.freeze(new Point(1, 0))

function rangeIntersectsWithPrompt (range) {
  return range.intersectsWith(PROMPT_RANGE)
}

function isSelectionAtPrompt (selection) {
  return rangeIntersectsWithPrompt(selection.getBufferRange())
}

// Wrap normal text-editor and consolidate narrow-able item editor concerns.
class ItemEditor {
  onDidDestroyPromptSelection (fn) { return this.emitter.on('did-destroy-prompt-selection', fn) } // prettier-ignore
  emitDidDestroyPromptSelection () { this.emitter.emit('did-destroy-prompt-selection') } // prettier-ignore
  onDidChangeQuery (fn) { return this.emitter.on('did-change-query', fn) } // prettier-ignore
  emitDidChangeQuery () { this.emitter.emit('did-change-query') } // prettier-ignore

  onDidChangeRow (fn) { return this.emitter.on('did-change-row', fn) } // prettier-ignore
  emitDidChangeRow (event) { this.emitter.emit('did-change-row', event) } // prettier-ignore

  constructor (ui, titleNumber) {
    this.ui = ui
    this.items = this.ui.items
    this.provider = ui.provider

    this.modified = null
    this.readOnly = false
    this.goalColumn = null

    this.ignoreCursorMove = false
    this.ignoreChange = false

    this.disposables = new CompositeDisposable()
    this.emitter = new Emitter()

    ui.onDidDestroy(() => this.destroy())

    this.editor = this.buildEditor(titleNumber)
    this.itemIndicator = new ItemIndicator(this.editor, this.items)
    this.setModifiedState(false)
    this.onDidChangeRow(this.didChangeRow.bind(this))
  }

  initialize () {
    this.editor.setGrammar(atom.grammars.grammarForScopeName('source.narrow'))
  }

  destroy () {
    this.itemIndicator.destroy()
  }

  buildEditor (titleNumber) {
    const editor = atom.workspace.buildTextEditor({
      lineNumberGutterVisible: false,
      autoHeight: false
    })
    const title = this.provider.dashName + '-' + titleNumber
    editor.getTitle = () => title
    editor.element.classList.add('narrow', 'narrow-editor', this.provider.dashName)

    return editor
  }

  didChangeRow ({item, oldRow, newRow}) {
    this.editor.element.classList.toggle('prompt', newRow === PROMPT_ROW)
    if (oldRow === PROMPT_ROW) {
      if (settings.get('autoShiftReadOnlyOnMoveToItemArea')) {
        this.setReadOnly(true)
      }
    }
    if (newRow !== PROMPT_ROW) {
      this.items.selectItem(item)
      if (this.ui.autoPreview) {
        this.ui.previewWithDelay()
      }
    }
  }

  setModifiedState (state) {
    if (state === this.modified) return

    // HACK: overwrite TextBuffer:isModified to return static state.
    // This state is used by tabs package to show modified icon on tab.
    this.modified = state
    this.editor.buffer.isModified = () => state
    this.editor.buffer.emitModifiedStatusChanged(state)
  }

  setReadOnly (readOnly) {
    this.readOnly = readOnly
    const {component, classList} = this.editor.element
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

  updateItemIndicator (states) {
    this.itemIndicator.updateItemIndicator(states)
  }

  isModified () {
    return this.modified
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

  getQuery () {
    return this.editor.getTextInBufferRange(PROMPT_RANGE)
  }

  setQuery (text = '') {
    if (this.editor.getLastBufferRow() === 0) {
      this.editor.setTextInBufferRange([[0, 0], ITEM_START_POINT], text + '\n')
    } else {
      this.editor.setTextInBufferRange(PROMPT_RANGE, text)
    }
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
        this.ui.resetQuery() // recover control bar?
      }

      const eof = this.editor.getEofBufferPosition()
      let text = (firstRender ? '' : '\n') + texts.join('\n')
      const range = [renderStartPosition, eof]
      renderStartPosition = this.editor.setTextInBufferRange(range, text, {undo: 'skip'}).end
      this.setModifiedState(false)
    })

    const firstVisibleScreenRow = this.editor.getFirstVisibleScreenRow()
    if (Number.isInteger(firstVisibleScreenRow)) {
      const firstVisibleRow = this.editor.bufferRowForScreenRow(firstVisibleScreenRow)
      const start = firstVisibleRow - firstItemRow
      const visibleCount = start + this.editor.getRowsPerPage()
      if (visibleCount > 0) {
        const visibleItems = items.slice(Math.max(start, 0), visibleCount)
        this.ui.highlighter.highlightItemsOnNarrowEditor(visibleItems, filterSpec)
      }
    }
    return {renderStartPosition}
  }

  preserveGoalColumn () {
    // HACK: In narrow-editor, header row is skipped onDidChangeCursorPosition event
    // But at this point, cursor.goalColumn is explicitly cleared by atom-core
    // I want use original goalColumn info within onDidChangeCursorPosition event
    // to keep original column when header item was auto-skipped.
    const cursor = this.editor.getLastCursor()
    this.goalColumn = cursor.goalColumn != null ? cursor.goalColumn : cursor.getBufferColumn()
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
      const item = this.items.findPromptOrNormalItem(newRow, {direction, includeStartRow: true})
      const rowToSelect = item._row

      // When newRow was header row
      if (newRow !== rowToSelect) {
        this.withIgnoreCursorMove(() => this.editor.setCursorBufferPosition([rowToSelect, goalColumn]))
      }
      this.emitDidChangeRow({item, oldRow, newRow})
    })
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
        // Destroy selections at prompt to protect query from being mutated on 'find-and-replace:select-all'( cmd-alt-g ).
        const selectionsAtPrompt = this.editor.getSelections().filter(isSelectionAtPrompt)
        if (selectionsAtPrompt.length) {
          selectionsAtPrompt.forEach(selection => selection.destroy())
          this.emitDidDestroyPromptSelection()
        }
      } else {
        this.emitDidChangeQuery()
      }
    })
  }

  getTextForItem (item) {
    return this.editor.lineTextForBufferRow(item._row)
  }

  isActive () {
    return isActiveEditor(this.editor)
  }

  isAtPrompt () { return PROMPT_ROW === this.editor.getCursorBufferPosition().row } // prettier-ignore
  itemRowIsDeleted () { return this.items.items.length - 1 !== this.editor.getLastBufferRow() } // prettier-ignore

  // PromptLine parsing start
  // =================================
  // Return range for {searchTerm, includeFilters, excludeFilters}
  parsePromptLine () {
    return parsePromptLine(this.getQuery(), {
      negateByEndingExclamation: this.ui.negateByEndingExclamation,
      useFirstQueryAsSearchTerm: this.ui.useFirstQueryAsSearchTerm
    })
  }

  getSearchTerm () {
    const range = this.parsePromptLine().searchTerm
    return this.editor.getTextInBufferRange(range)
  }
  // PromptLine parsing end

  // Extended edit
  // ---------------------------
  deleteToEndOfSearchTerm () {
    if (!this.isAtPrompt()) return

    const range = this.parsePromptLine().searchTerm
    if (!range) {
      this.editor.deleteToBeginningOfLine()
    } else {
      const selection = this.editor.getLastSelection()
      const cursorPosition = selection.cursor.getBufferPosition()
      const searchTermEnd = range.end
      const deleteStart = cursorPosition.isGreaterThan(searchTermEnd) ? searchTermEnd : [0, 0]

      selection.setBufferRange([deleteStart, cursorPosition])
      selection.delete()
    }
  }

  // Other
  // ---------------------------
  flashCurrentRow () {
    const itemCount = this.items.getNormalItemCount()
    if (itemCount <= 5) return

    const flashSpec =
      itemCount < 10
        ? {duration: 1000, class: 'narrow-cursor-line-flash-medium'}
        : {duration: 2000, class: 'narrow-cursor-line-flash-long'}

    if (this.currentRowFlashMarker) this.currentRowFlashMarker.destroy()
    const point = this.editor.getCursorBufferPosition()
    this.currentRowFlashMarker = this.editor.markBufferPosition(point)
    this.editor.decorateMarker(this.currentRowFlashMarker, {
      type: 'line',
      class: flashSpec.class
    })

    const destroyMarker = () => {
      if (this.currentRowFlashMarker) this.currentRowFlashMarker.destroy()
      this.currentRowFlashMarker = null
    }
    setTimeout(destroyMarker, flashSpec.duration)
  }

  // Extended move or predict
  moveToPrompt () {
    this.editor.setCursorBufferPosition(PROMPT_RANGE.end)
    this.setReadOnly(false)
  }

  moveToPromptOrSelectedItem () {
    if (this.isAtSelectedItem()) {
      this.moveToPrompt()
    } else {
      this.moveToBeginningOfSelectedItem()
    }
  }

  moveToBeginningOfSelectedItem () {
    if (this.items.hasSelectedItem()) {
      this.editor.setCursorBufferPosition(this.items.getFirstPositionForSelectedItem())
    }
  }

  isAtSelectedItem () {
    const selectedItem = this.items.getSelectedItem()
    return selectedItem && this.editor.getCursorBufferPosition().row === selectedItem._row
  }

  moveToItem (item, column) {
    if (item) {
      if (column == null) {
        column = this.editor.getCursorBufferPosition().column
      }
      const point = [item._row, column]
      // Manually set cursor to center to avoid scrollTop drastically changes
      // when refresh and auto-sync.
      this.editor.setCursorBufferPosition(point, {autoscroll: false})
      this.editor.scrollToBufferPosition(point, {center: true})
    }
  }

  moveToDifferentFileItem (direction) {
    let item
    // This is when curor is at prompt
    if (this.isAtPrompt()) {
      item = this.items.getSelectedItem()
    } else {
      item = this.items.findDifferentFileItem(direction)
    }
    this.moveToItem(item)
  }

  moveToItemForFilePath (filePath) {
    this.moveToItem(this.items.findNextItemForFilePath(filePath))
  }
  //

  // vim-mode-plus integration
  // -------------------------
  vmpActivateNormalMode () { atom.commands.dispatch(this.editor.element, 'vim-mode-plus:activate-normal-mode') } // prettier-ignore
  vmpActivateInsertMode () { atom.commands.dispatch(this.editor.element, 'vim-mode-plus:activate-insert-mode') } // prettier-ignore
  vmpIsInsertMode () { return this.vmpIsEnabled() && this.editor.element.classList.contains('insert-mode') } // prettier-ignore
  vmpIsNormalMode () { return this.vmpIsEnabled() && this.editor.element.classList.contains('normal-mode') } // prettier-ignore
  vmpIsEnabled () { return this.editor.element.classList.contains('vim-mode-plus') } // prettier-ignore
}

module.exports = ItemEditor
