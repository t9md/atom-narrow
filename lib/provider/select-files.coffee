# This is META provider, invoked from UI.
# Provide narrow-ui to select narrowing target files.
{Point} = require 'atom'
_ = require 'underscore-plus'
ProviderBase = require './provider-base'
settings = require '../settings'
{relativizeFilePath} = require '../utils'

queryByProviderName = {}

module.exports =
class SelectFiles extends ProviderBase
  boundToSingleFile: true
  showLineHeader: false
  supportCacheItems: true
  supportReopen: false
  needRestoreEditorState: false

  @getLastQuery: (providerName) ->
    if settings.get('SelectFiles.rememberQuery')
      queryByProviderName[providerName] ? ''
    else
      ''

  initialize: ->
    {@clientUi} = @options
    @ui.onDidDestroy =>
      @clientUi.focus(autoPreview: false) if @clientUi.isAlive()

  getItems: ->
    filePaths = @clientUi.getFilePathsForAllItems()
    @finishUpdateItems filePaths.map (filePath) ->
      {
        text: relativizeFilePath(filePath)
        filePath: filePath
        point: new Point(0, 0)
      }

  confirmed: ->
    if @clientUi.isAlive()
      @clientUi.updateSelectFilesState(
        queryForSelectFiles: @ui.lastQuery
        selectedFiles: _.pluck(@ui.items.getNormalItems(), 'filePath')
      )

    Promise.resolve(null) # HACK to noop

  destroy: ->
    if @clientUi.isAlive()
      queryByProviderName[@clientUi.provider.name] = @ui.lastQuery

    super
