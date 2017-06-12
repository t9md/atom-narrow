const _ = require("underscore-plus")
const {inspect} = require("util")
const Ui = require("../lib/ui")
const ProviderBase = require("../lib/provider/provider-base")

function startNarrow(providerName, options) {
  return ProviderBase.start(providerName, options).then(getNarrowForUi)
}

function reopen() {
  return ProviderBase.reopen()
}

function getNarrowForUi(ui) {
  const {provider} = ui
  const props = {provider, ui}
  const ensureer = new Ensureer(ui, provider)
  const propNames = [
    "ensure",
    "waitsForRefresh",
    "waitsForConfirm",
    "waitsForDestroy",
    "waitsForPreview",
  ]
  for (let propName of propNames) {
    props[propName] = ensureer[propName]
  }
  return props
}

function dispatchCommand(target, commandName) {
  atom.commands.dispatch(target, commandName)
}

function dispatchEditorCommand(commandName, editor = null) {
  if (!editor) editor = atom.workspace.getActiveTextEditor()
  atom.commands.dispatch(editor.element, commandName)
}

function ensureCursorPosition(editor, position) {
  expect(editor.getCursorBufferPosition()).toEqual(position)
}

function validateOptions(options, validOptions, message) {
  const invalidOptions = _.without(_.keys(options), ...validOptions)
  if (invalidOptions.length) {
    throw new Error(`${message}: ${inspect(invalidOptions)}`)
  }
}

function ensureEditor(editor, options) {
  let value
  const ensureEditorOptionsOrdered = ["cursor", "text", "active", "alive"]
  validateOptions(
    options,
    ensureEditorOptionsOrdered,
    "invalid options ensureEditor"
  )
  for (const name of ensureEditorOptionsOrdered) {
    const value = options[name]
    if (value == null) continue

    if (name === "cursor") {
      expect(editor.getCursorBufferPosition()).toEqual(value)
    } else if (name === "active") {
      expect(atom.workspace.getActiveTextEditor() === editor).toBe(value)
    } else if (name === "alive") {
      expect(editor.isAlive()).toBe(value)
    }
  }
}

function ensureEditorIsActive(editor) {
  expect(atom.workspace.getActiveTextEditor()).toBe(editor)
}

function isProjectHeaderItem(item) {
  item.header && item.projectName && !item.filePath
}

function isFileHeaderItem(item) {
  item.header && item.filePath
}

const ensureOptionsOrdered = [
  "itemsCount",
  "selectedItemRow",
  "selectedItemText",
  "text",
  "cursor",
  "classListContains",
  "filePathForProviderPane",
  "query",
  "searchItems",
  "columnForSelectedItem",
]
// var Ensureer = (function() {
// let ensureOptionsOrdered = undefined
class Ensureer {
  constructor(ui, provider) {
    this.waitsForDestroy = this.waitsForDestroy.bind(this)
    this.waitsForRefresh = this.waitsForRefresh.bind(this)
    this.waitsForConfirm = this.waitsForConfirm.bind(this)
    this.waitsForPreview = this.waitsForPreview.bind(this)
    this.ensure = this.ensure.bind(this)

    this.ui = ui
    this.provider = provider
    this.editor = this.ui.editor
    this.items = this.ui.items
    this.editorElement = this.ui.editorElement
  }

  waitsForDestroy(fn) {
    const disposable = this.ui.onDidDestroy(() => disposable.dispose())
    fn()
    waitsFor(() => disposable.disposed)
  }

  waitsForRefresh(fn) {
    const disposable = this.ui.onDidRefresh(() => disposable.dispose())
    fn()
    waitsFor(() => disposable.disposed)
  }

  waitsForConfirm(fn) {
    const disposable = this.ui.onDidConfirm(() => disposable.dispose())
    fn()
    waitsFor(() => disposable.disposed)
  }

  waitsForPreview(fn) {
    const disposable = this.ui.onDidPreview(() => disposable.dispose())
    fn()
    waitsFor(() => disposable.disposed)
  }

