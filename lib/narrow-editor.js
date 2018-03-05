const createOutlet = require('atom-outlet').create
const {Point, Range, Emitter} = require('atom')
const {
  isActiveEditor,
  parsePromptLine,
  setBufferRow,
  getPrefixedTextLengthInfo,
  paneForItem,
  redrawPoint,
  getLocationForItem
} = require('./utils')

const settings = require('./settings')
const ItemIndicator = require('./item-indicator')
const GroupedHighlight = require('./grouped-highlight')

const PROMPT_RANGE = Object.freeze(new Range([0, 0], [0, Infinity]))
const PROMPT_ROW = 0
const ITEM_START_POINT = Object.freeze(new Point(1, 0))

function intersectPrompt (range) {
  return range.intersectsWith(PROMPT_RANGE)
}

function isNonPromptChange ({newRange, oldRange}) {
  return (!newRange.isEmpty() && !intersectPrompt(newRange)) || (!oldRange.isEmpty() && !intersectPrompt(oldRange))
}

// Wrap normal text-editor and consolidate narrow-able item editor concerns.
class NarrowEditor {
  onDidDestroyPromptSelection (fn) { return this.emitter.on('did-destroy-prompt-selection', fn) } // prettier-ignore
  emitDidDestroyPromptSelection () { this.emitter.emit('did-destroy-prompt-selection') } // prettier-ignore

  onDidChangeQuery (fn) { return this.emitter.on('did-change-query', fn) } // prettier-ignore
  emitDidChangeQuery () { this.emitter.emit('did-change-query') } // prettier-ignore

  onDidChangeRow (fn) { return this.emitter.on('did-change-row', fn) } // prettier-ignore
  emitDidChangeRow (event) { this.emitter.emit('did-change-row', event) } // prettier-ignore

  onDidMoveToItem (fn) { return this.emitter.on('did-move-to-item', fn) } // prettier-ignore
  emitDidMoveToItem (item) { this.emitter.emit('did-move-to-item', item) } // prettier-ignore

  constructor (options) {
    this.items = options.items
    this.negateByEndingExclamation = options.negateByEndingExclamation
    this.useFirstQueryAsSearchTerm = options.useFirstQueryAsSearchTerm
    this.autoShiftReadOnlyOnMoveToItemArea = settings.get('autoShiftReadOnlyOnMoveToItemArea')

    this.modified = null
    this.readOnly = false
    this.goalColumn = null
    this.ignoreCursorMove = false
    this.ignoreChange = false
    this.emitter = new Emitter()

    this.clearCurrentRowFlash = this.clearCurrentRowFlash.bind(this)

    this.outlet = createOutlet({
      title: options.title,
      editorOptions: {lineNumberGutterVisible: false},
      classList: options.classList,
      defaultLocation: options.defaultLocation,
      split: options.split,
      useAdjacentPane: options.useAdjacentPane,
      extendsTextEditor: true
    })
    this.outlet.onDidDestroy(() => this.destroy())

    this.itemIndicator = new ItemIndicator(this.outlet, this.items)
    this.setModifiedState(false)
    this.onDidChangeRow(this.didChangeRow.bind(this))

    // Manage prompt and item highlight separately. Why?
    //  - Item highlight is done at rendering phase of refresh, it's delayed.
    //  - But prompt highlight must be updated as user type, without delay.
    this.promptHighlight = new GroupedHighlight(this.outlet, {
      searchTerm: 'narrow-syntax--search-term',
      includeFilter: 'narrow-syntax--include-filter',
      excludeFilter: 'narrow-syntax--exclude-filter'
    })
    this.itemHighlight = new GroupedHighlight(this.outlet, {
      searchTerm: 'narrow-syntax--search-term',
      includeFilter: 'narrow-syntax--include-filter',
      fileHeader: 'narrow-syntax--header-file',
      projectHeader: 'narrow-syntax--header-project',
      truncationIndicator: 'narrow-syntax--truncation-indicator'
    })
  }

  initialize () {
    this.observeChange()
    this.observeCursorMove()
    atom.grammars.assignLanguageMode(this.outlet.getBuffer(), 'source.narrow')
  }

