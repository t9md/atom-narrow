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
    if typeof(config[key]) is 'boolean'
      config[key] = {default: config[key]}

    value = config[key]
    value.type = inferType(value.default) unless value.type?
    value.title ?= _.uncamelcase(key) if injectTitle

  # Inject order props to display orderd in setting-view
  for name, i in Object.keys(config)
    config[name].order = i

  return config

class Settings
  constructor: (@scope, @config) ->
    complimentField(@config)

  get: (param) ->
    atom.config.get "#{@scope}.#{param}"

  set: (param, value) ->
    atom.config.set "#{@scope}.#{param}", value

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
    for param in Object.keys(atom.config.get(@scope)) when param not of @config
      paramsToDelete.push(param)
    @notifyAndDelete(paramsToDelete...)

  notifyAndDelete: (params...) ->
    paramsToDelete = (param for param in params when @has(param))
    return if paramsToDelete.length is 0

    content = [
      "#{@scope}: Config options deprecated.  ",
      "Automatically removed from your `config.cson`  "
    ]
    for param in paramsToDelete
      @delete(param)
      content.push "- `#{param}`"
    atom.notifications.addWarning content.join("\n"), dismissable: true

newProviderConfig = (otherProperties) ->
  properties =
    directionToOpen:
      default: 'inherit'
      enum: [
        'inherit'
        'right'
        'right:never-use-previous-adjacent-pane'
        'right:always-new-pane'
        'down'
        'down:never-use-previous-adjacent-pane'
        'down:always-new-pane'
      ]
    caseSensitivityForNarrowQuery:
      default: 'inherit'
      enum: ['inherit', 'smartcase', 'sensitive', 'insensitive']
    autoPreview: true
    autoPreviewOnQueryChange: true
    closeOnConfirm: true
    revealOnStartCondition:
      default: 'always'
      enum: ['never', 'always', 'on-input']

  _.deepExtend(properties, otherProperties) if otherProperties?

  return {
    type: 'object'
    properties: complimentField(properties, true)
  }

module.exports = new Settings 'narrow',
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

  # Per providers settings
  # -------------------------
  GitDiffAll: newProviderConfig()
  Fold: newProviderConfig(
    revealOnStartCondition:
      default: "on-input"
  )
  Symbols: newProviderConfig(
    revealOnStartCondition:
      default: "on-input"
  )
  ProjectSymbols: newProviderConfig(
    revealOnStartCondition:
      default: "on-input"
  )
  Linter: newProviderConfig()
  Bookmarks: newProviderConfig()
  Scan: newProviderConfig(
    revealOnStartCondition:
      default: "on-input"
    searchWholeWord:
      default: false
      description: """
      This provider is exceptional since it use first query as scan term.<br>
      You can toggle value per narrow-editor via `narrow:scan:toggle-whole-word`( `alt-cmd-w` )<br>
      """
    caseSensitivityForSearchTerm:
      default: 'smartcase'
      enum: ['smartcase', 'sensitive', 'insensitive']
      description: """
      Search term is first word of query, is used as search term
      """
  )
  Search: newProviderConfig(
    caseSensitivityForSearchTerm:
      default: 'smartcase'
      enum: ['smartcase', 'sensitive', 'insensitive']
    searchWholeWord: false
    startByDoubleClick:
      default: false
      description: """
      [Experimental]: start by dounble click.
      You can toggle this value by command `narrow:toggle-search-start-by-double-click`
      """
    agCommandArgs:
      default: "--nocolor --column --vimgrep"
      description: """
      [Experimental: Must be removed in future]<br>
      <br>
      By default args, full command became..<br>
      `ag --nocolor --column PATTERN`<br>
      Be careful narrow don't support every possible combination of args.<br>
      Pick only if it worked.<br>
      e.g.<br>
        Case sensitive: `ag --nocolor --column -s PATTERN`<br>
        Smart case: `ag --nocolor --column -S PATTERN`<br>
        Case sensitive/word only: `ag --nocolor --column -s -w PATTERN`<br>
      """
  )
  AtomScan: newProviderConfig(
    caseSensitivityForSearchTerm:
      default: 'smartcase'
      enum: ['smartcase', 'sensitive', 'insensitive']
    searchWholeWord: false
  )
  GitDiff: newProviderConfig()
