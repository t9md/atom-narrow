_ = require 'underscore-plus'
Base = require './base'
{Point} = require 'atom'
{padStringLeft, requireFrom} = require '../utils'
settings = require '../settings'

TagGenerator = requireFrom('symbols-view', 'tag-generator')

module.exports =
class Symbols extends Base
  cachedTags: {}

  initialize: ->
    @subscribe @editor.onDidSave(@refresh.bind(this))

  refresh: ->
    [@items, @width] = []  # invalidate cache.
    @ui.refresh()

  getTags: ->
    filePath = @editor.getPath()
    scopeName = @editor.getGrammar().scopeName
    new TagGenerator(filePath, scopeName).generate()

  getItems: ->
    if @items?
      @items
    else
      toItem = ({name, position}) => {point: position, text: @editor.lineTextForBufferRow(position.row)}

      @getTags().then (tags) =>
        # We show full line text of symbol's line, so just care for which line have symbols.
        @items = _.uniq(tags, (tag) -> tag.position.row).map(toItem)

  viewForItem: ({point, text}) ->
    @width ?= String(@editor.getLastBufferRow()).length
    padString = padStringLeft(String(point.row + 1), @width)
    "#{padString}:#{text}"
