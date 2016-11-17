{Point, CompositeDisposable} = require 'atom'
{decorateRange} = require '../utils'

module.exports =
class Base
  getName: ->
    @constructor.name

  getTitle: ->
    @constructor.name

  constructor: (@ui, @options={}) ->
    @subscriptions = new CompositeDisposable
    @editor = atom.workspace.getActiveTextEditor()
    @editorElement = atom.views.getView(@editor)
    @pane = atom.workspace.getActivePane()
    @initialize?()
    @ui.start(this)

  subscribe: (args...) ->
    @subscriptions.add(args...)

  getFilterKey: ->
    "text"

  useFuzzyFilter: ->
    false

  keepItemsOrderOnFuzzyFilter: ->
    true

  highlightRow: (editor, row) ->
    range = [[row, 0], [row, 0]]
    decorateRange(editor, range, {type: 'line', class: 'narrow-result'})

  destroy: ->
    @marker?.destroy()
    @subscriptions.dispose()
    {@editor, @editorElement, @marker, @subscriptions} = {}

  confirmed: ({point}, options={}) ->
    @marker?.destroy()
    return unless point?
    point = Point.fromObject(point)

    if options.preview?
      @pane.activateItem(@editor)
      @marker = @highlightRow(@editor, point.row)
    else
      @editor.setCursorBufferPosition(point, autoscroll: false)
      @pane.activate()
      @pane.activateItem(@editor)

    @editor.scrollToBufferPosition(point, center: true)
    @editorElement.component.updateSync()
