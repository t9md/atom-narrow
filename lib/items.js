const {Emitter, Point} = require('atom')
const {getValidIndexForList} = require('./utils')

module.exports = class Items {
  onDidChangeSelectedItem (fn) { return this.emitter.on('did-change-selected-item', fn) } // prettier-ignore
  emitDidChangeSelectedItem (event) { this.emitter.emit('did-change-selected-item', event) } // prettier-ignore

  constructor (options) {
    this.selectedItem = null
    this.previouslySelectedItem = null
    this.cachedItems = null
    this.destroyed = false
    this.boundToSingleFile = options.boundToSingleFile

    this.promptItem = Object.freeze({_prompt: true, skip: true, _row: 0})
    this.emitter = new Emitter()

    this.reset()
  }

  destroy () {
    this.destroyed = true

    this.items = null
  }

  setCachedItems (cachedItems) {
    this.cachedItems = cachedItems
  }

  clearCachedItems () {
    this.cachedItems = null
  }

  // Called for every items to be rendered in narrow-editor(=ui)
  // This method can be called multiple times on single query.
  // Since item updated multiple times untill finished.
  // items' index and narrow-editor's row is in-sync.
  // item[0] is always prompt item, real item start from index = 1 and renderd fromm row = 1.
  addItems (items) {
    let index = this.items.length
    for (const item of items) {
      this.items[index] = item
      item._row = index
      index++
    }
    this.selectedItem = null
    this.previouslySelectedItem = null
  }

  itemForRow (row) {
    return this.items[row]
  }

  reset () {
    this.items = [this.promptItem]
    this.selectedItem = null
    this.previouslySelectedItem = null
  }

  selectItem (item) {
    if (item && !item.skip && item !== this.selectedItem) {
      this.previouslySelectedItem = this.selectedItem
      this.selectedItem = item
      this.emitDidChangeSelectedItem({
        oldItem: this.previouslySelectedItem,
        newItem: this.selectedItem
      })
    }
  }

  selectFirstNormalItem () {
    this.selectItem(this.findNormalItem(0, {direction: 'next'}))
  }

  getFirstPositionForSelectedItem () {
    return this.getFirstPositionForItem(this.selectedItem)
  }

  getFirstPositionForItem (item) {
    return new Point(item._row, this.getFirstColumnForItem(item))
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

  getNormalItems (filePath) {
    const items = this.items.filter(item => !item.skip)
    if (this.boundToSingleFile || !filePath) {
      return items
    } else {
      return items.filter(item => item.filePath === filePath)
    }
  }

  getItemsInRowRange (startRow, endRow) {
    if (this.items) {
      return this.items.slice(startRow, endRow + 1)
    } else {
      return []
    }
  }

  getNormalItemCount () {
    return this.getNormalItems().length
  }

  findItem (startRow, {direction, includeStartRow = false}, fn) {
    const stride = direction === 'next' ? +1 : -1
    let row = startRow
    while (true) {
      if (includeStartRow) {
        includeStartRow = false
      } else {
        row = getValidIndexForList(this.items, row + stride)
        if (row === startRow) {
          return null
        }
      }
      const item = this.itemForRow(row)
      // Need gurad because if items was emtpy, `itemForRow` return `undefined`.
      if (item && fn(item)) {
        return item
      }
    }
  }

  findPromptOrNormalItem (row, options) {
    return this.findItem(row, options, item => !item.skip || item === this.promptItem)
  }

  findNormalItem (row, options, fn = () => true) {
    return this.findItem(row, options, item => !item.skip && fn(item))
  }

  findDifferentFileItem (direction) {
    const selectedItem = this.getSelectedItem()
    if (selectedItem) {
      const {filePath} = selectedItem
      return this.findNormalItem(selectedItem._row, {direction}, item => item.filePath !== filePath)
    }
  }

  findNextItemForFilePath (filePath) {
    const selectedItem = this.getSelectedItem()
    if (selectedItem) {
      const options = {direction: 'next', includeStartRow: true}
      return this.findNormalItem(selectedItem._row, options, item => item.filePath === filePath)
    }
  }

  findClosestItemForBufferPosition (point, {filePath} = {}) {
    const items = this.getNormalItems(filePath)
    if (items.length) {
      for (let i = items.length - 1; i >= 0; i--) {
        const item = items[i]
        if (item.point.isLessThanOrEqual(point)) {
          return item
        }
      }
      return items[0]
    }
  }

  selectEqualLocationItem ({point, filePath}) {
    this.selectItem(
      this.findNormalItem(0, {direction: 'next'}, item => item.point.isEqual(point) && item.filePath === filePath)
    )
  }

  getRelativeItem (editor, direction) {
    const selectedItem = this.getSelectedItem()
    if (!selectedItem) {
      return
    }

    // When selectedItem have no filePath, its single file bounded selectedItem so comparable
    // Or selectedItem have filePath and equal to editor's path, is too comparable
    const isComparable = !selectedItem.filePath || selectedItem.filePath === editor.getPath()
    if (!isComparable) {
      return selectedItem
    }

    const currentPosition = editor.getCursorBufferPosition()

    if (direction === 'next') {
      if (selectedItem.point.isGreaterThan(currentPosition)) {
        return selectedItem
      }
    } else {
      const endOfSelectedItem = selectedItem.range ? selectedItem.range.end : selectedItem.point
      if (endOfSelectedItem.isLessThan(currentPosition)) {
        return selectedItem
      }
    }
    this.selectItem(this.findNormalItem(selectedItem._row, {direction}))
  }

  selectRelativeItem (editor, direction) {
    this.selectItem(this.getRelativeItem(editor, direction))
  }
}
