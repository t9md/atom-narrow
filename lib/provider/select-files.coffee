# This is META provider, used to exclude files in narrow-ui.
# This provider is invoked from UI.
{Point} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'

ProviderBase = require './provider-base'

module.exports =
class SelectFiles extends ProviderBase
  boundToSingleFile: true
  includeHeaderRules: true
  showLineHeader: false
  supportCacheItems: true
  supportReopen: false

  initialize: ->
    @clientUi = @options.clientUi
    @headerItems = @clientUi.items.getHeaderItemsHavingFilePathField()

  getItems: ->
    items = []
    projectNames = _.uniq(_.pluck(@headerItems, "projectName"))
    hasMultipleProjects = projectNames.length > 1

    for item in @headerItems.slice()
      {filePath, projectName} = item
      releativeFilePath = atom.project.relativize(filePath)
      if hasMultipleProjects
        text = path.join(projectName, releativeFilePath)
      else
        text = releativeFilePath

      item = {
        text: "# " + text
        filePath: filePath
        point: new Point(0, 0)
      }
      items.push(item)
    items

  confirmed: ->
    if @clientUi.isAlive()
      setSelectedFiles = _.pluck(@ui.items.getNormalItems(), 'filePath')
      @clientUi.setSelectedFiles(setSelectedFiles)
    Promise.resolve(null) # HACK to noop
