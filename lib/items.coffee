{Emitter, Point} = require 'atom'
ItemIndicator = require './item-indicator'
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
    @emitter = new Emitter
    @indicator = new ItemIndicator(@ui)

  destroy: ->
    @indicator.destroy()

  setItems: (@items) ->

  isPromptRow: (row) ->
    row is 0

  reset: ->
    @selectedItem = null
    @previouslySelectedItem = null

  redrawIndicator: ->
    @indicator.redraw()

  selectItem: (item) ->
    @selectItemForRow(@getRowForItem(item))

  selectItemForRow: (row) ->
    if isNormalItem(item = @getItemForRow(row))
      @indicator.setToRow(row)
      @previouslySelectedItem = @selectedItem
      @selectedItem = item
      event = {
        oldItem: @previouslySelectedItem
        newItem: @selectedItem
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
      item._lineHeader.length - 1
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

  getNormalItems: (filePath=null) ->
    if filePath?
      @items.filter (item) -> isNormalItem(item) and (item.filePath is filePath)
    else
      @items.filter(isNormalItem)

  hasNormalItem: ->
    @items.some(isNormalItem)

  getCount: ->
    @getNormalItems().length

  # When filePath is undefined, it OK cause, `undefined` is `undefined`
  findSelectedItem: ->
    @findItem(@selectedItem)

  findItem: ({point, filePath}={}) ->
    for item in @getNormalItems(filePath) when item.point.isEqual(point)
      return item

  # Return row
  # Never fail since prompt is row 0 and always exists
  findRowForNormalOrPromptItem: (row, direction) ->
    delta = switch direction
      when 'next' then +1
      when 'previous' then -1

    loop
      row = getValidIndexForList(@items, row + delta)
      if @isNormalItemRow(row) or @isPromptRow(row)
        return row

  findRowForNormalItem: (row, direction) ->
    return null unless @hasNormalItem()
    delta = switch direction
      when 'next' then +1
      when 'previous' then -1

    loop
      if @isNormalItemRow(row = getValidIndexForList(@items, row + delta))
        return row

  findDifferentFileItem: (direction) ->
    return if @ui.provider.boundToSingleFile
    return null unless selectedItem = @getSelectedItem()

    delta = switch direction
      when 'next' then +1
      when 'previous' then -1

    nextRow = (row) => getValidIndexForList(@items, row + delta)
    startRow = row = @getRowForSelectedItem()
    while (row = nextRow(row)) isnt startRow
      if @isNormalItemRow(row) and @items[row].filePath isnt selectedItem.filePath
        return @items[row]

  findClosestItemForBufferPosition: (point, {filePath}={}) ->
    items = @getNormalItems(filePath)
    return null unless items.length
    for item in items by -1 when item.point.isLessThanOrEqual(point)
      return item
    return items[0]

  findRowForClosestItemInDirection: (point, direction) ->
    item = @getSelectedItem()
    rowForSelectedItem = @getRowForItem(item)
    switch direction
      when 'next'
        if item? and point.isLessThan(item.range?.start ? item.point)
          return rowForSelectedItem

      when 'previous'
        if item? and point.isGreaterThan(item.range?.end ? item.point)
          return rowForSelectedItem

    @findRowForNormalItem(rowForSelectedItem, direction)
