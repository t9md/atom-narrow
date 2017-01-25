ProviderBase = require './provider-base'

module.exports =
class Linter extends ProviderBase
  includeHeaderGrammar: true

  getItems: ->
    linter = atom.packages.getActivePackage('linter')?.mainModule.provideLinter()
    return unless linter?
    messages = linter.views.messages

    filePaths = []
    items = []
    for {filePath, text, range: {start: point}} in messages
      if filePath not in filePaths
        filePaths.push(filePath)
        items.push(header: "# #{filePath}", skip: true)
      items.push({filePath, text, point})

    @injectMaxLineTextWidthForItems(items)

  confirmed: (item) ->
    {filePath, point} = item
    @pane.activate()
    atom.workspace.open(filePath, pending: true).then (editor) ->
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      return {editor, point}
