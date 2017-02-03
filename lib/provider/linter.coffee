_ = require 'underscore-plus'
ProviderBase = require './provider-base'


module.exports =
class Linter extends ProviderBase
  includeHeaderGrammar: true
  indentTextForLineHeader: "    "
  supportDirectEdit: true

  injectLineText: (filePath, items) ->
    # Inject real lineText
    result = []
    result.push(header: "# #{filePath}", skip: true, fileHeader: true, filePath: filePath)
    atom.workspace.open(filePath, activateItem: false).then (editor) ->
      for item in items
        text = editor.lineTextForBufferRow(item.point.row)
        item.text = text
        result.push(header: "  # #{item.info}", filePath: filePath, skip: true, item: item)
        result.push(item)
      return result

  getItems: ->
    linter = atom.packages.getActivePackage('linter')?.mainModule.provideLinter()
    return unless linter?
    items = linter.views.messages.map ({filePath, text, range}) ->
      {filePath, info: text, point: range.start}

    promises = []
    for filePath, items of _.groupBy(items, ({filePath}) -> filePath)
      promises.push(@injectLineText(filePath, items))

    Promise.all(promises).then (values) =>
      @injectMaxLineTextWidthForItems(_.flatten(values))

  filterItems: (items, filterSpec) ->
    items = super
    normalItems = _.reject(items, (item) -> item.skip)
    filePaths = _.uniq(_.pluck(normalItems, "filePath"))

    _.filter items, (item) ->
      if item.header?
        if item.fileHeader
          item.filePath in filePaths
        else
          item.item in normalItems
      else
        true
