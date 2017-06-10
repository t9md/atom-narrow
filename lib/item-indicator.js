module.exports =
class ItemIndicator
  constructor: (@editor) ->
    @gutter = @editor.addGutter(name: 'narrow-item-indicator', priority: 100)
    @item = document.createElement('span')
    @states = {row: null, protected: false}

  render: ->
    @marker?.destroy()
    @marker = @editor.markBufferPosition([@states.row, 0])
    if @states.protected
      className = "narrow-ui-item-indicator-protected"
    else
      className = "narrow-ui-item-indicator"
    @gutter.decorateMarker(@marker, class: className, item: @item)

  update: (states={}) ->
    for state, value of states
      @states[state] = value
    @render(@states)

  destroy: ->
    @marker?.destroy()
