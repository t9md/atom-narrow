const Path = require('path')
const {getMemoizedRelativizeFilePath} = require('./utils')
const settings = require('./settings')

// Helper
// -------------------------
function getLineHeaderForItem (point, maxLineWidth, maxColumnWidth) {
  const lineText = String(point.row + 1)
  let padding = ' '.repeat(maxLineWidth - lineText.length)
  let lineHeader = `${padding}${lineText}`
  if (maxColumnWidth != null) {
    const columnText = String(point.column + 1)
    padding = ' '.repeat(maxColumnWidth - columnText.length)
    lineHeader = `${lineHeader}:${padding}${columnText}`
  }
  return lineHeader + ': '
}

function findIndexBy (items, fn) {
  for (let i = 0; i < items.length; i++) {
    if (fn(items[i])) return i
  }
}

function findLastIndexBy (items, fn) {
  for (let i = items.length - 1; i >= 0; i--) {
    if (fn(items[i])) return i
  }
}

// Replace old items for filePath or append if items are new filePath.
function replaceOrAppendItemsForFilePath (filePath, items, newItems) {
  const isSameFilePath = item => item.filePath === filePath
  const firstIndex = findIndexBy(items, isSameFilePath)
  if (firstIndex != null) {
    const amountOfRemove = findLastIndexBy(items, isSameFilePath) - firstIndex + 1
    items.splice(firstIndex, amountOfRemove, ...newItems)
  } else {
    items.push(...newItems)
  }
  return items
}

function getProjectNameForFilePath (filePath) {
  const projectName = atom.project.relativizePath(filePath)[0]
  if (projectName) {
    return Path.basename(projectName)
  }
}

// Reducer
// -------------------------
// Purpose of reducer is build final items through different filter.
// Reducer is filter, which mutate state and mutated state is passed to next reducer.
// All reducers take single state object as argument
// If reducer return object, that object is merged to state and passed to next reducer
// If reducer return nothing, original state is passed to next reducer.
function byMax (max, value) {
  return Math.max(max, value)
}

function toRow (item) {
  return item.point.row
}

function toColumn (item) {
  return item.point.column
}

function injectLineHeader (state) {
  let maxColumnWidth

  const normalItems = state.items.filter(item => !item.skip)
  if (normalItems.length && normalItems[0]._lineHeader) {
    return null
  }
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

function spliceItemsForFilePath ({existingItems, spliceFilePath, items}) {
  if (existingItems && spliceFilePath) {
    return {
      items: replaceOrAppendItemsForFilePath(spliceFilePath, existingItems, items)
    }
  }
}

function insertProjectHeader (state) {
  const template = settings.get('projectHeaderTemplate')

  const {projectHeadersInserted} = state
  const items = []
  for (const item of state.items) {
    if (!item.skip) {
      let projectName = item.projectName || getProjectNameForFilePath(item.filePath)
      if (!projectHeadersInserted.has(projectName)) {
        items.push({
          header: template.replace('__HEADER__', projectName),
          headerType: 'project',
          projectName: projectName,
          skip: true
        })
        projectHeadersInserted.add(projectName)
      }
    }
    items.push(item)
  }

  return {projectHeadersInserted, items}
}

function insertFileHeader (state) {
  const template = settings.get('fileHeaderTemplate')
  const {fileHeadersInserted} = state

  const items = []
  for (let item of state.items) {
    if (!item.skip) {
      const filePath = item.filePath
      if (!fileHeadersInserted.has(filePath)) {
        items.push({
          header: template.replace('__HEADER__', atom.project.relativize(filePath)),
          headerType: 'file',
          filePath: filePath,
          skip: true
        })
        fileHeadersInserted.add(filePath)
      }
    }
    items.push(item)
  }

  return {fileHeadersInserted, items}
}

function collectAllItems (state) {
  return {
    allItems: state.allItems.concat(state.items)
  }
}

// reducer
function filterFilePath (state) {
  let {items, fileExcluded, excludedFiles, filterSpecForSelectFiles} = state
  const beforeFilterItemLength = items.length

  if (excludedFiles.length) {
    items = items.filter(item => !excludedFiles.includes(item.filePath))
  }

  if (filterSpecForSelectFiles) {
    const filterKey = '_relativeFilePath'
    const relativizeFilePath = getMemoizedRelativizeFilePath()
    for (const item of items) {
      if (!item[filterKey]) item[filterKey] = relativizeFilePath(item.filePath)
    }
    items = filterSpecForSelectFiles.filterItems(items, filterKey)
  }

  return {
    items: items,
    fileExcluded: fileExcluded || beforeFilterItemLength !== items.length
  }
}

function filterItems ({items, filterSpec}) {
  if (filterSpec) {
    return {items: filterSpec.filterItems(items, 'text')}
  }
}

const Reducer = {
  injectLineHeader,
  insertProjectHeader,
  insertFileHeader,
  spliceItemsForFilePath,
  collectAllItems,
  filterFilePath,
  filterItems
}

// Reducer class
// -------------------------
module.exports = class ItemReducer {
  constructor (config) {
    this.reducers = [
      Reducer.spliceItemsForFilePath,
      config.showLineHeader && Reducer.injectLineHeader,
      Reducer.collectAllItems, // Correct BEFORE filter, insert file or project header
      Reducer.filterFilePath,
      Reducer.filterItems,
      config.showProjectHeader && Reducer.insertProjectHeader,
      config.showFileHeader && Reducer.insertFileHeader,
      config.renderItems
    ].filter(v => v)
  }

  reduce (state) {
    this.reducers.reduce((state, reducer) => {
      return Object.assign(state, reducer(state))
    }, state)
  }
}
