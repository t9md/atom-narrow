_ = require 'underscore-plus'

inferType = (value) ->
  switch
    when Number.isInteger(value) then 'integer'
    when typeof(value) is 'boolean' then 'boolean'
    when typeof(value) is 'string' then 'string'
    when Array.isArray(value) then 'array'

complimentField = (config, injectTitle=false) ->
  # Automatically infer and inject `type` of each config parameter.
  # skip if value which aleady have `type` field.
  # Also translate bare `boolean` value to {default: `boolean`} object
  for key in Object.keys(config)
    if inferedType = inferType(config[key])
      config[key] = {default: config[key]}
      config[key].type = inferedType

    value = config[key]
    value.type ?= inferType(value.default)
    value.title ?= _.uncamelcase(key) if injectTitle

  # Inject order props to display orderd in setting-view
  for name, i in Object.keys(config)
    config[name].order = i

  return config

class Settings
  constructor: (@scope, @config) ->
    complimentField(@config)

  get: (param) ->
    atom.config.get("#{@scope}.#{param}")

  set: (param, value) ->
    atom.config.set("#{@scope}.#{param}", value)

  toggle: (param) ->
    @set(param, not @get(param))

  has: (param) ->
    param of atom.config.get(@scope)

  delete: (param) ->
    @set(param, undefined)

  observe: (param, fn) ->
    atom.config.observe "#{@scope}.#{param}", fn

  removeDeprecated: ->
    paramsToDelete = []
    loaded = atom.config.get(@scope)
    for param in Object.keys(loaded)
      if param not of @config
        paramsToDelete.push(param)
      else if @config[param].type is 'object' # Provider config
        providerName = param
        loadedForProvider = loaded[providerName]
        definedForProvider = @config[providerName].properties
        for _param in Object.keys(loadedForProvider) when _param not of definedForProvider
          paramsToDelete.push(providerName + '.' + _param)
    if paramsToDelete.length
      @notifyAndDelete(paramsToDelete...)

  notifyAndDelete: (params...) ->
    content = [
      "#{@scope}: Config options deprecated.  ",
      "Automatically removed from your `config.cson`  "
    ]
    for param in params
      @delete(param)
      content.push "- `#{param}`"
    atom.notifications.addWarning content.join("\n"), dismissable: true

globalSettings =
  autoShiftReadOnlyOnMoveToItemArea:
    default: true
    description: "When cursor moved to item area automatically change to read-only mode"
  directionToOpen:
    default: 'right'
    enum: [
      'right'
      'right:never-use-previous-adjacent-pane'
      'right:always-new-pane'
      'down'
      'down:never-use-previous-adjacent-pane'
      'down:always-new-pane'
    ]
    description: "Where to open narrow-editor when open by split pane."
  caseSensitivityForNarrowQuery:
    default: 'smartcase'
    enum: ['smartcase', 'sensitive', 'insensitive']
    description: "Case sensitivity of your query in narrow-editor"
  activateOnStart:
    default: 'always'
    enum: ['never', 'always', 'on-input']
  confirmOnUpdateRealFile: true

inheritGlobalEnum = (name) ->
  default: 'inherit'
  enum: ['inherit', globalSettings[name].enum...]

# inhe
newProviderConfig = (otherProperties) ->
  properties =
    directionToOpen: inheritGlobalEnum('directionToOpen')
    caseSensitivityForNarrowQuery: inheritGlobalEnum('caseSensitivityForNarrowQuery')
    activateOnStart: inheritGlobalEnum('activateOnStart')
    revealOnStartCondition:
      default: 'always'
      enum: ['always', 'never', 'on-input']
    negateNarrowQueryByEndingExclamation: false
    autoPreview: true
    autoPreviewOnQueryChange: true
    closeOnConfirm: true

  _.deepExtend(properties, complimentField(otherProperties)) if otherProperties?

  return {
    type: 'object'
    collapsed: true
    properties: complimentField(properties, true)
  }

providerSettings =
  Scan: newProviderConfig(
    revealOnStartCondition: 'on-input'
    searchWholeWord:
      default: false
      description: """
        This provider is exceptional since it use first query as scan term.<br>
        You can toggle value per narrow-editor via `narrow-ui:toggle-search-whole-word`( `alt-cmd-w` )<br>
        """
    caseSensitivityForSearchTerm:
      default: 'smartcase'
      enum: ['smartcase', 'sensitive', 'insensitive']
      description: "Search term is first word of query, is used as search term"
  )
  Search: newProviderConfig(
    caseSensitivityForSearchTerm:
      default: 'smartcase'
      enum: ['smartcase', 'sensitive', 'insensitive']
    rememberIgnoreCaseForByHandSearch: false
    rememberIgnoreCaseForByCurrentWordSearch: false
    searchWholeWord: false
    searcher:
      default: 'ag'
      enum: ['ag', 'rg']
      description: """
        Choose `ag`( The silver searcher) or `rg`( ripgrep )
        """
    startByDoubleClick:
      default: false
      description: """
        [Experimental]: start by dounble click.
        You can toggle this value by command `narrow:toggle-search-start-by-double-click`
        """
  )
  AtomScan: newProviderConfig(
    caseSensitivityForSearchTerm:
      default: 'smartcase'
      enum: ['smartcase', 'sensitive', 'insensitive']
    rememberIgnoreCaseForByHandSearch: false
    rememberIgnoreCaseForByCurrentWordSearch: false
    searchWholeWord: false
  )
  Symbols: newProviderConfig(revealOnStartCondition: 'on-input')
  GitDiffAll: newProviderConfig()
  Fold: newProviderConfig(revealOnStartCondition: 'on-input')
  ProjectSymbols: newProviderConfig(revealOnStartCondition: 'on-input')
  Linter: newProviderConfig()
  Bookmarks: newProviderConfig()
  GitDiff: newProviderConfig()
  SelectFiles: newProviderConfig(
    autoPreview: false
    autoPreviewOnQueryChange: false
    negateNarrowQueryByEndingExclamation: true
    closeOnConfirm: true
    revealOnStartCondition: 'never'
    rememberQuery:
      default: false
      description: "Remember query per provider basis and apply it at startup"
  )


module.exports = new Settings('narrow', _.defaults(globalSettings, providerSettings))
