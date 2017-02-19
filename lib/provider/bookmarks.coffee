_ = require 'underscore-plus'
ProviderBase = require './provider-base'
{requireFrom, padStringLeft, compareByPoint} = require '../utils'

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

  getItemsForEditor: (editor, markerLayer) ->
    filePath = editor.getPath()
    markerLayer.getMarkers()
      .map (marker) ->
        point = marker.getStartBufferPosition()
        text = editor.lineTextForBufferRow(point.row)
        {point, text, filePath}
      .sort(compareByPoint)

  getItems: ->
    items = []
    for {editor, markerLayer} in getBookmarks() when markerLayer.getMarkerCount() > 0
      items.push(@getItemsForEditor(editor, markerLayer)...)
    items
