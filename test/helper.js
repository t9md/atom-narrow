const _ = require('underscore-plus')
const {inspect} = require('util')

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

function getActiveEditor () {
  const item = atom.workspace
    .getActivePaneContainer()
    .getActivePane()
    .getActiveItem()
  if (atom.workspace.isTextEditor(item)) {
    return item
  }
}

function validateOptions (options, validOptions, message) {
  const invalidOptions = _.without(_.keys(options), ...validOptions)
  if (invalidOptions.length) {
    throw new Error(`${message}: ${inspect(invalidOptions)}`)
  }
}

const ensureOptionsOrdered = [
  'itemsCount',
  'selectedItemRow',
  'selectedItemText',
  'text',
  'itemTextSet',
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
      options = args[0]
    } else if (args.length === 2) {
      query = args[0]
      options = args[1]
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
      this.ui.setQuery(query)
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

  ensureItemTextSet (expected) {
    const items = this.ui.items.items.slice(1) // skip query
    const actual = new Set(items.map(item => item.text))
    assert(equalSet(actual, expected))
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

  ensureSearchItems (expected) {
    const relativizedFilePath = item => atom.project.relativize(item.filePath)

    const actual = {}
    let projectName = null
    const items = this.ui.items.items.slice(1) // skip query
    for (const item of items) {
      if (item.headerType === 'project') {
        projectName = item.projectName
        actual[projectName] = {}
      } else if (item.headerType === 'file') {
        actual[projectName][relativizedFilePath(item)] = []
      } else {
        const itemText = this.ui.narrowEditor.getTextForItem(item)
        actual[projectName][relativizedFilePath(item)].push(itemText)
      }
    }

    assert.deepEqual(actual, expected)
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

function activateItem (item) {
  const pane = atom.workspace.paneForItem(item)
  pane.activate()
  pane.activateItem(item)
}

function setActiveTextEditorWithWaits (editor) {
  activateItem(editor)
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

function equalSet (setA, setB) {
  if (setA.size !== setB.size) return false

  for (const item of setA) {
    if (!setB.has(item)) return false
  }
  return true
}

module.exports = {
  ensurePaneLayout,
  getActiveEditor,
  activateItem,
  setActiveTextEditorWithWaits,
  getNarrowForProvider,
  unindent
}
