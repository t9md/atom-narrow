inferType = (value) ->
  switch
    when Number.isInteger(value) then 'integer'
    when typeof(value) is 'boolean' then 'boolean'
    when typeof(value) is 'string' then 'string'
    when Array.isArray(value) then 'array'

class Settings
  constructor: (@scope, @config) ->
    # Inject order props to display orderd in setting-view
    for name, i in Object.keys(@config)
      @config[name].order = i

    for key in Object.keys(@config)
      if typeof(@config[key]) is 'boolean'
        @config[key] = {default: @config[key]}
      value = @config[key]
      unless value.type?
        value.type = inferType(value.default)

  get: (param) ->
    atom.config.get "#{@scope}.#{param}"

  set: (param, value) ->
    atom.config.set "#{@scope}.#{param}", value

  toggle: (param) ->
    @set(param, not @get(param))

  observe: (param, fn) ->
    atom.config.observe "#{@scope}.#{param}", fn

module.exports = new Settings 'narrow',
  directionToOpen:
    default: 'right'
    enum: ['right', 'down', 'here']
    description: "Where to open"
  vmpStartInInsertModeForUI: true
  LinesUseFuzzyFilter: false
  LinesKeepItemsOrderOnFuzzyFilter: true
  FoldUseFuzzyFilter: false
  FoldKeepItemsOrderOnFuzzyFilter: false
