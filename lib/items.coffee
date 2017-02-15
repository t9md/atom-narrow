{
  isNormalItem
  getValidIndexForList
} = require './utils'

module.exports =
class Items
  items: []
  constructor: (@ui) ->

  setItems: (@items) ->

  isPromptRow: (row) ->
    row is 0

  getSelectedItem: ->
    @ui.getSelectedItem()

  getRowForSelectedItem: ->
    @getRowForItem(@getSelectedItem())

  isNormalItemRow: (row) ->
    isNormalItem(@items[row])

  getRowForItem: (item) ->
    @items.indexOf(item)

  getItemForRow: (row) ->
    @items[row]

  getNormalItems: ->
    @items.filter(isNormalItem)

  hasNormalItem: ->
    @items.some(isNormalItem)

  getNormalItemsForFilePath: (filePath) ->
    @items.filter (item) -> isNormalItem(item) and (item.filePath is filePath)

  # When filePath is undefined, it OK cause, `undefined` is `undefined`
  findItem: ({point, filePath}={}) ->
    for item in @getNormalItems()
      if item.point.isEqual(point) and item.filePath is filePath
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
