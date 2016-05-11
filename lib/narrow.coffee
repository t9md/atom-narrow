module.exports =
class Narrow
  @fromProvider: (provider) ->
    narrow = new this
    Promise.resolve(provider.getItems()).then (items) ->
      narrow.setItems(items)

  createEditor: ->
    @editor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @editorElement = atom.views.getView(@editor)
    @editor.getTitle = -> ["Narrow", params.title].join(' ')
    @editor.isModified = -> false

  openItemOnAdjacentPane: (item) ->
    activePane = atom.workspace.getActivePane()
    if pane = getAdjacentPaneForPane(activePane)
      pane.activateItem(item)
    else
      pane = activePane.splitRight(items: [item])
    pane.activate()

  constructor: (params) ->
    @createEditor(params)

  setItems: (items) ->
    console.log "gotItems", items

  getSelectedItem: ->

  render: (items) ->
#
# demoNormalUse = ->
#   new Narrow().setItems([1..3])
#
# demoSyncProvider = ->
#   provider = getItems: ->
#     ['a', 'b', 'c']
#   Narrow.fromProvider(provider)
#
# demoAsyncProvider = ->
#   asyncProvider =
#     getItems: ->
#       new Promise (resolve) ->
#         setTimeout((-> resolve(['d', 'e', 'f'])), 1000)
#   Narrow.fromProvider(asyncProvider)
#
# demoNormalUse()
# demoSyncProvider()
# demoAsyncProvider()