  destroy () {
    this.clearCurrentRowFlash()
    this.promptHighlight.destroy()
    this.itemHighlight.destroy()
    this.itemIndicator.destroy()
  }

  didChangeRow ({item, oldRow, newRow}) {
    this.outlet.element.classList.toggle('prompt', newRow === PROMPT_ROW)
    if (oldRow === PROMPT_ROW && this.autoShiftReadOnlyOnMoveToItemArea) {
      this.setReadOnly(true)
    }
    if (newRow !== PROMPT_ROW) {
      this.items.selectItem(item)
      this.emitDidMoveToItem(item)
    }
  }

  getPane () {
    return paneForItem(this.outlet)
  }

  getLocation () {
    return getLocationForItem(this.outlet)
  }

  setModifiedState (state) {
    if (state === this.modified) return

    // HACK: overwrite TextBuffer:isModified to return static state.
    // This state is used by tabs package to show modified icon on tab.
    this.modified = state
    this.outlet.buffer.isModified = () => state
    this.outlet.buffer.emitModifiedStatusChanged(state)
  }

  setReadOnly (readOnly) {
    this.readOnly = readOnly
    const {component, classList} = this.outlet.element
    if (readOnly) {
      if (component) component.setInputEnabled(false)
      classList.add('read-only')
      if (this.vmpIsInsertMode()) this.vmpActivateNormalMode()
    } else {
      if (component) component.setInputEnabled(true)
      classList.remove('read-only')
      if (this.vmpIsNormalMode()) {
        this.vmpActivateInsertMode()
      }
    }
  }

  updateItemIndicator (states) {
    this.itemIndicator.update(states)
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
    return this.outlet.getTextInBufferRange(PROMPT_RANGE)
  }

  setQuery (text = '') {
    if (this.outlet.getLastBufferRow() === 0) {
      this.outlet.setTextInBufferRange([[0, 0], ITEM_START_POINT], text + '\n')
    } else {
      this.outlet.setTextInBufferRange(PROMPT_RANGE, text)
    }
  }

  observeCursorMove () {
    this.outlet.onDidChangeCursorPosition(event => {
      if (this.ignoreCursorMove) return

      const {oldBufferPosition, newBufferPosition, textChanged, cursor} = event

      // Clear preserved this.goalColumn as early as possible to not affect other movement commands.
      const goalColumn = this.goalColumn != null ? this.goalColumn : newBufferPosition.column
      this.goalColumn = null

      if (textChanged || !cursor.selection.isEmpty() || oldBufferPosition.row === newBufferPosition.row) {
        return
      }

      const newRow = newBufferPosition.row
      const oldRow = oldBufferPosition.row
      const item = this.items.findPromptOrNormalItem(newRow, {
        direction: newRow > oldRow ? 'next' : 'previous',
        includeStartRow: true
      })

      if (newRow !== item._row) {
        // When newRow was header row, skip to item's row
        this.withIgnoreCursorMove(() => this.outlet.setCursorBufferPosition([item._row, goalColumn]))
      }
      this.emitDidChangeRow({item, oldRow, newRow: item._row})
    })
  }

  destroyPromptSelections () {
    let destroyed = false
    for (const selection of this.outlet.getSelections()) {
      if (intersectPrompt(selection.getBufferRange())) {
        selection.destroy()
        destroyed = true
      }
    }
    if (destroyed) {
      this.emitDidDestroyPromptSelection()
    }
  }

  observeChange () {
    this.outlet.buffer.onDidChangeText(event => {
      if (this.ignoreChange) return

      // Destroy selections at prompt when has multi cursors
      // Which prevent query updated on direct-edit after `find-and-replace:select-all`( cmd-alt-g ).
      if (this.outlet.hasMultipleCursors()) {
        this.destroyPromptSelections()
      }

      if (event.changes.some(isNonPromptChange)) {
        this.setModifiedState(true)
      } else {
        this.emitDidChangeQuery()
      }
    })
  }

  getTextForItem (item) {
    return this.outlet.lineTextForBufferRow(item._row)
  }

