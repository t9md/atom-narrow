const {Emitter, Point} = require('atom')
const {isNormalItem, getValidIndexForList} = require('./utils')

module.exports = class Items {
  onDidChangeSelectedItem (fn) {
    return this.emitter.on('did-change-selected-item', fn)
  }
  emitDidChangeSelectedItem (event) {
    return this.emitter.emit('did-change-selected-item', event)
  }

  constructor (ui) {
    this.selectedItem = null
    this.previouslySelectedItem = null
    this.cachedItems = null

    this.ui = ui
    this.promptItem = Object.freeze({_prompt: true, skip: true, _uiRow: 0})
    this.emitter = new Emitter()
    this.items = []
  }

  destroy () {
    this.items = null
  }

  setCachedItems (cachedItems) {
    this.cachedItems = cachedItems
  }

  clearCachedItems () {
    this.cachedItems = null
  }

  addItems (items) {
    let index = this.items.length
    for (const item of items) {
      item._uiRow = index
      this.items[index] = item
      index++
    }
    this.selectedItem = null
    this.previouslySelectedItem = null
  }

  reset () {
    this.items = [this.promptItem]
    this.selectedItem = null
    this.previouslySelectedItem = null
  }

  selectItem (item) {
    if (isNormalItem(item)) {
      this.previouslySelectedItem = this.selectedItem
      this.selectedItem = item
      this.emitDidChangeSelectedItem({
        oldItem: this.previouslySelectedItem,
        newItem: this.selectedItem
      })
    }
  }

  selectItemForRow (row) {
    this.selectItem(this.getItemForRow(row))
  }

  selectFirstNormalItem () {
    this.selectItem(this.findNormalItem(0, {direction: 'next'}))
  }

  getFirstPositionForSelectedItem () {
    return this.getFirstPositionForItem(this.selectedItem)
  }

  getFirstPositionForItem (item) {
    return new Point(this.getRowForItem(item), this.getFirstColumnForItem(item))
  }

  getPointForSelectedItemAtColumn (column) {
    return this.getFirstPositionForSelectedItem().translate([0, column])
  }

  getFirstColumnForItem (item) {
    return item._lineHeader ? item._lineHeader.length : 0
  }

  getSelectedItem () {
    return this.selectedItem
  }

  hasSelectedItem () {
    return this.selectedItem != null
  }

  getPreviouslySelectedItem () {
    return this.previouslySelectedItem
  }

  getRowForSelectedItem () {
    return this.getRowForItem(this.getSelectedItem())
  }

  isNormalItemRow (row) {
    return isNormalItem(this.items[row])
  }

  getRowForItem (item) {
    return item ? item._uiRow : -1
  }

  getItemForRow (row) {
    return this.items[row]
  }

  getNormalItems (filePath) {
    const normalItems = this.items.filter(isNormalItem)
    return filePath ? normalItems.filter(item => item.filePath === filePath) : normalItems
  }

  getVisibleItems () {
    const {editor, editorElement} = this.ui
    const [startRow, endRow] = editorElement.getVisibleRowRange()
    return this.items.slice(editor.bufferRowForScreenRow(startRow), editor.bufferRowForScreenRow(endRow) + 1)
  }

  getCount () {
    return this.getNormalItems().length
  }

  // Never fail since prompt item is always exists
  findPromptOrNormalItem (row, options) {
    return this.findItem(row, options, item => isNormalItem(item) || item === this.promptItem)
  }

  findNormalItem (row, options, fn = () => true) {
    return this.findItem(row, options, item => isNormalItem(item) && fn(item))
  }

  findItem (startRow, {direction, includeStartRow = false}, fn) {
    if (includeStartRow) {
      const item = this.getItemForRow(startRow)
      if (fn(item)) {
        return item
      }
    }

    let row = startRow
    const stride = direction === 'next' ? +1 : -1
    while (true) {
      row = getValidIndexForList(this.items, row + stride)
      const item = this.getItemForRow(row)
      if (fn(item)) {
        return item
      }
      if (row === startRow) return null
    }
  }

  findDifferentFileItem (direction) {
    const selectedItem = this.getSelectedItem()
    if (selectedItem) {
      return this.findNormalItem(selectedItem._uiRow, {direction}, item => item.filePath !== selectedItem.filePath)
    }
  }

  findNextItemForFilePath (filePath) {
    const selectedItem = this.getSelectedItem()
    if (selectedItem) {
      return this.findItem(
        selectedItem._uiRow,
        {direction: 'next', includeStartRow: true},
        item => isNormalItem(item) && item.filePath === filePath
      )
    }
  }

  findClosestItemForBufferPosition (point, {filePath} = {}) {
    const items = this.getNormalItems(filePath)
    if (!items.length) return null

    for (let i = items.length - 1; i >= 0; i--) {
      const item = items[i]
      if (item.point.isLessThanOrEqual(point)) {
        return item
      }
    }
    return items[0]
  }

  findEqualLocationItem (item) {
    return this.getNormalItems().find(({point, filePath}) => {
      return point.isEqual(item.point) && filePath === item.filePath
    })
  }

  selectEqualLocationItem (item) {
    const found = this.findEqualLocationItem(item)
    if (found) {
      this.selectItem(item)
    }
  }

  selectItemInDirection (point, direction) {
    const item = this.getSelectedItem()
    if (!item) return

    if (direction === 'next' && item.point.isGreaterThan(point)) return

    const basePoint = item.range ? item.range.end : item.point
    if (direction === 'previous' && basePoint.isLessThan(point)) return

    this.selectItem(this.findNormalItem(this.getRowForItem(item), {direction}))
  }
}
