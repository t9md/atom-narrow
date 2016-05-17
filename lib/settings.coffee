class Settings
  constructor: (@scope, @config) ->

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
    order: 0
    type: 'string'
    default: 'right'
    enum: ['right', 'down', 'here']
    description: "Where to open"
  vmpStartInInsertModeForUI:
    order: 1
    type: 'boolean'
    default: true
  LinesUseFuzzyFilter:
    order: 2
    type: 'boolean'
    default: false
  LinesKeepItemsOrderOnFuzzyFilter:
    order: 3
    type: 'boolean'
    default: false
  FoldUseFuzzyFilter:
    order: 4
    type: 'boolean'
    default: false
  FoldKeepItemsOrderOnFuzzyFilter:
    order: 5
    type: 'boolean'
    default: false