  isActive () { return isActiveEditor(this.outlet) } // prettier-ignore
  isAtPrompt () { return PROMPT_ROW === this.outlet.getCursorBufferPosition().row } // prettier-ignore
  itemRowIsDeleted () { return this.items.items.length - 1 !== this.outlet.getLastBufferRow() } // prettier-ignore

  // PromptLine parsing start
  // =================================
  // Return range for {searchTerm, includeFilters, excludeFilters}
  parsePromptLine () {
    return parsePromptLine(this.getQuery(), {
      negateByEndingExclamation: this.negateByEndingExclamation,
      useFirstQueryAsSearchTerm: this.useFirstQueryAsSearchTerm
    })
  }

  getSearchTerm () {
    const range = this.parsePromptLine().searchTerm
    return this.outlet.getTextInBufferRange(range)
  }

  // Extended edit
  // ---------------------------
  preserveGoalColumn () {
    // HACK: In narrow-editor, header row is skipped onDidChangeCursorPosition event
    // But at this point, cursor.goalColumn is explicitly cleared by atom-core
    // I want use original goalColumn info within onDidChangeCursorPosition event
    // to keep original column when header item was auto-skipped.
    const cursor = this.outlet.getLastCursor()
    this.goalColumn = cursor.goalColumn != null ? cursor.goalColumn : cursor.getBufferColumn()
  }

  // Line-wrapped version of 'core:move-up' override default behavior
  moveUpOrDownWrap (event, direction) {
    this.preserveGoalColumn()

    const cursor = this.outlet.getLastCursor()
    const cursorRow = cursor.getBufferRow()
    const lastRow = this.outlet.getLastBufferRow()

    if (direction === 'up' && cursorRow === 0) {
      setBufferRow(cursor, lastRow)
      event.stopImmediatePropagation()
    } else if (direction === 'down' && cursorRow === lastRow) {
      setBufferRow(cursor, 0)
      event.stopImmediatePropagation()
    }
  }

  deleteToEndOfSearchTerm () {
    if (!this.isAtPrompt()) return

    const range = this.parsePromptLine().searchTerm
    if (!range) {
      this.outlet.deleteToBeginningOfLine()
    } else {
      const selection = this.outlet.getLastSelection()
      const cursorPosition = selection.cursor.getBufferPosition()
      const searchTermEnd = range.end
      const deleteStart = cursorPosition.isGreaterThan(searchTermEnd) ? searchTermEnd : [0, 0]

      selection.setBufferRange([deleteStart, cursorPosition])
      selection.delete()
    }
  }

