const _ = require('underscore-plus')
const {inspect} = require('util')
const Provider = require('../lib/provider/provider')
const sinon = require('sinon')

function reopen () {
  return Provider.reopen()
}

function getNarrowForProvider (provider) {
  const ui = provider.ui
  return {
    ui: ui,
    provider: provider,
    ensure: new Ensureer(ui, provider).ensure,
    promiseForUiEvent (eventName) {
      return emitterEventPromise(ui.emitter, eventName)
    }
  }
}

function dispatchCommand (target, commandName) {
  atom.commands.dispatch(target, commandName)
}

function getActiveEditor () {
  const item = atom.workspace
    .getActivePaneContainer()
    .getActivePane()
    .getActiveItem()
  if (atom.workspace.isTextEditor(item)) {
    return item
  }
}

function dispatchEditorCommand (commandName, editor = getActiveEditor()) {
  if (!editor) {
    throw new Error('dispatchCommand could not find editor to dispatch command: `commandName`')
  }
  atom.commands.dispatch(editor.element, commandName)
}

function validateOptions (options, validOptions, message) {
  const invalidOptions = _.without(_.keys(options), ...validOptions)
  if (invalidOptions.length) {
    throw new Error(`${message}: ${inspect(invalidOptions)}`)
  }
}

function ensureEditor (editor, options) {
  const ensureEditorOptionsOrdered = ['cursor', 'text', 'active', 'alive']
  validateOptions(options, ensureEditorOptionsOrdered, 'invalid options ensureEditor')
  for (const name of ensureEditorOptionsOrdered) {
    const value = options[name]
    if (value == null) continue

    if (name === 'cursor') {
      assert.equal(editor.getCursorBufferPosition().isEqual(value), true)
    } else if (name === 'active') {
      assert.equal(getActiveEditor() === editor, value)
    } else if (name === 'alive') {
      assert.equal(editor.isAlive(), value)
    }
  }
}

// function ensureEditorIsActive (editor) {
//   assert(getActiveEditor() === editor)
// }

function isProjectHeaderItem (item) {
  return item.header && item.projectName && !item.filePath
}

function isFileHeaderItem (item) {
  return item.header && item.filePath
}

const ensureOptionsOrdered = [
  'itemsCount',
  'selectedItemRow',
  'selectedItemText',
  'text',
  'textAndSelectedItemTextOneOf',
  'cursor',
  'classListContains',
  'filePathForProviderPane',
  'query',
  'searchItems',
  'columnForSelectedItem'
]
class Ensureer {
  constructor (ui, provider) {
    this.ensure = this.ensure.bind(this)

    this.ui = ui
    this.provider = provider
    this.editor = this.ui.editor
    this.items = this.ui.items
  }

  async ensure (...args) {
    let options, query
    if (args.length === 1) {
      ;[options] = args
    } else if (args.length === 2) {
      ;[query, options] = args
    }

    validateOptions(options, ensureOptionsOrdered, 'Invalid ensure option')

    const ensureOptions = () => {
      for (let name of ensureOptionsOrdered) {
        if (options[name] != null) {
          const method = `ensure${_.capitalize(_.camelize(name))}`
          this[method](options[name])
        }
      }
    }

    if (query) {
      // const clock = sinon.useFakeTimers()
      this.ui.setQuery(query)
      if (this.ui.autoPreviewOnQueryChange) {
        // await emitterEventPromise(this.ui.emitter, 'did-preview')
        // clock.tick(500)
        // clock.restore()
      }
      this.ui.moveToPrompt()
      await emitterEventPromise(this.ui.emitter, 'did-refresh')
    }
    ensureOptions()
  }

  ensureItemsCount (count) {
    assert(this.items.getNormalItemCount() === count)
  }

  ensureSelectedItemRow (row) {
    assert(this.items.getSelectedItem()._row === row)
  }

  ensureSelectedItemText (text) {
    assert(
      this.items.getSelectedItem().text === text,
      `Was ${this.items.getSelectedItem().text} where it should ${text}`
    )
  }

