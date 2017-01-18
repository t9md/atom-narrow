_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{requireFrom, padStringLeft} = require '../utils'

# HACK: Core bookmarks package
# I need to get all bookmarks instances, but bookmarks package currently not have service for this.
# But it have serialize/deserialize.
# So I can get all bookrmaks indirectly by serialize then deserialize.
# But I also can't call Bookmarks.deserialize direcltly since it's also register `bookmarks:toggle-bookmark`
# What I need is marker information only so I manually restore marker from serialized value.
getBookmarks = ->
  mainModule = atom.packages.getActivePackage('bookmarks').mainModule
  bookmarksByEditorId = mainModule.serialize()
  bookmarks = []
  for editor in atom.workspace.getTextEditors() when state = bookmarksByEditorId[editor.id]
    bookmarks.push({editor, markerLayer: editor.getMarkerLayer(state.markerLayerId)})
  bookmarks

module.exports =
class Bookmarks extends ProviderBase
  getItemsInEditor: (editor, markerLayer) ->
    filePath = editor.getPath()
    lastRowNumberTextLength = String(editor.getLastBufferRow()).length
    items = []
    for marker in markerLayer.getMarkers()
      point = marker.getStartBufferPosition()
      text = editor.lineTextForBufferRow(point.row)
      items.push({point, text, filePath, lastRowNumberTextLength})

    _.sortBy(items, ({point}) -> point.row)

  getItems: ->
    items = []
    for {editor, markerLayer} in getBookmarks() when markerLayer.getMarkerCount() > 0
      filePath = editor.getPath()
      items.push(header: "# #{filePath}", skip: true)
      items.push(@getItemsInEditor(editor, markerLayer)...)
    items

  confirmed: ({filePath, point}, options={}) ->
    @marker?.destroy()
    @pane.activate()

    if options.preview?
      openOptions = {activatePane: false, pending: true}
      atom.workspace.open(filePath, openOptions).then (editor) =>
        editor.scrollToBufferPosition(point, center: true)
        @marker = @highlightRow(editor, point.row)
    else
      openOptions = {pending: true}
      atom.workspace.open(filePath, openOptions).then (editor) ->
        editor.setCursorBufferPosition(point, autoscroll: false)
        editor.scrollToBufferPosition(point, center: true)

  viewForItem: ({header, text, point, lastRowNumberTextLength}) ->
    if header?
      header
    else
      rowText = padStringLeft(String(point.row + 1), lastRowNumberTextLength)
      "  " + rowText + ":"  + text
