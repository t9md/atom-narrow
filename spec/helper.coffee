_ = require 'underscore-plus'
{inspect} = require 'util'
Ui = require '../lib/ui'
ProviderBase = require "../lib/provider/provider-base"

startNarrow = (providerName, options) ->
  ProviderBase.start(providerName, options).then(getNarrowForUi)

reopen = ->
  ProviderBase.reopen()

getNarrowForUi = (ui) ->
  provider = ui.provider
  props = {provider, ui}
  ensureer = new Ensureer(ui, provider)
  for propName in ['ensure', 'waitsForRefresh', 'waitsForConfirm', 'waitsForDestroy', 'waitsForPreview']
    props[propName] = ensureer[propName]
  props

dispatchCommand = (target, commandName) ->
  atom.commands.dispatch(target, commandName)

dispatchEditorCommand = (commandName, editor=null) ->
  editor ?= atom.workspace.getActiveTextEditor()
  atom.commands.dispatch(editor.element, commandName)

ensureCursorPosition = (editor, position) ->
  expect(editor.getCursorBufferPosition()).toEqual(position)

validateOptions = (options, validOptions, message) ->
  invalidOptions = _.without(_.keys(options), validOptions...)
  if invalidOptions.length
    throw new Error("#{message}: #{inspect(invalidOptions)}")

ensureEditor = (editor, options) ->
  ensureEditorOptionsOrdered = [
    'cursor', 'text', 'active', 'alive'
  ]
  validateOptions(options, ensureEditorOptionsOrdered, "invalid options ensureEditor")
  for name in ensureEditorOptionsOrdered when (value = options[name])?
    switch name
      when 'cursor'
        expect(editor.getCursorBufferPosition()).toEqual(value)
      when 'active'
        expect(atom.workspace.getActiveTextEditor() is editor).toBe(value)
      when 'alive'
        expect(editor.isAlive()).toBe(value)

ensureEditorIsActive = (editor) ->
  expect(atom.workspace.getActiveTextEditor()).toBe(editor)

isProjectHeaderItem = (item) ->
  item.header? and item.projectName and not item.filePath?

isFileHeaderItem = (item) ->
  item.header? and item.filePath?

addCustomMatchers = (spec) ->
  spec.addMatchers
    toEqualSearchItems: (expected) ->
      @message = ->
        "Expected '" + inspect(@actual) + "' to equal '" + inspect(expected)

      _.isEqual(@actual, expected)

beforeEach ->
  addCustomMatchers(this)

class Ensureer
  constructor: (@ui, @provider) ->
    {@editor, @items, @editorElement} = @ui

  ensureOptionsOrdered = [
    'itemsCount', 'selectedItemRow', 'selectedItemText'
    'text', 'cursor', 'classListContains'
    'filePathForProviderPane'
    'query'
    'searchItems'
    'columnForSelectedItem'
  ]

  waitsForDestroy: (fn) =>
    disposable = @ui.onDidDestroy -> disposable.dispose()
    fn()
    waitsFor -> disposable.disposed

  waitsForRefresh: (fn) =>
    disposable = @ui.onDidRefresh -> disposable.dispose()
    fn()
    waitsFor -> disposable.disposed

  waitsForConfirm: (fn) =>
    disposable = @ui.onDidConfirm -> disposable.dispose()
    fn()
    waitsFor -> disposable.disposed

  waitsForPreview: (fn) =>
    disposable = @ui.onDidPreview -> disposable.dispose()
    fn()
    waitsFor -> disposable.disposed

  ensure: (args...) =>
    switch args.length
      when 1 then [options] = args
      when 2 then [query, options] = args

    validateOptions(options, ensureOptionsOrdered, 'Invalid ensure option')

    ensureOptions = =>
      for name in ensureOptionsOrdered when options[name]?
        method = 'ensure' + _.capitalize(_.camelize(name))
        this[method](options[name])

    if query?
      runs =>
        @waitsForRefresh =>
          @ui.setQuery(query)
          if @ui.autoPreviewOnQueryChange
            advanceClock(200)
          @ui.moveToPrompt()
      runs -> ensureOptions()
    else
      ensureOptions()

  ensureItemsCount: (count) ->
    expect(@items.getCount()).toBe(count)

  ensureSelectedItemRow: (row) ->
    expect(@items.getRowForSelectedItem()).toBe(row)

  ensureSelectedItemText: (text) ->
    expect(@items.getSelectedItem().text).toBe(text)

  ensureText: (text) ->
    expect(@editor.getText()).toBe(text)

  ensureQuery: (text) ->
    expect(@ui.getQuery()).toBe(text)

  ensureSearchItems: (object) ->
    relativizedFilePath = (item) ->
      atom.project.relativize(item.filePath)

    actualObject = {}
    projectName = null
    for item in @ui.items.items[1...]
      switch
        when isProjectHeaderItem(item)
          projectName = item.projectName
          actualObject[projectName] = {}
        when isFileHeaderItem(item)
          actualObject[projectName][relativizedFilePath(item)] = []
        else
          itemText = @ui.getTextForItem(item)
          actualObject[projectName][relativizedFilePath(item)].push(itemText)

    expect(actualObject).toEqual(object)

  ensureCursor: (cursor) ->
    expect(@editor.getCursorBufferPosition()).toEqual(cursor)

  ensureColumnForSelectedItem: (column) ->
    cursorPosition = @editor.getCursorBufferPosition()
    expect(@items.getRowForSelectedItem()).toBe(cursorPosition.row)
    expect(cursorPosition.column).toBe(column)

  ensureClassListContains: (classList) ->
    for className in classList
      expect(@editorElement.classList.contains(className)).toBe(true)

  ensureFilePathForProviderPane: (filePath) ->
    result = @provider.getPane().getActiveItem().getPath()
    expect(result).toBe(filePath)

# example-usage
# ensurePaneLayout
#   horizontal: [
#     [e1]
#     vertical: [[e4], [e2, e3]]
#   ]
ensurePaneLayout = (layout) ->
  root = atom.workspace.getActivePane().getContainer().getRoot()
  expect(paneLayoutFor(root)).toEqual(layout)

paneLayoutFor = (root) ->
  switch root.constructor.name
    when "Pane"
      root.getItems()
    when "PaneAxis"
      layout = {}
      layout[root.getOrientation()] = root.getChildren().map(paneLayoutFor)
      layout

paneForItem = (item) ->
  atom.workspace.paneForItem(item)

setActiveTextEditor = (editor) ->
  pane = paneForItem(editor)
  pane.activate()
  pane.activateItem(editor)

setActiveTextEditorWithWaits = (editor) ->
  runs ->
    disposable = atom.workspace.onDidStopChangingActivePaneItem (item) ->
      # This guard is necessary(only in spec), to ignore `undefined` item are passed.
      if item is editor
        disposable.dispose()
    setActiveTextEditor(editor)
    waitsFor -> disposable.disposed

module.exports = {
  startNarrow
  dispatchCommand
  ensureCursorPosition
  ensureEditor
  ensurePaneLayout
  ensureEditorIsActive
  dispatchEditorCommand
  paneForItem
  setActiveTextEditor
  setActiveTextEditorWithWaits
  getNarrowForUi
  reopen
}
