_ = require 'underscore-plus'

# Config definitions
# -------------------------
inheritGlobalEnum = (name) ->
  default: 'inherit'
  enum: ['inherit', globalSettings[name].enum...]

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
  confirmOnUpdateRealFile: true
  queryCurrentWordByDoubleClick: true

ProviderConfigTemplate =
  directionToOpen: inheritGlobalEnum('directionToOpen')
  caseSensitivityForNarrowQuery: inheritGlobalEnum('caseSensitivityForNarrowQuery')
  revealOnStartCondition:
    default: 'always'
    enum: ['always', 'never', 'on-input']
  focusOnStartCondition:
    default: 'always'
    description: "Condition when focus to narrow-editor on start"
    enum: ['always', 'never', 'no-input']
  negateNarrowQueryByEndingExclamation: false
  autoPreview: true
  autoPreviewOnQueryChange: true
  closeOnConfirm: true

SearchFaimilyConfigTemplate =
  caseSensitivityForSearchTerm:
    default: 'smartcase'
    enum: ['smartcase', 'sensitive', 'insensitive']
  revealOnStartCondition: 'on-input'
  searchWholeWord: false
  searchUseRegex: false
  refreshDelayOnSearchTermChange: 700

searchFamilyConfigs =
  Scan: refreshDelayOnSearchTermChange: 10
  Search:
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
  AtomScan: {}

otherProviderConfigs =
  Symbols: revealOnStartCondition: 'on-input'
  GitDiffAll: {}
  Fold: revealOnStartCondition: 'on-input'
  ProjectSymbols: revealOnStartCondition: 'on-input'
  SelectFiles:
    autoPreview: false
    autoPreviewOnQueryChange: false
    negateNarrowQueryByEndingExclamation: true
    closeOnConfirm: true
    revealOnStartCondition: 'never'
    rememberQuery:
      default: false
      description: "Remember query per provider basis and apply it at startup"

# Utils
# -------------------------
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

    # To remove provider prefix
    # e.g. "Scan.AutoPreview" config to appear as "Auto Preview"
    value.title ?= _.uncamelcase(key) if injectTitle

  # Inject order props to display orderd in setting-view
  for name, i in Object.keys(config)
    config[name].order = i

  return config

# Main
# -------------------------
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

  registerProviderConfig: (object, otherTemplate) ->
    for key in Object.keys(object)
      object[key] = @createProviderConfig(otherTemplate, object[key])

    # HACK: An very first load timing, atom.config have no `narrow` config.
    config = atom.config.get('narrow') ? @config
    Object.assign(config, object)

  createProviderConfig: (configs...) ->
    config = Object.assign({}, ProviderConfigTemplate, configs...)
    return {
      type: 'object'
      collapsed: true
      properties: complimentField(config, true)
    }

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

settings = new Settings('narrow', globalSettings)
settings.registerProviderConfig(searchFamilyConfigs, SearchFaimilyConfigTemplate)
settings.registerProviderConfig(otherProviderConfigs)

module.exports = settings
