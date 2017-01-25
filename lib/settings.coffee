inferType = (value) ->
  switch
    when Number.isInteger(value) then 'integer'
    when typeof(value) is 'boolean' then 'boolean'
    when typeof(value) is 'string' then 'string'
    when Array.isArray(value) then 'array'

class Settings
  constructor: (@scope, @config) ->
    # Automatically infer and inject `type` of each config parameter.
    # skip if value which aleady have `type` field.
    # Also translate bare `boolean` value to {default: `boolean`} object
    for key in Object.keys(@config)
      if typeof(@config[key]) is 'boolean'
        @config[key] = {default: @config[key]}
      unless (value = @config[key]).type?
        value.type = inferType(value.default)

    # Inject order props to display orderd in setting-view
    for name, i in Object.keys(@config)
      @config[name].order = i


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

module.exports = new Settings 'narrow',
  directionToOpen:
    default: 'right'
    enum: ['right', 'down']
    description: "Where to open narrow-editor"
  caseSensitivityForNarrowQuery:
    default: 'smartcase'
    enum: ['smartcase', 'sensitive', 'insensitive']
    description: "Case sensitivity of your query in narrow-editor"
  vmpAutoChangeModeInUI:
    default: true
    description: "Automatically change mode on narrow-editor, insert-mode(=prompt), normal-mode(=item-area)"

  # Per providers settings
  # -------------------------
  # auto-preview
  AtomScanAutoPreview: true
  BookmarksAutoPreview: true
  FoldAutoPreview: true
  GitDiffAutoPreview: true
  LinesAutoPreview: true
  LinterAutoPreview: true
  SearchAutoPreview: true
  SymbolsAutoPreview: true

  # close-on-confirm
  AtomScanCloseOnConfirm: true
  BookmarksCloseOnConfirm: true
  FoldCloseOnConfirm: true
  GitDiffCloseOnConfirm: true
  LinesCloseOnConfirm: true
  LinterCloseOnConfirm: true
  SearchCloseOnConfirm: true
  SymbolsCloseOnConfirm: true

  # Other
  SearchAgCommandArgs:
    default: "--nocolor --column"
    description: """
    By default args, full command became..<br>
    `ag --nocolor --column PATTERN`<br>
    Be careful narrow don't support every possible combination of args.<br>
    Pick only if it worked.<br>
    e.g.<br>
      Case sensitive: `ag --nocolor --column -s PATTERN`<br>
      Smart case: `ag --nocolor --column -S PATTERN`<br>
      Case sensitive/word only: `ag --nocolor --column -s -w PATTERN`<br>
    """
