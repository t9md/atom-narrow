ProviderBase = require './provider-base'

module.exports =
class Linter extends ProviderBase
  includeHeaderGrammar: true

  getItems: ->
    linter = atom.packages.getActivePackage('linter')?.mainModule.provideLinter()
    return unless linter?

    filePaths = []
    items = []
    for {filePath, text, range: {start: point}} in linter.views.messages
      if filePath not in filePaths
        filePaths.push(filePath)
        items.push(header: "# #{filePath}", skip: true)
      items.push({filePath, text, point})

    @injectMaxLineTextWidthForItems(items)