  ensureText (text) {
    assert(this.editor.getText() === text)
  }

  ensureTextAndSelectedItemTextOneOf (textAndSelectedItemText) {
    let ok = 0
    textAndSelectedItemText.forEach(({text, selectedItemText}) => {
      if (this.editor.getText() === text && this.items.getSelectedItem().text === selectedItemText) {
        ok++
      }
    })
    assert(ok === 1)
  }

  ensureQuery (text) {
    assert(this.ui.getQuery() === text)
  }

  ensureSearchItems (object) {
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
        const itemText = this.ui.narrowEditor.getTextForItem(item)
        actualObject[projectName][relativizedFilePath(item)].push(itemText)
      }
    }

    assert.deepEqual(actualObject, object)
  }

  ensureCursor (cursor) {
    assert(this.editor.getCursorBufferPosition().isEqual(cursor))
  }

  ensureColumnForSelectedItem (column) {
    const cursorPosition = this.editor.getCursorBufferPosition()
    assert(this.items.getSelectedItem()._row === cursorPosition.row)
    assert(cursorPosition.column === column)
  }

  ensureClassListContains (classList) {
    for (const className of classList) {
      assert(this.editor.element.classList.contains(className))
    }
  }

  ensureFilePathForProviderPane (filePath) {
    const result = this.provider
      .getPane()
      .getActiveItem()
      .getPath()
    assert(result === filePath)
  }
}

// example-usage
// ensurePaneLayout
//   horizontal: [
//     [e1]
//     vertical: [[e4], [e2, e3]]
//   ]
function ensurePaneLayout (layout) {
  const root = atom.workspace
    .getActivePane()
    .getContainer()
    .getRoot()
  assert.deepEqual(paneLayoutFor(root), layout)
}

function paneLayoutFor (root) {
  switch (root.constructor.name) {
    case 'Pane':
      return root.getItems()
    case 'PaneAxis':
      const layout = {}
      layout[root.getOrientation()] = root.getChildren().map(paneLayoutFor)
      return layout
  }
}

function paneForItem (item) {
  return atom.workspace.paneForItem(item)
}

function setActiveTextEditor (editor) {
  const pane = paneForItem(editor)
  pane.activate()
  pane.activateItem(editor)
}

function setActiveTextEditorWithWaits (editor) {
  setActiveTextEditor(editor)
  let done
  const promise = new Promise(resolve => {
    done = resolve
  })
  const disposable = atom.workspace.onDidStopChangingActivePaneItem(item => {
    // This guard is necessary(only in spec), to ignore `undefined` item are passed.
    if (item === editor) {
      disposable.dispose()
      done()
    }
  })
  return promise
}

function unindent (strings, ...values) {
  let result = ''
  for (let rawString of strings.raw) {
    result += rawString.replace(/\\{2}/g, '\\') + (values.length ? values.shift() : '')
  }

  const lines = result.split(/\n/)
  lines.shift()
  lines.pop()

  const minIndent = lines.reduce((minIndent, line) => {
    return !line.match(/\S/) ? minIndent : Math.min(line.match(/ */)[0].length, minIndent)
  }, Infinity)
  return lines.map(line => line.slice(minIndent)).join('\n')
}

function emitterEventPromise (emitter, event, timeout = 15000) {
  return new Promise((resolve, reject) => {
    const timeoutHandle = setTimeout(() => {
      reject(new Error(`Timed out waiting for '${event}' event`))
    }, timeout)
    emitter.once(event, () => {
      clearTimeout(timeoutHandle)
      resolve()
    })
  })
}

module.exports = {
  dispatchCommand,
  ensureEditor,
  ensurePaneLayout,
  // ensureEditorIsActive,
  dispatchEditorCommand,
  getActiveEditor,
  paneForItem,
  setActiveTextEditor,
  setActiveTextEditorWithWaits,
  getNarrowForProvider,
  reopen,
  unindent,
  emitterEventPromise
}
