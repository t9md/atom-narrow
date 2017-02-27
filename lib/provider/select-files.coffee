# This is META provider, invoked from UI.
# Provide narrow-ui to select narrowing target files.
{Point} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'
ProviderBase = require './provider-base'

itemForHeaderItem = (hasMultipleProjects, {filePath, projectName}) ->
  text = atom.project.relativize(filePath)
  # In multi-projects, add projectName to distinguish and narrow by projectName
  if hasMultipleProjects
    text = path.join(projectName, text)

  {
    text: "# " + text
    filePath: filePath
    point: new Point(0, 0)
  }

module.exports =
class SelectFiles extends ProviderBase
  boundToSingleFile: true
  includeHeaderRules: true
  showLineHeader: false
  supportCacheItems: true
  supportReopen: false
  needRestoreEditorState: false

  initialize: ->
    @clientUi = @options.clientUi

  getItems: ->
    items = []
    projectNames = _.uniq(_.pluck(@headerItems, "projectName"))
    itemize = itemForHeaderItem.bind(null, projectNames.length > 1)
    @clientUi.getBeforeFilteredFileHeaderItems().map(itemize)

  confirmed: ->
    if @clientUi.isAlive()
      @clientUi.focus(autoPreview: false)
      @clientUi.setQueryForSelectFiles(@ui.lastQuery)
      @clientUi.setSelectedFiles(_.pluck(@ui.items.getNormalItems(), 'filePath'))
    Promise.resolve(null) # HACK to noop
