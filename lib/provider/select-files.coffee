# This is META provider, invoked from UI.
# Provide narrow-ui to select narrowing target files.
{Point} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'
ProviderBase = require './provider-base'
settings = require '../settings'

lastQueryByProviderName = {}

module.exports =
class SelectFiles extends ProviderBase
  boundToSingleFile: true
  showLineHeader: false
  supportCacheItems: true
  supportReopen: false
  needRestoreEditorState: false

  @getLastQuery: (providerName) ->
    switch settings.get('SelectFiles.persistQuery')
      when 'never'
        null
      when 'same-provider'
        lastQueryByProviderName[providerName]
      when 'across-providers'
        lastQueryByProviderName['_all']

  initialize: ->
    {@clientUi} = @options
    @headerItems = @clientUi.getBeforeFilteredFileHeaderItems()
    @ui.onDidDestroy =>
      @clientUi.focus(autoPreview: false) if @clientUi.isAlive()

  getItems: ->
    @headerItems.map ({filePath, projectName}) ->
      text: path.join(projectName, atom.project.relativize(filePath))
      filePath: filePath
      point: new Point(0, 0)

  confirmed: ->
    if @clientUi.isAlive()
      @clientUi.focus(autoPreview: false)
      @clientUi.setQueryForSelectFiles(@ui.lastQuery)

      selectedFiles = _.pluck(@ui.items.getNormalItems(), 'filePath')
      allFiles = _.pluck(@headerItems, 'filePath')
      excludedFiles = _.without(allFiles, selectedFiles...)
      @clientUi.setExcludedFiles(excludedFiles)

    Promise.resolve(null) # HACK to noop

  destroy: ->
    if @clientUi.isAlive()
      query = @ui.lastQuery
      lastQueryByProviderName[@clientUi.provider.name] = query
      lastQueryByProviderName['_all'] = query

    super
