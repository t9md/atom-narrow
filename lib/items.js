const {Emitter, Point} = require("atom")
const {isNormalItem, getValidIndexForList} = require("./utils")
const _ = require("underscore-plus")

class Items {
  onDidChangeSelectedItem(fn) {
    return this.emitter.on("did-change-selected-item", fn)
  }
  emitDidChangeSelectedItem(event) {
    return this.emitter.emit("did-change-selected-item", event)
  }

  constructor(ui) {
    this.selectedItem = null
    this.previouslySelectedItem = null
    this.cachedItems = null

    this.ui = ui
    this.promptItem = Object.freeze({_prompt: true, skip: true, _uiRow: 0})
    this.emitter = new Emitter()
    this.items = []
  }

  destroy() {
    this.items = null
  }

  setCachedItems(cachedItems) {
    this.cachedItems = cachedItems
  }

  clearCachedItems() {
    this.cachedItems = null
  }

  addItems(items) {
    let index = this.items.length
    for (const item of items) {
      item._uiRow = index
      this.items[index] = item
      index++
    }
    this.selectedItem = null
    this.previouslySelectedItem = null
  }

  reset() {
    this.items = [this.promptItem]
    this.selectedItem = null
    this.previouslySelectedItem = null
  }

  selectItem(item) {
    this.selectItemForRow(this.getRowForItem(item))
  }

  selectItemForRow(row) {
    const item = this.getItemForRow(row)
    if (isNormalItem(item)) {
      this.previouslySelectedItem = this.selectedItem
      this.selectedItem = item
      const event = {
        oldItem: this.previouslySelectedItem,
        newItem: this.selectedItem,
        row,
      }
      this.emitDidChangeSelectedItem(event)
    }
  }

  selectFirstNormalItem() {
    this.selectItemForRow(this.findRowForNormalItem(0, "next"))
  }

  getFirstPositionForSelectedItem() {
    return this.getFirstPositionForItem(this.selectedItem)
  }

  getFirstPositionForItem(item) {
    return new Point(this.getRowForItem(item), this.getFirstColumnForItem(item))
  }

  getPointForSelectedItemAtColumn(column) {
    return this.getFirstPositionForSelectedItem().translate([0, column])
  }

  getFirstColumnForItem(item) {
    return item._lineHeader ? item._lineHeader.length : 0
  }

  getSelectedItem() {
    return this.selectedItem
  }

  hasSelectedItem() {
    return this.selectedItem != null
  }

  getPreviouslySelectedItem() {
    return this.previouslySelectedItem
  }

  getRowForSelectedItem() {
    return this.getRowForItem(this.getSelectedItem())
  }

  isNormalItemRow(row) {
    return isNormalItem(this.items[row])
  }

  getRowForItem(item) {
    return item ? item._uiRow : -1
  }

  getItemForRow(row) {
    return this.items[row]
  }

  getNormalItems(filePath = null) {
    const normalItems = this.items.filter(isNormalItem)
    if (filePath != null) {
      return normalItems.filter(item => item.filePath === filePath)
    } else {
      return normalItems
    }
  }

  getVisibleItems() {
    const {editor, editorElement} = this.ui
    const [startRow, endRow] = editorElement.getVisibleRowRange()
    return this.items.slice(editor.bufferRowForScreenRow(startRow), editor.bufferRowForScreenRow(endRow) + 1)
  }

  hasNormalItem() {
    return this.items.some(isNormalItem)
  }

  getCount() {
    return this.getNormalItems().length
  }

  findItem({point, filePath} = {}) {
    for (const item of this.getNormalItems(filePath)) {
      if (item.point.isEqual(point)) {
        return item
      }
    }
  }

  findRowBy(row, direction, fn) {
    const startRow = row
    const delta = direction === "next" ? +1 : -1

    while (true) {
      row = getValidIndexForList(this.items, row + delta)
      if (fn(row)) {
        return row
      }

      if (row === startRow) {
        return null
      }
    }
  }

  // Return row
  // Never fail since prompt is row 0 and always exists
  findRowForNormalOrPromptItem(row, direction) {
    const normalRowOrPromptRow = row => this.isNormalItemRow(row) || this.ui.isPromptRow(row)

    return this.findRowBy(row, direction, normalRowOrPromptRow)
  }

  findRowForNormalItem(row, direction) {
    if (!this.hasNormalItem()) return null
    return this.findRowBy(row, direction, row => this.isNormalItemRow(row))
  }

  findNormalItemInDirection(row, direction) {
    row = this.findRowForNormalItem(row, direction)
    if (row != null) {
      return this.getItemForRow(row)
    }
  }

  findDifferentFileItem(direction) {
    if (this.ui.boundToSingleFile) return
    const selectedItem = this.getSelectedItem()
    if (!selectedItem) return

    const {filePath} = selectedItem
    const row = this.findRowBy(this.getRowForSelectedItem(), direction, row => {
      return this.isNormalItemRow(row) && this.getItemForRow(row).filePath !== filePath
    })
    return this.getItemForRow(row)
  }

  findItemForFilePath(filePath) {
    if (this.ui.boundToSingleFile) return
    const selectedItem = this.getSelectedItem()
    if (!selectedItem) return

    const row = this.findRowBy(this.getRowForSelectedItem(), "next", row => {
      return this.isNormalItemRow(row) && this.getItemForRow(row).filePath === filePath
    })
    return this.getItemForRow(row)
  }

  findClosestItemForBufferPosition(point, {filePath} = {}) {
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

  findEqualLocationItem(itemToFind) {
    const items = this.getNormalItems()
    const isEqualLocation = ({point, filePath}) => point.isEqual(itemToFind.point) && filePath === itemToFind.filePath

    return _.detect(items, isEqualLocation)
  }

  selectEqualLocationItem(item) {
    if ((item = this.findEqualLocationItem(item))) {
      this.selectItem(item)
    }
  }

  selectItemInDirection(point, direction) {
    const item = this.getSelectedItem()
    if (!item) return

    if (direction === "next" && item.point.isGreaterThan(point)) {
      return
    }
    const basePoint = item.range ? item.range.end : item.point
    if (direction === "previous" && basePoint.isLessThan(point)) {
      return
    }

    this.selectItem(this.findNormalItemInDirection(this.getRowForItem(item), direction))
  }
}
module.exports = Items
