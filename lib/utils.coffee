{Range} = require 'atom'
_ = require 'underscore-plus'

getAdjacentPaneForPane = (pane) ->
  return unless children = pane.getParent().getChildren?()
  index = children.indexOf(pane)
  options = {split: 'left', activatePane: false}

  _.chain([children[index-1], children[index+1]])
    .filter (pane) ->
      pane?.constructor?.name is 'Pane'
    .last()
    .value()

openItemInAdjacentPane = (item, direction) ->
  activePane = atom.workspace.getActivePane()
  if direction is 'here'
    activePane.activateItem(item)
    return

  if pane = getAdjacentPaneForPane(activePane)
    pane.activateItem(item)
    pane.activate()
  else
    switch direction
      when 'right' then activePane.splitRight(items: [item])
      when 'down' then activePane.splitDown(items: [item])

getView = (model) ->
  atom.views.getView(model)

getVisibleBufferRange = (editor) ->
  [startRow, endRow] = getView(editor).getVisibleRowRange()
  return null unless (startRow? and endRow?)
  startRow = editor.bufferRowForScreenRow(startRow)
  endRow = editor.bufferRowForScreenRow(endRow)
  new Range([startRow, 0], [endRow, Infinity])

module.exports = {
  getView
  getAdjacentPaneForPane
  getVisibleBufferRange
  openItemInAdjacentPane
}
