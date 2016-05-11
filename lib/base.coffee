{
  decorateRange
  smartScrollToBufferPosition
} = require './utils'

module.exports =
class Base
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

    if options.reveal?
      smartScrollToBufferPosition(@editor, point)
      @pane.activateItem(@editor)
    else
      @editor.setCursorBufferPosition(point)
      @pane.activate()
      @pane.activateItem(@editor)

    range = @editor.bufferRangeForBufferRow(point[0])
    decorateRange(@editor, range, {class: 'narrow-flash', timeout: 200})
