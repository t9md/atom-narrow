{Emitter, Point} = require 'atom'
{
  isNormalItem
  getValidIndexForList
} = require './utils'

module.exports =
class Items
  selectedItem: null
  previouslySelectedItem: null
  items: []

  onDidChangeSelectedItem: (fn) -> @emitter.on('did-change-selected-item', fn)
  emitDidChangeSelectedItem: (event) -> @emitter.emit('did-change-selected-item', event)

  constructor: (@ui) ->
    @promptItem = Object.freeze({_prompt: true, skip: true})
    @emitter = new Emitter

  destroy: ->

  setItems: (items) ->
    @items = [@promptItem, items...]
    @reset()

  reset: ->
    @selectedItem = null
    @previouslySelectedItem = null

  selectItem: (item) ->
    @selectItemForRow(@getRowForItem(item))

  selectItemForRow: (row) ->
    if isNormalItem(item = @getItemForRow(row))
      @previouslySelectedItem = @selectedItem
      @selectedItem = item
      event = {
        oldItem: @previouslySelectedItem
        newItem: @selectedItem
        row: row
      }
      @emitDidChangeSelectedItem(event)

  selectFirstNormalItem: ->
    @selectItemForRow(@findRowForNormalItem(0, 'next'))

  getFirstPositionForSelectedItem: ->
    row = @getRowForItem(@selectedItem)
    column = @getFirstColumnForItem(@selectedItem)
    new Point(row, column)

  getFirstColumnForItem: (item) ->
    if item._lineHeader?
      item._lineHeader.length
    else
      0

  getSelectedItem: ->
    @selectedItem

  hasSelectedItem: ->
    @selectedItem?

  getPreviouslySelectedItem: ->
    @previouslySelectedItem

  getRowForSelectedItem: ->
    @getRowForItem(@getSelectedItem())

  isNormalItemRow: (row) ->
    isNormalItem(@items[row])

  getRowForItem: (item) ->
    @items.indexOf(item)

  getItemForRow: (row) ->
    @items[row]

  getFileHeaderItems: ->
    @items.filter (item) -> item.fileHeader

  getNormalItems: (filePath=null) ->
    if filePath?
      @items.filter (item) -> isNormalItem(item) and (item.filePath is filePath)
    else
      @items.filter(isNormalItem)

  hasNormalItem: ->
    @items.some(isNormalItem)

  getCount: ->
    @getNormalItems().length

  findItem: ({point, filePath}={}) ->
    for item in @getNormalItems(filePath) when item.point.isEqual(point)
      return item

  findRowBy: (row, direction, fn) ->
    startRow = row
    delta = switch direction
      when 'next' then +1
      when 'previous' then -1

    loop
      row = getValidIndexForList(@items, row + delta)
      if fn(row)
        return row

      if row is startRow
        return null

  # Return row
  # Never fail since prompt is row 0 and always exists
  findRowForNormalOrPromptItem: (row, direction) ->
    @findRowBy row, direction, (row) =>
      @isNormalItemRow(row) or @ui.isPromptRow(row)

  findRowForNormalItem: (row, direction) ->
    return null unless @hasNormalItem()
    @findRowBy row, direction, (row) => @isNormalItemRow(row)

  findNormalItemInDirection: (row, direction) ->
    row = @findRowForNormalItem(row, direction)
    @getItemForRow(row) if row?

  findDifferentFileItem: (direction) ->
    return if @ui.provider.boundToSingleFile
    return null unless selectedItem = @getSelectedItem()
    filePath = selectedItem.filePath
    row = @findRowBy @getRowForSelectedItem(), direction, (row) =>
      @isNormalItemRow(row) and @getItemForRow(row).filePath isnt filePath
    @getItemForRow(row)

  findClosestItemForBufferPosition: (point, {filePath}={}) ->
    items = @getNormalItems(filePath)
    return null unless items.length
    for item in items by -1 when item.point.isLessThanOrEqual(point)
      return item
    return items[0]

  selectItemInDirection: (point, direction) ->
    itemToSelect = null
    item = @getSelectedItem()

    if item?
      switch direction
        when 'next'
          itemToSelect = item if point.isLessThan(item.point)
        when 'previous'
          itemToSelect = item if point.isGreaterThan(item.range?.end ? item.point)

    itemToSelect ?= @findNormalItemInDirection(@getRowForItem(item), direction)
    @selectItem(itemToSelect)
