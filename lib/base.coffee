{decorateRange} = require './utils'

module.exports =
class Base
  autoReveal: false

  getTitle: ->
    @constructor.name

  constructor: (@narrow, @options={}) ->
    @editor = atom.workspace.getActiveTextEditor()
    @pane = atom.workspace.getActivePane()
    @initialize?()
    @narrow.start(this)

  getFilterKey: ->
    "text"

  confirmed: ({point}, options={}) ->
    return unless point?

    @editor.scrollToBufferPosition(point, center: true)

    if options.reveal?
      @pane.activateItem(@editor)
    else
      @editor.setCursorBufferPosition(point)
      @pane.activate()
      @pane.activateItem(@editor)

    range = @editor.bufferRangeForBufferRow(point[0])
    decorateRange(@editor, range, {class: 'narrow-flash', timeout: 200})
