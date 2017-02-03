module.exports =
class ItemIndicator
  row: null
  constructor: (@ui) ->
    {@editor} = @ui
    @gutter = @editor.addGutter(name: 'narrow-item-indicator', priority: 100)
    @item = document.createElement('span')

  setToRow: (@row) ->
    @marker?.destroy()
    @marker = @editor.markBufferPosition([@row, 0])
    @gutter.decorateMarker @marker,
      class: @getClassName()
      item: @item

  getClassName: ->
    if @ui.isProtected()
      "narrow-ui-item-indicator-protected"
    else
      "narrow-ui-item-indicator"

  redraw: ->
    @setToRow(@row)

  destroy: ->
    @marker?.destroy()
