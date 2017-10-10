const _ = require("underscore-plus")
const path = require("path")
const {getMemoizedRelativizeFilePath} = require("./utils")
const settings = require("./settings")

// Helper
// -------------------------
function isNormalItem(item) {
  return !item.skip
}

function getLineHeaderForItem(point, maxLineWidth, maxColumnWidth) {
  const lineText = String(point.row + 1)
  let padding = " ".repeat(maxLineWidth - lineText.length)
  let lineHeader = `${padding}${lineText}`
  if (maxColumnWidth != null) {
    const columnText = String(point.column + 1)
    padding = " ".repeat(maxColumnWidth - columnText.length)
    lineHeader = `${lineHeader}:${padding}${columnText}`
  }
  return lineHeader + ": "
}

// Since underscore-plus not support _.findIndex
function findIndexBy(items, fn) {
  for (let i = 0; i < items.length; i++) {
    if (fn(items[i])) return i
  }
}

function findLastIndexBy(items, fn) {
  for (let i = items.length - 1; i >= 0; i--) {
    if (fn(items[i])) return i
  }
}

// Replace old items for filePath or append if items are new filePath.
function replaceOrAppendItemsForFilePath(filePath, items, newItems) {
  let amountOfRemove = 0
  let indexToInsert = items.length - 1

  const isSameFilePath = item => item.filePath === filePath
  const firstIndex = findIndexBy(items, isSameFilePath)
  if (firstIndex != null) {
    const lastIndex = findLastIndexBy(items, isSameFilePath)
    indexToInsert = firstIndex
    amountOfRemove = lastIndex - firstIndex + 1
  }

  items.splice(indexToInsert, amountOfRemove, ...newItems)
  return items
}

function getProjectNameForFilePath(filePath) {
  const projectName = atom.project.relativizePath(filePath)[0]
  if (projectName) {
    return path.basename(projectName)
  }
}

// Reducer
// -------------------------
// Purpose of reducer is build final items through different filter.
// Reducer is filter, which mutate state and mutated state is passed to next reducer.
// All reducers take single state object as argument
// If reducer return object, that object is merged to state and passed to next reducer
// If reducer return nothing, original state is passed to next reducer.
function byMax(max, value) {
  return Math.max(max, value)
}

function toRow(item) {
  return item.point.row
}

function toColumn(item) {
  return item.point.column
}

function injectLineHeader(state) {
  let maxColumnWidth
  if (state.hasCachedItems) return null

  const normalItems = state.items.filter(isNormalItem)
  const maxRow = state.maxRow != null ? state.maxRow : normalItems.map(toRow).reduce(byMax, 0)
  const maxLineWidth = String(maxRow + 1).length

  if (state.showColumn) {
    // NOTE: Intentionally avoid Math.max(columns...) here to keep memory usage low.
    const maxColumn = normalItems.map(toColumn).reduce(byMax, 0)
    // The purpose of keeping minimum 3 width is to prevent item text
    // side-shifted on filtered as long as matched column don't exceed column
    // 100. matched at 1000 column is unlikely. but 100 is likely.
    maxColumnWidth = Math.max(String(maxColumn + 1).length, 3)
  }

  for (const item of normalItems) {
    item._lineHeader = getLineHeaderForItem(item.point, maxLineWidth, maxColumnWidth)
  }
}

function spliceItemsForFilePath({cachedNormalItems, spliceFilePath, items}) {
  if (cachedNormalItems && spliceFilePath) {
    return {
      items: replaceOrAppendItemsForFilePath(spliceFilePath, cachedNormalItems, items),
    }
  }
}

function insertProjectHeader(state) {
  const {projectHeadersInserted} = state
  const items = []
  for (const item of state.items) {
    if (item.skip) {
      items.push(item)
      continue
    }

    let projectName = item.projectName || getProjectNameForFilePath(item.filePath)

    if (!(projectName in projectHeadersInserted)) {
      const template = settings.get("projectHeaderTemplate")
      const header = template.replace("__HEADER__", projectName)
      items.push({header, projectName, skip: true})
      projectHeadersInserted[projectName] = true
    }
    items.push(item)
  }

  return {projectHeadersInserted, items}
}

function insertFileHeader(state) {
  const {fileHeadersInserted} = state
  const items = []
  for (let item of state.items) {
    if (item.skip) {
      items.push(item)
      continue
    }

    const {filePath} = item
    if (!(filePath in fileHeadersInserted)) {
      const template = settings.get("fileHeaderTemplate")
      const header = template.replace("__HEADER__", atom.project.relativize(filePath))
      items.push({header, filePath, skip: true})
      fileHeadersInserted[filePath] = true
    }
    items.push(item)
  }

  return {fileHeadersInserted, items}
}

function collectAllItems(state) {
  return {
    allItems: state.allItems.concat(state.items),
  }
}

// reducer
function filterFilePath(state) {
  let {items, fileExcluded, excludedFiles, filterSpecForSelectFiles} = state
  const before = items.length

  if (excludedFiles.length) {
    items = items.filter(item => !excludedFiles.includes(item.filePath))
  }

  if (filterSpecForSelectFiles) {
    const filterKey = "_relativeFilePath"
    const relativizeFilePath = getMemoizedRelativizeFilePath()
    for (const item of items) {
      if (!item[filterKey]) item[filterKey] = relativizeFilePath(item.filePath)
    }
    items = filterSpecForSelectFiles.filterItems(items, filterKey)
  }

  const after = items.length

  if (!fileExcluded) fileExcluded = before !== after
  return {items, fileExcluded}
}

function filterItems({items, filterSpec}) {
  if (filterSpec) {
    return {items: filterSpec.filterItems(items, "text")}
  }
}

module.exports = {
  injectLineHeader,
  insertProjectHeader,
  insertFileHeader,
  spliceItemsForFilePath,
  collectAllItems,
  filterFilePath,
  filterItems,
}
