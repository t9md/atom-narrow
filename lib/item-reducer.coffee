_ = require 'underscore-plus'
path = require('path')
{getMemoizedRelativizeFilePath} = require './utils'

# Helper
# -------------------------
isNormalItem = (item) -> not item.skip

getLineHeaderForItem = (point, maxLineWidth, maxColumnWidth) ->
  lineText = String(point.row + 1)
  padding = " ".repeat(maxLineWidth - lineText.length)
  lineHeader = "#{padding}#{lineText}"
  if maxColumnWidth?
    columnText = String(point.column + 1)
    padding = " ".repeat(maxColumnWidth - columnText.length)
    lineHeader = "#{lineHeader}:#{padding}#{columnText}"
  lineHeader + ": "

# Since underscore-plus not support _.findIndex
findIndexBy = (items, fn) ->
  for item, i in items when fn(item)
    return i

findLastIndexBy = (items, fn) ->
  for item, i in items by -1 when fn(item)
    return i

# Replace old items for filePath or append if items are new filePath.
replaceOrAppendItemsForFilePath = (filePath, oldItems, newItems) ->
  amountOfRemove = 0
  indexToInsert = oldItems.length - 1

  isSameFilePath = (item) -> item.filePath is filePath
  firstIndex = findIndexBy(oldItems, isSameFilePath)
  if firstIndex?
    lastIndex = findLastIndexBy(oldItems, isSameFilePath)
    indexToInsert = firstIndex
    amountOfRemove = lastIndex - firstIndex + 1

  oldItems.splice(indexToInsert, amountOfRemove, newItems...)
  oldItems

getProjectNameForFilePath = (filePath) ->
  path.basename(atom.project.relativizePath(filePath)[0])

# Reducer
# -------------------------
# Purpose of reducer is build final items through different filter.
# Reducer is filter, which mutate state and mutated state is passed to next reducer.
# All reducers take single state object as argument
# If reducer return object, that object is merged to state and passed to next reducer
# If reducer return nothing, original state is passed to next reducer.
byMax = (max, value) -> Math.max(max, value)
toRow = (item) -> item.point.row
toColumn = (item) -> item.point.column

injectLineHeader = (state) ->
  return null if state.hasCachedItems

  normalItems = state.items.filter(isNormalItem)
  maxRow = state.maxRow ? normalItems.map(toRow).reduce(byMax, 0)
  maxLineWidth = String(maxRow + 1).length

  if state.showColumn
    # NOTE: Intentionally avoid Math.max(columns...) here to keep memory usage low.
    maxColumn = normalItems.map(toColumn).reduce(byMax, 0)
    # The purpose of keeping minimum 3 width is to prevent item text
    # side-shifted on filtered as long as matched column don't exceed column
    # 100. matched at 1000 column is unlikely. but 100 is likely.
    maxColumnWidth = Math.max(String(maxColumn + 1).length, 3)

  for item in normalItems
    item._lineHeader = getLineHeaderForItem(item.point, maxLineWidth, maxColumnWidth)

  return null

spliceItemsForFilePath = (state) ->
  {cachedNormalItems, spliceFilePath, items} = state
  if cachedNormalItems? and spliceFilePath?
    return {items: replaceOrAppendItemsForFilePath(spliceFilePath, cachedNormalItems, items)}
  else
    null

insertProjectHeader = (state) ->
  {projectHeadersInserted} = state
  items = []
  for item in state.items
    if item.skip
      item.push(item)
      continue

    if item.projectName
      projectName = item.projectName
    else
      projectName = getProjectNameForFilePath(item.filePath)

    if projectName not of projectHeadersInserted
      header = "# #{projectName}"
      items.push({header, projectName, skip: true})
      projectHeadersInserted[projectName] = true

    items.push(item)

  return {projectHeadersInserted, items}

insertFileHeader = (state) ->
  {fileHeadersInserted} = state
  items = []
  for item in state.items
    if item.skip
      items.push(item)
      continue

    filePath = item.filePath
    if filePath not of fileHeadersInserted
      header = "## " + atom.project.relativize(filePath)
      items.push({header, filePath, skip: true})
      fileHeadersInserted[filePath] = true
    items.push(item)

  return {fileHeadersInserted, items}

collectAllItems = (state) ->
  {allItems: state.allItems.concat(state.items)}

# reducer
filterFilePath = (state) ->
  {items, fileExcluded, excludedFiles, filterSpecForSelectFiles} = state
  before = items.length

  if excludedFiles.length
    items = items.filter (item) -> item.filePath not in excludedFiles

  if filterSpecForSelectFiles?
    relativizeFilePath = getMemoizedRelativizeFilePath()
    for item in items when filePath = item.filePath
      item._relativeFilePath ?= relativizeFilePath(filePath)
    items = filterSpecForSelectFiles.filterItems(items, '_relativeFilePath')

  after = items.length

  fileExcluded = before isnt after unless fileExcluded
  return {items, fileExcluded}

module.exports = {
  injectLineHeader
  insertProjectHeader
  insertFileHeader
  spliceItemsForFilePath
  collectAllItems
  filterFilePath
}
