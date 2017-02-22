_ = require 'underscore-plus'

narrow = (providerName, options) ->
  klass = require("../lib/provider/#{providerName}")
  editor = atom.workspace.getActiveTextEditor()
  new klass(editor, options)

startNarrow = (providerName, options) ->
  provider = narrow(providerName, options)
  # console.log provider
  provider.start().then ->
    ui = provider.ui

    {
      provider: provider
      ui: ui
      ensure: new Ensureer(ui, provider).ensure
    }

dispatchCommand = (target, commandName) ->
  atom.commands.dispatch(target, commandName)

ensureCursorPosition = (editor, position) ->
  expect(editor.getCursorBufferPosition()).toEqual(position)

validateOptions = (options, validOptions, message) ->
  invalidOptions = _.without(_.keys(options), validOptions...)
  if invalidOptions.length
    throw new Error("#{message}: #{inspect(invalidOptions)}")

ensureEditor = (editor, options) ->
  ensureOptionsOrdered = [
    'cursor', 'text', 'active', 'alive'
  ]
  validateOptions(options, ensureOptionsOrdered, "invalid options ensureEditor")
  for name in ensureOptionsOrdered when (value = options[name])?
    switch name
      when 'cursor'
        expect(editor.getCursorBufferPosition()).toEqual(value)
      when 'active'
        expect(atom.workspace.getActiveTextEditor() is editor).toBe(value)
      when 'alive'
        expect(editor.isAlive()).toBe(value)

class Ensureer
  constructor: (@ui, @provider) ->
    {@editor, @items, @editorElement} = @ui

  ensureOptionsOrdered = [
    'itemsCount', 'selectedItemRow',
    'text', 'cursor',
  ]

  ensure: (args...) =>
    switch args.length
      when 1 then [options] = args
      when 2 then [query, options] = args

    validateOptions(options, ensureOptionsOrdered, 'Invalid ensure option')

    runs =>
      if query?
        refreshed = false
        @ui.onDidRefresh -> refreshed = true
        @ui.setQuery(query)
        waitsFor -> refreshed

      runs =>
        for name in ensureOptionsOrdered when options[name]?
          method = 'ensure' + _.capitalize(_.camelize(name))
          this[method](options[name])

  ensureItemsCount: (count) ->
    expect(@items.getCount()).toBe(count)

  ensureSelectedItemRow: (row) ->
    expect(@items.getRowForSelectedItem()).toBe(row)

  ensureText: (text) ->
    expect(@editor.getText()).toBe(text)

  ensureCursor: (cursor) ->
    expect(@editor.getCursorBufferPosition()).toEqual(cursor)

module.exports = {
  startNarrow
  dispatchCommand
  ensureCursorPosition
  ensureEditor
}
