_ = require 'underscore-plus'
{Point, CompositeDisposable} = require 'atom'
{
  getAdjacentPaneForPane
  openItemInAdjacentPaneForPane
} = require './utils'
settings = require './settings'
path = require 'path'
NarrowGrammar = require './grammar'

module.exports =
class UI
  @uiByNarrowEditor: new Map()
  autoPreview: false
  preventAutoPreview: false
  destroyed: false
  items: []

  @unregisterUI: (narrowEditor) ->
    @uiByNarrowEditor.delete(narrowEditor)
    @updateWorkspaceClassList()

  @registerUI: (narrowEditor, ui) ->
    @uiByNarrowEditor.set(narrowEditor, ui)
    @updateWorkspaceClassList()

  @updateWorkspaceClassList: ->
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.classList.toggle('has-narrow', @uiByNarrowEditor.size)

  constructor: (@provider, params={}) ->
    @disposables = new CompositeDisposable
    {@initialKeyword, @input} = params

    @originalPane = atom.workspace.getActivePane()
    @gutterItem = document.createElement('span')
    @gutterItem.textContent = " > "

    @narrowEditor = atom.workspace.buildTextEditor(lineNumberGutterVisible: false)
    @narrowEditor.getTitle = => @provider.getDashName()
    @narrowEditor.isModified = -> false
    @narrowEditor.onDidDestroy => @destroy()
    @narrowEditorElement = @narrowEditor.element
    @narrowEditorElement.classList.add('narrow')
    @gutter = @narrowEditor.addGutter(name: 'narrow')

    @narrowEditor.insertText("\n")
    @narrowEditor.setCursorBufferPosition([0, Infinity])

    @registerCommands()
    @disposables.add(@observeInputChange())
    @observeCursorPositionChangeForNarrowEditor()
    @constructor.registerUI(@narrowEditor, this)

  focus: ->
    if @isAlive()
      @pane.activate()
      @pane.activateItem(@narrowEditor)

  isAlive: ->
    @narrowEditor?.isAlive?()

  destroy: ->
    return if @destroyed
    @destroyed = true

    @disposables.dispose()
    @narrowEditor.destroy()
    @originalPane.activate() if @originalPane.isAlive()
    @provider?.destroy?()
    @gutterMarker?.destroy()
    @constructor.unregisterUI(@narrowEditor)
    @rowMarker?.destroy()

  registerCommands: ->
    atom.commands.add @narrowEditorElement,
      'core:confirm': => @confirm()
      'narrow-ui:confirm-keep-open': => @confirm(keepOpen: true)
      'narrow-ui:preview-item': => @preview()
      'narrow-ui:toggle-auto-preview': => @toggleAutoPreview()

  moveUpDown: (direction) ->
    if (row = @getRowForSelectedItem()) >= 0
      @withLock => @narrowEditor.setCursorBufferPosition([row, 0])

    @withPreventAutoPreview =>
      switch direction
        when 'up' then @narrowEditor.moveUp()
        when 'down' then @narrowEditor.moveDown()

    @confirm(keepOpen: true)

  nextItem: (options) ->
    @moveUpDown('down', options)

  previousItem: (options) ->
    @moveUpDown('up', options)

  isAutoPreview: ->
    if @preventAutoPreview
      false
    else
      @autoPreview

  toggleAutoPreview: ->
    @autoPreview = not @autoPreview
    @preview() if @isAutoPreview()

  getItems: ->
    Promise.resolve(@provider.getItems())

  start: ->
    if @provider.getName() in ['Search', 'Bookmarks']
      includeHeaderRules = true

    @grammar = new NarrowGrammar(@narrowEditor, {@initialKeyword, includeHeaderRules})
    @grammar.activate()
    @narrowEditorElement.classList.add(@provider.getDashName())

    if @provider.syncToEditor
      @disposables.add @provider.editor.onDidChangeCursorPosition =>
        if @items.length and item = @findNearestItem(@items)
          @selectItem(item)
          if (row = @getRowForSelectedItem()) >= 0
            unless @narrowEditor.getCursorBufferPosition().row is row
              @withLock =>
                @narrowEditor.setCursorBufferPosition([row, 0])

      @disposables.add @provider.editor.onDidDestroy =>
        @destroy()

    @disposables.add atom.workspace.onDidStopChangingActivePaneItem (item) =>
      if item isnt @narrowEditor
        @rowMarker?.destroy()

    activePane = atom.workspace.getActivePane()
    direction = settings.get('directionToOpen')
    if direction is 'here'
      @pane = activePane.activateItem(@narrowEditor)
      @autoPreview = false
    else
      @pane = openItemInAdjacentPaneForPane(activePane, @narrowEditor, direction)
      defaultAutoPreviewConfigName = @provider.getName() + "DefaultAutoPreview"
      @autoPreview = settings.get(defaultAutoPreviewConfigName) ? false

    @getItems().then (items) =>
      @setItems(items)
      if @input
        @narrowEditor.insertText(@input)

  findNearestItem: (items) ->
    cursorPosition = @provider.editor.getCursorBufferPosition()
    # Detect item
    # - cursor position is equal or greather than that item.
    for item, i in items by -1 when item.point?
      itemPoint = Point.fromObject(item.point)
      break if itemPoint.isLessThanOrEqual(cursorPosition)
    return item

  getNarrowQuery: ->
    @narrowEditor.lineTextForBufferRow(0)

  refresh: ->
    query = @getNarrowQuery()
    words = _.compact(query.split(/\s+/))
    pattern = words.map(_.escapeRegExp).join('|')
    @grammar.update({pattern})

    @getItems().then (items) =>
      @clearItemsText()
      @setItems(@provider.filterItems(items, words))

  observeInputChange: ->
    @narrowEditor.buffer.onDidChange ({newRange}) =>
      if newRange.start.row is 0
        @refresh()

  locked: false
  isLocked: -> @locked
  withLock: (fn) ->
    @locked = true
    fn()
    @locked = false

  withPreventAutoPreview: (fn) ->
    @preventAutoPreview = true
    fn()
    @preventAutoPreview = false

  observeCursorPositionChangeForNarrowEditor: ->
    @narrowEditor.onDidChangeCursorPosition (event) =>
      {oldBufferPosition, newBufferPosition, textChanged, cursor} = event
      return if @isLocked() or
        not cursor.selection.isEmpty() or
        textChanged or
        (newBufferPosition.row is 0) or
        (oldBufferPosition.row is newBufferPosition.row)

      direction = if (newBufferPosition.row - oldBufferPosition.row) > 0 then 'next' else 'previous'
      {row, column} = newBufferPosition
      @withLock =>
        row = @findValidItem(row, direction)
        if row? # row might be '0'
          @selectItemForRow(row)
          cursor.setBufferPosition([row, column])
        else if direction is 'previous'
          cursor.setBufferPosition([0, column])

      @preview() if @isAutoPreview()

  preview: ->
    @confirm(keepOpen: true).then ({editor, item}) =>
      @rowMarker = @highlightRow(editor, Point.fromObject(item.point).row)
      @focus()

  isValidItem: (item) ->
    item? and not item.skip

  setGutterMarkerToRow: (row) ->
    @gutterMarker?.destroy()
    @gutterMarker = @narrowEditor.markBufferPosition([row, 0])
    @gutter.decorateMarker @gutterMarker,
      class: "narrow-ui-row"
      item: @gutterItem

  highlightRow: (editor, row) ->
    point = [row, 0]
    marker = editor.markBufferRange([point, point])
    editor.decorateMarker(marker, type: 'line', class: 'narrow-result')
    marker

  confirm: (options={}) ->
    @rowMarker?.destroy()
    item = @getSelectedItem()
    done = @provider.confirmed(item)
    done = Promise.resolve(@provider.editor) unless done instanceof Promise
    done.then (editor) =>
      unless options.keepOpen
        @narrowEditor.destroy()
      {editor, item}

  # clear text from  2nd row to last row.
  clearItemsText: ->
    range = [[1, 0], @narrowEditor.getEofBufferPosition()]
    @narrowEditor.setTextInBufferRange(range, '')

  appendText: (text) ->
    eof = @narrowEditor.getEofBufferPosition()
    @narrowEditor.setTextInBufferRange([eof, eof], text)

  # Return row
  findValidItem: (startRow, direction) ->
    maxRow = @items.length - 1
    rows = if direction is 'next'
      [startRow..maxRow]
    else
      [startRow..0]

    for row in rows when @isValidItem(@items[row])
      return row
    null

  getRowForSelectedItem: ->
    @getRowForItem(@getSelectedItem())

  getRowForItem: (item) ->
    @items.indexOf(item)

  selectItem: (item) ->
    if (row = @items.indexOf(item) ) >= 0
      @selectItemForRow(row)

  selectItemForRow: (row) ->
    item = @items[row]
    if @isValidItem(item)
      @setGutterMarkerToRow(row)
      @selectedItem = item

  getSelectedItem: ->
    @selectedItem ? {}

  setItems: (items) ->
    @items = [{_prompt: true, skip: true}, items...]
    texts = items.map (item) => @provider.viewForItem(item)
    @appendText(texts.join("\n"))
    @selectItemForRow(@findValidItem(1, 'next'))
