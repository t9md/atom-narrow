# This is META provider, invoked from UI.
# Provide narrow-ui to select narrowing target files.
{Point} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'
ProviderBase = require './provider-base'

itemForHeaderItem = ({filePath, projectName}) ->
  {
    text: "# " + path.join(projectName, atom.project.relativize(filePath))
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
    @ui.onDidDestroy =>
      @clientUi.focus(autoPreview: false) if @clientUi.isAlive()

  getItems: ->
    @clientUi.getBeforeFilteredFileHeaderItems().map(itemForHeaderItem)

  confirmed: ->
    if @clientUi.isAlive()
      @clientUi.focus(autoPreview: false)
      @clientUi.setQueryForSelectFiles(@ui.lastQuery)
      selectedFiles = _.pluck(@ui.items.getNormalItems(), 'filePath')
      excludedFiles = @clientUi.getBeforeFilteredFileHeaderItems()
        .map (item) -> item.filePath
        .filter (filePath) -> filePath not in selectedFiles
      @clientUi.setExcludedFiles(excludedFiles)

    Promise.resolve(null) # HACK to noop
