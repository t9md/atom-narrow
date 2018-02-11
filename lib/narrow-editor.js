const {Point, Range, Emitter, TextEditor} = require('atom')
const {isActiveEditor, parsePromptLine, setBufferRow, getPrefixedTextLengthInfo} = require('./utils')

const settings = require('./settings')
const ItemIndicator = require('./item-indicator')

const PROMPT_RANGE = Object.freeze(new Range([0, 0], [0, Infinity]))
const PROMPT_ROW = 0
const ITEM_START_POINT = Object.freeze(new Point(1, 0))

function intersectPrompt (range) {
  return range.intersectsWith(PROMPT_RANGE)
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

    this.editor = new TextEditor({lineNumberGutterVisible: false, autoHeight: false})
    const editorTitle = options.dashName + '-' + options.titleNumber
    this.editor.getTitle = () => editorTitle
    this.editor.element.classList.add('narrow', 'narrow-editor', options.dashName)
    this.editor.onDidDestroy(() => this.destroy())

    this.itemIndicator = new ItemIndicator(this.editor, this.items)
    this.setModifiedState(false)
    this.onDidChangeRow(this.didChangeRow.bind(this))
  }

  initialize () {
    this.observeChange()
    this.observeCursorMove()
    this.editor.setGrammar(atom.grammars.grammarForScopeName('source.narrow'))
    this.initializeMarkerLayerForHighlight()
  }

  destroy () {
    Object.values(this.markerLayers.prompt).forEach(layer => layer.destroy())
    Object.values(this.markerLayers.item).forEach(layer => layer.destroy())
    Object.values(this.decorationLayers.prompt).forEach(layer => layer.destroy())
    Object.values(this.decorationLayers.item).forEach(layer => layer.destroy())

    this.itemIndicator.destroy()
  }

  didChangeRow ({item, oldRow, newRow}) {
    this.editor.element.classList.toggle('prompt', newRow === PROMPT_ROW)
    if (oldRow === PROMPT_ROW && this.autoShiftReadOnlyOnMoveToItemArea) {
      this.setReadOnly(true)
    }
    if (newRow !== PROMPT_ROW) {
      this.items.selectItem(item)
      this.emitDidMoveToItem(item)
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
    return this.editor.getTextInBufferRange(PROMPT_RANGE)
  }

  setQuery (text = '') {
    if (this.editor.getLastBufferRow() === 0) {
      this.editor.setTextInBufferRange([[0, 0], ITEM_START_POINT], text + '\n')
    } else {
      this.editor.setTextInBufferRange(PROMPT_RANGE, text)
    }
  }

  observeCursorMove () {
    this.editor.onDidChangeCursorPosition(event => {
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
        this.withIgnoreCursorMove(() => this.editor.setCursorBufferPosition([item._row, goalColumn]))
      }
      this.emitDidChangeRow({item, oldRow, newRow: item._row})
    })
  }

  observeChange () {
    this.editor.buffer.onDidChange(event => {
      if (this.ignoreChange) return

      const isQueryModified =
        (!event.newRange.isEmpty() && intersectPrompt(event.newRange)) ||
        (!event.oldRange.isEmpty() && intersectPrompt(event.oldRange))

      if (!isQueryModified) {
        this.setModifiedState(true) // Item area modified, direct-edit so don't refresh editor!
        return
      }

      if (this.editor.hasMultipleCursors()) {
        // Destroy selections at prompt to protect query from being mutated on 'find-and-replace:select-all'( cmd-alt-g ).
        const selectionsAtPrompt = this.editor.getSelections().filter(selection => {
          intersectPrompt(selection.getBufferRange())
        })
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
      negateByEndingExclamation: this.negateByEndingExclamation,
      useFirstQueryAsSearchTerm: this.useFirstQueryAsSearchTerm
    })
  }

  getSearchTerm () {
    const range = this.parsePromptLine().searchTerm
    return this.editor.getTextInBufferRange(range)
  }

  // Extended edit
  // ---------------------------
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

  // Extended move or predict
  // -------------------------
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

  // Highlight
  // -------------------------
  initializeMarkerLayerForHighlight () {
    this.markerLayers = {prompt: {}, item: {}}
    this.decorationLayers = {prompt: {}, item: {}}

    const createMarkerLayer = (kind, name, className) => {
      const markerLayer = this.editor.addMarkerLayer()
      const decorationLayer = this.editor.decorateMarkerLayer(markerLayer, {type: 'text', class: className})
      this.markerLayers[kind][name] = markerLayer
      this.decorationLayers[kind][name] = decorationLayer
    }

    createMarkerLayer('item', 'searchTerm', 'narrow-syntax--search-term')
    createMarkerLayer('item', 'includeFilter', 'narrow-syntax--include-filter')
    createMarkerLayer('item', 'fileHeader', 'narrow-syntax--header-file')
    createMarkerLayer('item', 'projectHeader', 'narrow-syntax--header-project')
    createMarkerLayer('item', 'truncationIndicator', 'narrow-syntax--truncation-indicator')
    createMarkerLayer('prompt', 'searchTerm', 'narrow-syntax--search-term')
    createMarkerLayer('prompt', 'includeFilter', 'narrow-syntax--include-filter')
    createMarkerLayer('prompt', 'excludeFilter', 'narrow-syntax--exclude-filter')
  }

  // Manage marker for prompt highlight separately. Why?
  //  - Normal highlight is done at rendering phase of refresh, it's delayed.
  //  - But prompt highlight must be updated as user type, without delay.
  refreshPromptHighlight () {
    const parsed = this.parsePromptLine()
    const {searchTerm, includeFilter, excludeFilter} = this.markerLayers.prompt
    searchTerm.clear()
    includeFilter.clear()
    excludeFilter.clear()

    if (parsed.searchTerm) searchTerm.markBufferRange(parsed.searchTerm)
    parsed.includeFilters.forEach(range => includeFilter.markBufferRange(range))
    parsed.excludeFilters.forEach(range => excludeFilter.markBufferRange(range))
  }

  clearItemHighlight () {
    Object.values(this.markerLayers.item).forEach(layer => layer.clear())
  }

  highlightItems (items, filterSpec) {
    const markRange = (name, range) => {
      this.markerLayers.item[name].markBufferRange(range, {invalidate: 'inside'})
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
        const range = item.translateRange ? item.translateRange() : item.range
        markRange('searchTerm', [[row, range.start.column + totalLength], [row, range.end.column + totalLength]])
      }

      if (includeFilters) {
        const lineText = this.editor.lineTextForBufferRow(row).slice(totalLength)
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
        this.markRange('truncationIndicator', range)
      }
    }
  }

  // vim-mode-plus integration
  // -------------------------
  vmpActivateNormalMode () { atom.commands.dispatch(this.editor.element, 'vim-mode-plus:activate-normal-mode') } // prettier-ignore
  vmpActivateInsertMode () { atom.commands.dispatch(this.editor.element, 'vim-mode-plus:activate-insert-mode') } // prettier-ignore
  vmpIsInsertMode () { return this.vmpIsEnabled() && this.editor.element.classList.contains('insert-mode') } // prettier-ignore
  vmpIsNormalMode () { return this.vmpIsEnabled() && this.editor.element.classList.contains('normal-mode') } // prettier-ignore
  vmpIsEnabled () { return this.editor.element.classList.contains('vim-mode-plus') } // prettier-ignore
}

module.exports = NarrowEditor