  // Extended move or predict
  // -------------------------
  moveToPrompt ({appendSpaceAfterQuery = false} = {}) {
    if (appendSpaceAfterQuery) {
      const promptLine = this.outlet.lineTextForBufferRow(PROMPT_ROW)
      if (promptLine && !promptLine.endsWith(' ')) {
        this.withIgnoreChange(() => {
          this.outlet.setTextInBufferRange([PROMPT_RANGE.end, PROMPT_RANGE.end], ' ')
        })
      }
    }
    this.outlet.setCursorBufferPosition(PROMPT_RANGE.end)
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
      this.outlet.setCursorBufferPosition(this.items.getFirstPositionForSelectedItem())
    }
  }

  isAtSelectedItem () {
    const selectedItem = this.items.getSelectedItem()
    return selectedItem && this.outlet.getCursorBufferPosition().row === selectedItem._row
  }

  moveToItem (item, column) {
    if (item) {
      if (column == null) {
        column = this.outlet.getCursorBufferPosition().column
      }
      const point = [item._row, column]
      // Manually set cursor to center to avoid scrollTop drastically changes
      // when refresh and auto-sync.
      this.outlet.setCursorBufferPosition(point, {autoscroll: false})
      this.outlet.scrollToBufferPosition(point, {center: true})
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

  // Other
  // ---------------------------
  centerCursorPosition () {
    redrawPoint(this.outlet, this.outlet.getCursorBufferPosition(), 'center')
  }

  flashCurrentRow () {
    const itemCount = this.items.getNormalItemCount()
    this.clearCurrentRowFlash()
    if (itemCount >= 2) {
      const flashSpec =
        itemCount < 10 && this.isActive()
          ? {duration: 1000, class: 'narrow-cursor-line-flash-medium'}
          : {duration: 2000, class: 'narrow-cursor-line-flash-long'}

      const point = this.outlet.getCursorBufferPosition()
      this.currentRowFlashMarker = this.outlet.markBufferPosition(point)
      this.outlet.decorateMarker(this.currentRowFlashMarker, {
        type: 'line',
        class: flashSpec.class
      })
      this.currentRowFlashTimeout = setTimeout(this.clearCurrentRowFlash, flashSpec.duration)
    }
  }

  clearCurrentRowFlash () {
    if (this.currentRowFlashTimeout) {
      clearTimeout(this.currentRowFlashTimeout)
      this.currentRowFlashMarker.destroy()
      if (this.outlet.component) {
        this.outlet.component.updateSync()
      }
      this.currentRowFlashTimeout = null
      this.currentRowFlashMarker = null
    }
  }

  // Highlight
  // -------------------------
  refreshPromptHighlight () {
    const {searchTerm, includeFilters, excludeFilters} = this.parsePromptLine()
    const prompt = this.promptHighlight

    prompt.clear()

    if (searchTerm) prompt.markRange('searchTerm', searchTerm)
    includeFilters.forEach(range => prompt.markRange('includeFilter', range))
    excludeFilters.forEach(range => prompt.markRange('excludeFilter', range))
  }

  clearItemHighlight () {
    this.itemHighlight.clear()
  }

  highlightItems (items, filterSpec) {
    const markRange = (name, range) => {
      this.itemHighlight.markRange(name, range, {invalidate: 'inside'})
    }

    const includeFilters = filterSpec
      ? filterSpec.include.map(regex => new RegExp(regex.source, regex.flags + 'g'))
      : undefined

    for (const item of items) {
      const row = item._row

      if (item.header) {
        let layerName
        if (item.headerType === 'file') {
          layerName = 'fileHeader'
        } else if (item.headerType === 'project') {
          layerName = 'projectHeader'
        }
        markRange(layerName, [[row, 0], [row, Infinity]])
        continue
      }

      // These variables are used to calculate offset for highlight
      const {lineHeaderLength, truncationIndicatorLength, totalLength} = getPrefixedTextLengthInfo(item)

      // We can not highlight item without range info
      if (item.range) {
        const {start, end} = item.range
        markRange('searchTerm', [[row, start.column + totalLength], [row, end.column + totalLength]])
      }

      if (includeFilters) {
        const lineText = this.outlet.lineTextForBufferRow(row).slice(totalLength)
        for (const regex of includeFilters) {
          regex.lastIndex = 0
          let match
          while ((match = regex.exec(lineText))) {
            const matchText = match[0]
            if (!matchText) break // Avoid infinite loop in zero length match(in regex /^/)
            const range = [[row, match.index + totalLength], [row, regex.lastIndex + totalLength]]
            markRange('includeFilter', range)
          }
        }
      }

      if (truncationIndicatorLength) {
        const range = [[row, lineHeaderLength], [row, lineHeaderLength + truncationIndicatorLength]]
        markRange('truncationIndicator', range)
      }
    }
  }

  // vim-mode-plus integration
  // -------------------------
  vmpActivateNormalMode () { atom.commands.dispatch(this.outlet.element, 'vim-mode-plus:activate-normal-mode') } // prettier-ignore
  vmpActivateInsertMode () { atom.commands.dispatch(this.outlet.element, 'vim-mode-plus:activate-insert-mode') } // prettier-ignore
  vmpIsInsertMode () { return this.vmpIsEnabled() && this.outlet.element.classList.contains('insert-mode') } // prettier-ignore
  vmpIsNormalMode () { return this.vmpIsEnabled() && this.outlet.element.classList.contains('normal-mode') } // prettier-ignore
  vmpIsEnabled () { return this.outlet.element.classList.contains('vim-mode-plus') } // prettier-ignore
}

module.exports = NarrowEditor