  ensure(...args) {
    let options, query
    if (args.length === 1) {
      ;[options] = args
    } else if (args.length === 2) {
      ;[query, options] = args
    }

    validateOptions(options, ensureOptionsOrdered, "Invalid ensure option")

    const ensureOptions = () => {
      for (let name of ensureOptionsOrdered) {
        if (options[name] != null) {
          const method = `ensure${_.capitalize(_.camelize(name))}`
          this[method](options[name])
        }
      }
    }

    if (query) {
      runs(() => {
        this.waitsForRefresh(() => {
          this.ui.setQuery(query)
          if (this.ui.autoPreviewOnQueryChange) advanceClock(200)
          this.ui.moveToPrompt()
        })
      })
      runs(() => ensureOptions())
    } else {
      ensureOptions()
    }
  }

  ensureItemsCount(count) {
    expect(this.items.getCount()).toBe(count)
  }

  ensureSelectedItemRow(row) {
    expect(this.items.getRowForSelectedItem()).toBe(row)
  }

  ensureSelectedItemText(text) {
    expect(this.items.getSelectedItem().text).toBe(text)
  }

  ensureText(text) {
    expect(this.editor.getText()).toBe(text)
  }

  ensureQuery(text) {
    expect(this.ui.getQuery()).toBe(text)
  }

  ensureSearchItems(object) {
    const relativizedFilePath = item => atom.project.relativize(item.filePath)

    const actualObject = {}
    let projectName = null
    for (let item of this.ui.items.items.slice(1)) {
      if (isProjectHeaderItem(item)) {
        projectName = item.projectName
        actualObject[projectName] = {}
      } else if (isFileHeaderItem(item)) {
        actualObject[projectName][relativizedFilePath(item)] = []
      } else {
        const itemText = this.ui.getTextForItem(item)
        actualObject[projectName][relativizedFilePath(item)].push(itemText)
      }
    }

    expect(actualObject).toEqual(object)
  }

  ensureCursor(cursor) {
    expect(this.editor.getCursorBufferPosition()).toEqual(cursor)
  }

  ensureColumnForSelectedItem(column) {
    const cursorPosition = this.editor.getCursorBufferPosition()
    expect(this.items.getRowForSelectedItem()).toBe(cursorPosition.row)
    expect(cursorPosition.column).toBe(column)
  }

  ensureClassListContains(classList) {
    for (const className of classList) {
      expect(this.editorElement.classList.contains(className)).toBe(true)
    }
  }

  ensureFilePathForProviderPane(filePath) {
    const result = this.provider.getPane().getActiveItem().getPath()
    expect(result).toBe(filePath)
  }
}

// example-usage
// ensurePaneLayout
//   horizontal: [
//     [e1]
//     vertical: [[e4], [e2, e3]]
//   ]
function ensurePaneLayout(layout) {
  const root = atom.workspace.getActivePane().getContainer().getRoot()
  expect(paneLayoutFor(root)).toEqual(layout)
}

function paneLayoutFor(root) {
  const name = root.constructor.name
  switch (root.constructor.name) {
    case "Pane":
      return root.getItems()
    case "PaneAxis":
      const layout = {}
      layout[root.getOrientation()] = root.getChildren().map(paneLayoutFor)
      return layout
  }
}

function paneForItem(item) {
  return atom.workspace.paneForItem(item)
}

function setActiveTextEditor(editor) {
  const pane = paneForItem(editor)
  pane.activate()
  pane.activateItem(editor)
}

function setActiveTextEditorWithWaits(editor) {
  runs(() => {
    let disposable
    disposable = atom.workspace.onDidStopChangingActivePaneItem(item => {
      // This guard is necessary(only in spec), to ignore `undefined` item are passed.
      if (item === editor) disposable.dispose()
    })
    setActiveTextEditor(editor)
    waitsFor(() => disposable.disposed)
  })
}

module.exports = {
  startNarrow,
  dispatchCommand,
  ensureCursorPosition,
  ensureEditor,
  ensurePaneLayout,
  ensureEditorIsActive,
  dispatchEditorCommand,
  paneForItem,
  setActiveTextEditor,
  setActiveTextEditorWithWaits,
  getNarrowForUi,
  reopen,
}
