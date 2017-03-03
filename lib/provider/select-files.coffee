# This is META provider, invoked from UI.
# Provide narrow-ui to select narrowing target files.
{Point} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'
ProviderBase = require './provider-base'
settings = require '../settings'

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
      queryByProviderName[providerName]
    else
      null

  initialize: ->
    {@clientUi} = @options
    @ui.onDidDestroy =>
      @clientUi.focus(autoPreview: false) if @clientUi.isAlive()

  getItems: ->
    @clientUi.getItemsForSelectFiles()

  confirmed: ->
    if @clientUi.isAlive()
      @clientUi.focus(autoPreview: false)
      @clientUi.setQueryForSelectFiles(@ui.lastQuery)
      @clientUi.refresh()

    Promise.resolve(null) # HACK to noop

  destroy: ->
    if @clientUi.isAlive()
      queryByProviderName[@clientUi.provider.name] = @ui.lastQuery

    super
