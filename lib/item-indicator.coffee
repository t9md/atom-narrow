module.exports =
class ItemIndicator
  row: null
  constructor: (@ui) ->
    {@editor} = @ui
    @gutter = @editor.addGutter(name: 'narrow-item-indicator', priority: 100)

    @item = document.createElement('span')
    # @item.className = 'icon icon-arrow-right'
    # @item.textContent = " > "

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

  setClassName: (@className) ->

  destroy: ->
    @marker?.destroy()
