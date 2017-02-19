_ = require 'underscore-plus'
ProviderBase = require './provider-base'

{isNormalItem} = require '../utils'

# Inject real lineText
injectLineText = (filePath, _items) ->
  items = []
  atom.workspace.open(filePath, activateItem: false).then (editor) ->
    for item in _items
      item.text = editor.lineTextForBufferRow(item.point.row)
      items.push(item)
    return items

module.exports =
class Linter extends ProviderBase
  supportDirectEdit: true

  getItems: ->
    linter = atom.packages.getActivePackage('linter')?.mainModule.provideLinter()
    return unless linter?
    items = linter.views.messages.map ({filePath, text, range}) ->
      {filePath, info: text, point: range.start}

    promises = []
    for filePath, items of _.groupBy(items, ({filePath}) -> filePath)
      promises.push(injectLineText(filePath, items))

    Promise.all(promises).then (values) ->
      items = []
      for item in _.flatten(values)
        items.push(header: "### #{item.info}", filePath: item.filePath, skip: true, item: item)
        items.push(item)
      items

  filterItems: (items, filterSpec) ->
    items = super
    normalItems = items.filter(isNormalItem)

    _.filter items, (item) ->
      if item.item
        item.item in normalItems
      else
        true
