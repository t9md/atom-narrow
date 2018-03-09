const Ui = require('../lib/ui')
const Path = require('path')
const settings = require('../lib/settings')
const Provider = require('../lib/provider/provider')

const {
  getNarrowForProvider,
  ensurePaneLayout,
  getActiveEditor,
  setActiveTextEditorWithWaits,
  unindent
} = require('./helper')
const $ = unindent

const dispatchActiveEditor = name => {
  atom.commands.dispatch(getActiveEditor().element, name)
}

const FIXTURES_DIR = Path.join(__dirname, 'fixtures')

const APPLE_GRAPE_LEMMON_TEXT = $`
  apple
  grape
  lemmon
  `

// Main
// -------------------------
describe('narrow', () => {
  let editor, service, workspaceElement
  function startNarrow (name, options) {
    return service.narrow(name, options).then(getNarrowForProvider)
  }

  beforeEach(async () => {
    // workaround BUG in 1.25.0-beta2
    atom.config.resetUserSettings({})

    workspaceElement = atom.workspace.getElement()
    document.body.appendChild(workspaceElement)
    document.body.focus()

    editor = await atom.workspace.open()

    const activationPromise = atom.packages.activatePackage('narrow')
    atom.commands.dispatch(workspaceElement, 'narrow:activate-package')
    const pkg = await activationPromise
    service = pkg.mainModule.provideNarrow()
  })

  afterEach(() => {
    atom.workspace.getTextEditors().forEach(editor => editor.destroy())
    workspaceElement.remove()
    Ui.reset()
    Ui.forEach(ui => ui.destroy())
  })

  describe('confirm family', () => {
    let narrow
    beforeEach(async () => {
      editor.setText(APPLE_GRAPE_LEMMON_TEXT)
      editor.setCursorBufferPosition([0, 0])
      narrow = await startNarrow('scan')
      await narrow.ensure('l', {
        text: $`
          l
          apple
          lemmon
          `,
        selectedItemRow: 1
      })
    })

    describe('closeOnConfirm settings', () => {
      it('land to confirmed item and close narrow-editor', async () => {
        settings.set('Scan.closeOnConfirm', true)
        dispatchActiveEditor('core:confirm')
        await narrow.promiseForUiEvent('did-destroy')
        assert(editor.getCursorBufferPosition().isEqual([0, 3]))
        assert(!narrow.ui.isAlive())
        assert(Ui.getSize() === 0)
      })

      it('land to confirmed item and keep open narrow-editor', async () => {
        settings.set('Scan.closeOnConfirm', false)
        dispatchActiveEditor('core:confirm')
        await narrow.promiseForUiEvent('did-confirm')
        assert(editor.getCursorBufferPosition().isEqual([0, 3]))
        assert(narrow.ui.isAlive())
        assert(Ui.getSize() === 1)
      })
    })

    describe('confirm-keep-open command', () => {
      it('land to confirmed item and keep open narrow-editor even if closeOnConfirm was true', async () => {
        settings.set('Scan.closeOnConfirm', true)
        dispatchActiveEditor('narrow-ui:confirm-keep-open')
        await narrow.promiseForUiEvent('did-confirm')
        assert(editor.getCursorBufferPosition().isEqual([0, 3]))
        assert(narrow.ui.isAlive())
        assert(Ui.getSize() === 1)
      })
    })
  })

  describe('narrow-editor open/close', () => {
    function getBottomDockActiveItem () {
      return atom.workspace.getBottomDock().getActivePaneItem()
    }

    beforeEach(() => {
      editor.setText(APPLE_GRAPE_LEMMON_TEXT)
      editor.setCursorBufferPosition([0, 0])
    })

    describe('[bottom] open/close in bottom dock', () => {
      it('open narow-editor at dock and can close by `core:close`', async () => {
        const narrow = await startNarrow('scan')
        const dockActiveItem = getBottomDockActiveItem()
        assert(dockActiveItem === narrow.ui.editor)
        const destroyPromise = narrow.promiseForUiEvent('did-destroy')
        atom.commands.dispatch(dockActiveItem.element, 'core:close')
        await destroyPromise
        assert(!narrow.ui.isAlive())
        assert(getBottomDockActiveItem() === undefined)
      })
    })

    describe('[bottom/center] narrow-ui:relocate command', () => {
      it('open narow-editor at dock and can close by `core:close`', async () => {
        const narrow = await startNarrow('scan')

        assert(narrow.ui.narrowEditor.getLocation() === 'bottom')
        assert(narrow.ui.editor.element.hasFocus())

        dispatchActiveEditor('narrow-ui:relocate')
        assert(narrow.ui.narrowEditor.getLocation() === 'center')
        assert(narrow.ui.editor.element.hasFocus())
        assert(getBottomDockActiveItem() === undefined)

        dispatchActiveEditor('narrow-ui:relocate')
        assert(narrow.ui.narrowEditor.getLocation() === 'bottom')
        assert(narrow.ui.editor.element.hasFocus())

        dispatchActiveEditor('narrow-ui:relocate')
        assert(narrow.ui.narrowEditor.getLocation() === 'center')
        assert(narrow.ui.editor.element.hasFocus())
        assert(getBottomDockActiveItem() === undefined)
      })
    })
    describe('[center location] split settings', () => {
      beforeEach(() => {
        atom.config.set('narrow.locationToOpen', 'center')
      })
      describe('from one pane', () => {
        beforeEach(() => {
          ensurePaneLayout([editor])
        })

        it('open on right pane', async () => {
          settings.set('split', 'right')
          const narrow = await startNarrow('scan')
          ensurePaneLayout({horizontal: [[editor], [narrow.ui.editor]]})
        })

        it('open on down pane', async () => {
          settings.set('split', 'down')
          const narrow = await startNarrow('scan')
          ensurePaneLayout({vertical: [[editor], [narrow.ui.editor]]})
        })
      })

      describe('from two pane', () => {
        beforeEach(() => {
          settings.set('split', 'right')
        })

        describe('horizontal split', () => {
          let editor2
          beforeEach(async () => {
            editor2 = await atom.workspace.open(null, {split: 'right'})
            ensurePaneLayout({horizontal: [[editor], [editor2]]})
          })

          describe('initially left-pane active', () => {
            it('open on existing right pane', async () => {
              atom.workspace.paneForItem(editor).activate()
              assert(editor.element.hasFocus())
              const narrow = await startNarrow('scan')
              ensurePaneLayout({horizontal: [[editor], [editor2, narrow.ui.editor]]})
            })
          })

          describe('initially right-pane active', () => {
            it('open on previous adjacent pane', async () => {
              assert(editor2.element.hasFocus())
              const narrow = await startNarrow('scan')
              ensurePaneLayout({horizontal: [[editor, narrow.ui.editor], [editor2]]})
            })
          })
        })

        describe('vertical split', () => {
          let editor2
          beforeEach(async () => {
            editor2 = await atom.workspace.open(null, {split: 'down'})
            ensurePaneLayout({vertical: [[editor], [editor2]]})
          })

          describe('initially up-pane active', () => {
            it('open on existing down pane', async () => {
              atom.workspace.paneForItem(editor).activate()
              assert(editor.element.hasFocus())
              const narrow = await startNarrow('scan')
              ensurePaneLayout({vertical: [[editor], [editor2, narrow.ui.editor]]})
            })
          })

          describe('initially down-pane active', () => {
            it('open on previous adjacent pane', async () => {
              assert(editor2.element.hasFocus())
              const narrow = await startNarrow('scan')
              ensurePaneLayout({vertical: [[editor, narrow.ui.editor], [editor2]]})
            })
          })
        })
      })
    })
  })

  describe('narrow:focus', () => {
    beforeEach(() => {
      editor.setText(APPLE_GRAPE_LEMMON_TEXT)
      editor.setCursorBufferPosition([0, 0])
    })

    it('toggle focus between provider.editor and ui.editor', async () => {
      const {ui, provider} = await startNarrow('scan')
      assert(ui.editor.element.hasFocus())
      dispatchActiveEditor('narrow:focus')
      assert(provider.editor.element.hasFocus())
      dispatchActiveEditor('narrow:focus')
      assert(ui.editor.element.hasFocus())
      dispatchActiveEditor('narrow:focus')
      assert(provider.editor.element.hasFocus())
    })
  })

  describe('narrow:focus-prompt', () => {
    beforeEach(() => {
      editor.setText(APPLE_GRAPE_LEMMON_TEXT)
      editor.setCursorBufferPosition([0, 0])
    })

    it('toggle focus between provider.editor and ui.editor', async () => {
      const {ensure, ui, provider} = await startNarrow('scan')
      ui.editor.setCursorBufferPosition([1, 0])

      assert(ui.editor.element.hasFocus())
      await ensure({cursor: [1, 0], selectedItemRow: 1})

      dispatchActiveEditor('narrow:focus-prompt')
      assert(ui.editor.element.hasFocus())
      await ensure({cursor: [0, 0], selectedItemRow: 1})

      // focus provider.editor
      dispatchActiveEditor('narrow:focus-prompt')
      assert(provider.editor.element.hasFocus())
      await ensure({cursor: [0, 0], selectedItemRow: 1})

      // focus narrow-editor
      dispatchActiveEditor('narrow:focus-prompt')
      assert(ui.editor.element.hasFocus())
      await ensure({cursor: [0, 0], selectedItemRow: 1})
    })
  })

  describe('narrow:close', () => {
    beforeEach(() => {
      editor.setText(APPLE_GRAPE_LEMMON_TEXT)
      editor.setCursorBufferPosition([0, 0])
    })

    it('close narrow-editor without focusing', async () => {
      await startNarrow('scan')
      assert(atom.workspace.getTextEditors().length === 2)
      editor.element.focus()

      assert(editor.element.hasFocus())
      dispatchActiveEditor('narrow:close')
      assert(editor.element.hasFocus())
      assert(atom.workspace.getTextEditors().length === 1)
    })

    it('close existing ui one by one', async () => {
      await startNarrow('scan')
      await startNarrow('scan')
      await startNarrow('scan')
      await startNarrow('scan')

      assert(Ui.getSize() === 4)
      editor.element.focus()
      assert(editor.element.hasFocus())

      dispatchActiveEditor('narrow:close')
      assert(Ui.getSize() === 3)
      dispatchActiveEditor('narrow:close')
      assert(Ui.getSize() === 2)
      dispatchActiveEditor('narrow:close')
      assert(Ui.getSize() === 1)
      dispatchActiveEditor('narrow:close')
      assert(Ui.getSize() === 0)
      dispatchActiveEditor('narrow:close')
      assert(Ui.getSize() === 0)
    })
  })

  describe('narrow:refresh', () => {
    beforeEach(() => {
      editor.setText(APPLE_GRAPE_LEMMON_TEXT)
      editor.setCursorBufferPosition([0, 0])
    })

    it('redraw items when item area was mutated', async () => {
      const narrow = await startNarrow('scan')
      const originalText = narrow.ui.editor.getText()

      const eof = narrow.ui.editor.getEofBufferPosition()
      narrow.ui.editor.setTextInBufferRange([[1, 0], eof], 'abc\ndef\n')
      await narrow.ensure({text: '\nabc\ndef\n'})

      dispatchActiveEditor('narrow:refresh')
      await narrow.promiseForUiEvent('did-refresh')
      await narrow.ensure({text: originalText})
    })
  })

  describe('reopen', () => {
    // prettier-ignore
    it('reopen closed narrow editor up to 10 recent', async () => {
      const ensureText = text => assert(getActiveEditor().getText() === text)
      const narrows = []

      editor.setText('1\n2\n3\n4\n5\n6\n7\n8\n9\na\nb')
      editor.setCursorBufferPosition([0, 0])
      for (let i = 0; i <= 10; i++) {
        narrows.push(await startNarrow('scan'))
      }

      assert(Ui.getSize() === 11)
      await narrows[0].ensure('1', {text: '1\n1'})
      await narrows[1].ensure('2', {text: '2\n2'})
      await narrows[2].ensure('3', {text: '3\n3'})
      await narrows[3].ensure('4', {text: '4\n4'})
      await narrows[4].ensure('5', {text: '5\n5'})
      await narrows[5].ensure('6', {text: '6\n6'})
      await narrows[6].ensure('7', {text: '7\n7'})
      await narrows[7].ensure('8', {text: '8\n8'})
      await narrows[8].ensure('9', {text: '9\n9'})
      await narrows[9].ensure('a', {text: 'a\na'})
      await narrows[10].ensure('b', {text: 'b\nb'})
      Ui.forEach(ui => ui.destroy())
      assert(Ui.getSize() === 0)
      await Provider.reopen(); ensureText('b\nb'); assert(Ui.getSize() === 1)
      await Provider.reopen(); ensureText('a\na'); assert(Ui.getSize() === 2)
      await Provider.reopen(); ensureText('9\n9'); assert(Ui.getSize() === 3)
      await Provider.reopen(); ensureText('8\n8'); assert(Ui.getSize() === 4)
      await Provider.reopen(); ensureText('7\n7'); assert(Ui.getSize() === 5)
      await Provider.reopen(); ensureText('6\n6'); assert(Ui.getSize() === 6)
      await Provider.reopen(); ensureText('5\n5'); assert(Ui.getSize() === 7)
      await Provider.reopen(); ensureText('4\n4'); assert(Ui.getSize() === 8)
      await Provider.reopen(); ensureText('3\n3'); assert(Ui.getSize() === 9)
      await Provider.reopen(); ensureText('2\n2'); assert(Ui.getSize() === 10)

      assert(!Provider.reopen())
      assert(Ui.getSize() === 10)
    })
  })

  describe('narrow:next-item, narrow:previous-item', () => {
    describe('basic behavior', () => {
      beforeEach(() => {
        editor.setText(APPLE_GRAPE_LEMMON_TEXT)
        editor.setCursorBufferPosition([0, 0])
      })

      it('move to next/previous item with wrap', async () => {
        const narrow = await startNarrow('scan')
        await narrow.ensure('p', {
          text: $`
            p
            apple
            apple
            grape
            `
        })

        editor.element.focus()
        assert(editor.element.hasFocus())
        assert(editor.getCursorBufferPosition().isEqual([0, 0]))

        const ensureConfirmedPoint = async (command, point) => {
          dispatchActiveEditor(command)
          await narrow.promiseForUiEvent('did-confirm')
          assert(editor.getCursorBufferPosition().isEqual(point))
        }

        await ensureConfirmedPoint('narrow:next-item', [0, 1])
        await ensureConfirmedPoint('narrow:next-item', [0, 2])

        await ensureConfirmedPoint('narrow:next-item', [1, 3])
        await ensureConfirmedPoint('narrow:next-item', [0, 1])

        await ensureConfirmedPoint('narrow:previous-item', [1, 3])
        await ensureConfirmedPoint('narrow:previous-item', [0, 2])
        await ensureConfirmedPoint('narrow:previous-item', [0, 1])
      })
    })

    describe('when cursor position is contained in item.range', () => {
      let narrow
      beforeEach(async () => {
        editor.setText($`
          line 1
            line 2
          line 3
            line 4
          `)
        editor.setCursorBufferPosition([0, 0])
        narrow = await startNarrow('scan')
        await narrow.ensure('line', {
          text: $`
            line
            line 1
              line 2
            line 3
              line 4
            `
        })
      })

      it('move to next/previous', async () => {
        await setActiveTextEditorWithWaits(editor)

        const r1 = [[0, 0], [0, 3]] // `line` range of "line 1"
        const r2 = [[1, 2], [1, 6]] // `line` range of "  line 2"
        const r3 = [[2, 0], [2, 3]] // `line` range of "line 3"
        const r4 = [[3, 2], [3, 6]] // `line` range of "  line 4"

        const ensureCommand = async (command, start, last) => {
          editor.setCursorBufferPosition(start)
          dispatchActiveEditor(command)
          await narrow.promiseForUiEvent('did-confirm')
          assert(editor.getCursorBufferPosition().isEqual(last))
        }

        await ensureCommand('narrow:next-item', r1[0], [1, 2])
        await ensureCommand('narrow:next-item', r1[1], [1, 2])
        await ensureCommand('narrow:previous-item', r1[0], [3, 2])
        await ensureCommand('narrow:previous-item', r1[1], [3, 2])
        await ensureCommand('narrow:next-item', r2[0], [2, 0])
        await ensureCommand('narrow:next-item', r2[1], [2, 0])
        await ensureCommand('narrow:previous-item', r2[0], [0, 0])
        await ensureCommand('narrow:previous-item', r2[1], [0, 0])
        await ensureCommand('narrow:next-item', r3[0], [3, 2])
        await ensureCommand('narrow:next-item', r3[1], [3, 2])
        await ensureCommand('narrow:previous-item', r3[0], [1, 2])
        await ensureCommand('narrow:previous-item', r3[1], [1, 2])
        await ensureCommand('narrow:next-item', r4[0], [0, 0])
        await ensureCommand('narrow:next-item', r4[1], [0, 0])
        await ensureCommand('narrow:previous-item', r4[0], [2, 0])
        await ensureCommand('narrow:previous-item', r4[1], [2, 0])
      })
    })
  })

  describe('auto reveal on start behavior( revealOnStartCondition )', () => {
    let points, pointsA

    const getEnsureStartState = startOptions => async (point, options) => {
      editor.setCursorBufferPosition(point)
      const narrow = await startNarrow('scan', startOptions)
      await narrow.ensure(options)
      narrow.ui.destroy()
    }

    beforeEach(() => {
      points = [
        [0, 0], // `line` start of "line 1"
        [1, 2], // `line` start of "  line 2"
        [2, 0], // `line` start of "line 3"
        [3, 2] // `line` start of "  line 4"
      ]
      // prettier-ignore
      pointsA = [
        [1, 0],
        [2, 2],
        [3, 0],
        [4, 2]
      ]

      editor.setText($`
        line 1
          line 2
        line 3
          line 4
        `)
      editor.setCursorBufferPosition([0, 0])
    })

    describe('revealOnStartCondition = on-input( default )', () => {
      beforeEach(() => {
        settings.set('Scan.revealOnStartCondition', 'on-input')
      })

      it('auto reveal when initial query was provided', async () => {
        const text = $`
          line
          line 1
            line 2
          line 3
            line 4
          `
        const ensureStartState = getEnsureStartState({queryCurrentWord: true})
        await ensureStartState(points[0], {cursor: pointsA[0], text, selectedItemText: 'line 1'})
        await ensureStartState(points[1], {cursor: pointsA[1], text, selectedItemText: '  line 2'})
        await ensureStartState(points[2], {cursor: pointsA[2], text, selectedItemText: 'line 3'})
        await ensureStartState(points[3], {cursor: pointsA[3], text, selectedItemText: '  line 4'})
      })

      it('NOT auto reveal when no query was provided', async () => {
        const text = $`

          line 1
            line 2
          line 3
            line 4
          `
        const ensureStartState = getEnsureStartState()
        const options = {selectedItemText: 'line 1', cursor: [0, 0], text}
        for (const point of points) {
          await ensureStartState(point, options)
        }
      })
    })

    describe('revealOnStartCondition = never', () => {
      beforeEach(() => {
        settings.set('Scan.revealOnStartCondition', 'never')
      })

      it('NOT auto reveal when initial query was provided', async () => {
        const text = $`
          line
          line 1
            line 2
          line 3
            line 4
          `
        const ensureStartState = getEnsureStartState({queryCurrentWord: true})
        const options = {selectedItemText: 'line 1', cursor: [0, 4], text}
        for (const point of points) {
          await ensureStartState(point, options)
        }
      })

      it('NOT auto reveal when no query was provided', async () => {
        const text = $`

          line 1
            line 2
          line 3
            line 4
          `
        const ensureStartState = getEnsureStartState()
        const options = {selectedItemText: 'line 1', cursor: [0, 0], text}
        for (const point of points) {
          await ensureStartState(point, options)
        }
      })
    })

    describe('revealOnStartCondition = always', () => {
      beforeEach(() => {
        settings.set('Scan.revealOnStartCondition', 'always')
      })

      it('auto reveal when initial query was provided', async () => {
        const text = $`
          line
          line 1
            line 2
          line 3
            line 4
          `
        const ensureStartState = getEnsureStartState({queryCurrentWord: true})
        await ensureStartState(points[0], {cursor: pointsA[0], text, selectedItemText: 'line 1'})
        await ensureStartState(points[1], {cursor: pointsA[1], text, selectedItemText: '  line 2'})
        await ensureStartState(points[2], {cursor: pointsA[2], text, selectedItemText: 'line 3'})
        await ensureStartState(points[3], {cursor: pointsA[3], text, selectedItemText: '  line 4'})
      })

      it('auto reveal when initial query was provided when multiple match on same line', async () => {
        const lineText = 'line line line line'
        editor.setText(lineText)

        const text = $`
          line
          line line line line
          line line line line
          line line line line
          line line line line
          `
        const ensureStartState = getEnsureStartState({queryCurrentWord: true})
        points = [[0, 0], [0, 5], [0, 10], [0, 15]]
        pointsA = [[1, 0], [2, 5], [3, 10], [4, 15]]

        const selectedItemText = lineText
        for (let i = 0; i < points.length; i++) {
          await ensureStartState(points[i], {cursor: pointsA[i], text, selectedItemText})
        }
      })

      it('auto reveal for based on current line of bound-editor', async () => {
        const text = $`

          line 1
            line 2
          line 3
            line 4
          `
        const ensureStartState = getEnsureStartState()
        await ensureStartState([0, 0], {cursor: [1, 0], text, selectedItemText: 'line 1'})
        await ensureStartState([1, 2], {cursor: [2, 0], text, selectedItemText: '  line 2'})
        await ensureStartState([2, 0], {cursor: [3, 0], text, selectedItemText: 'line 3'})
        await ensureStartState([3, 2], {cursor: [4, 0], text, selectedItemText: '  line 4'})
      })
    })
  })

  describe('narrow-editor auto-sync selected-item to active editor', () => {
    let narrow, editor2

    beforeEach(async () => {
      editor.setText($`
        line 1

        line 3

        line 5

        line 7

        line 9

        `)
      editor.setCursorBufferPosition([0, 0])

      editor2 = await atom.workspace.open()
      editor2.setText($`

        line 2

        line 4

        line 6

        line 8

        line 10
        `)
      editor2.setCursorBufferPosition([0, 0])

      assert(editor2.element.hasFocus())
      narrow = await startNarrow('scan')
      assert(narrow.ui.editor.element.hasFocus())
      assert(narrow.provider.editor === editor2)
      await narrow.ensure('line', {
        text: $`
          line
          line 2
          line 4
          line 6
          line 8
          line 10
          `
      })
    })

    describe('re-bound to active text-editor', () =>
      it('provider.editor is rebound to active text-editor and auto-refreshed', async () => {
        const {provider, ensure} = narrow

        await setActiveTextEditorWithWaits(editor)

        assert(editor.element.hasFocus())
        assert(provider.editor === editor)
        await ensure({
          text: $`
            line
            line 1
            line 3
            line 5
            line 7
            line 9
            `
        })
        const refreshPromise = narrow.promiseForUiEvent('did-refresh')
        await setActiveTextEditorWithWaits(editor2)
        await refreshPromise
        assert(provider.editor === editor2)
        await ensure({
          text: $`
            line
            line 2
            line 4
            line 6
            line 8
            line 10
            `
        })
      }))

    describe("auto-sync selected-item to acitive-editor's cursor position", () =>
      // prettier-ignore
      it('provider.editor is bound to active text-editor and auto-refreshed', async () => {
        const {provider, ensure} = narrow
        const setCursor = (editor, point) => editor.setCursorBufferPosition(point)

        await setActiveTextEditorWithWaits(editor)

        assert(editor.element.hasFocus())
        assert(provider.editor === editor)

        setCursor(editor, [0, 0]); await ensure({selectedItemText: 'line 1'})
        setCursor(editor, [1, 0]); await ensure({selectedItemText: 'line 1'})
        setCursor(editor, [2, 0]); await ensure({selectedItemText: 'line 3'})
        setCursor(editor, [3, 0]); await ensure({selectedItemText: 'line 3'})
        setCursor(editor, [4, 0]); await ensure({selectedItemText: 'line 5'})
        editor.moveToBottom()
        assert(editor.getCursorBufferPosition().isEqual([9, 0]))
        await ensure({selectedItemText: 'line 9'})

        await setActiveTextEditorWithWaits(editor2)

        assert(provider.editor === editor2)
        await ensure({selectedItemText: 'line 2'})
        setCursor(editor2, [1, 0]); await ensure({selectedItemText: 'line 2'})
        setCursor(editor2, [3, 0]); await ensure({selectedItemText: 'line 4'})
        setCursor(editor2, [5, 0]); await ensure({selectedItemText: 'line 6'})
        setCursor(editor2, [7, 0]); await ensure({selectedItemText: 'line 8'})

        editor2.moveToTop()
        assert(editor2.getCursorBufferPosition().isEqual([0, 0]))
        await ensure({selectedItemText: 'line 2'})
      }))
  })

  describe('scan', () => {
    describe('with empty query', () => {
      let narrow

      beforeEach(async () => {
        editor.setText(APPLE_GRAPE_LEMMON_TEXT)
        editor.setCursorBufferPosition([0, 0])
        narrow = await startNarrow('scan')
      })

      it('add css class to narrowEditorElement', async () => {
        await narrow.ensure({classListContains: ['narrow', 'narrow-editor', 'scan']})
      })

      it('initial state is whole buffer lines', async () => {
        await narrow.ensure({
          text: $`

            apple
            grape
            lemmon
            `
        })
      })

      it('can filter by query', async () => {
        await narrow.ensure('app', {
          text: $`
            app
            apple
            `,
          selectedItemRow: 1,
          itemsCount: 1
        })

        await narrow.ensure('r', {
          text: $`
            r
            grape
            `,
          selectedItemRow: 1,
          itemsCount: 1
        })

        await narrow.ensure('l', {
          text: $`
            l
            apple
            lemmon
            `,
          selectedItemRow: 1,
          itemsCount: 2
        })
      })

      it('land to confirmed item', async () => {
        await narrow.ensure('l', {
          text: $`
            l
            apple
            lemmon
            `,
          selectedItemRow: 1
        })

        dispatchActiveEditor('core:confirm')
        await narrow.promiseForUiEvent('did-destroy')
        assert(editor.getCursorBufferPosition().isEqual([0, 3]))
      })

      it('land to confirmed item', async () => {
        await narrow.ensure('mm', {
          text: $`
            mm
            lemmon
            `,
          selectedItemRow: 1
        })

        dispatchActiveEditor('core:confirm')
        await narrow.promiseForUiEvent('did-destroy')
        assert(editor.getCursorBufferPosition().isEqual([2, 2]))
      })
    })

    describe('with queryCurrentWord', () => {
      beforeEach(() => {
        editor.setText(APPLE_GRAPE_LEMMON_TEXT)
      })

      const ensureScan = async (point, option) => {
        editor.element.focus()
        editor.setCursorBufferPosition(point)
        const narrow = await startNarrow('scan', {queryCurrentWord: true})
        await narrow.ensure(option)
        narrow.ui.destroy()
      }

      it('set current-word as initial query', async () => {
        await ensureScan([0, 0], {text: 'apple\napple', selectedItemRow: 1, itemsCount: 1})
        await ensureScan([1, 0], {text: 'grape\ngrape', selectedItemRow: 1, itemsCount: 1})
        await ensureScan([2, 0], {text: 'lemmon\nlemmon', selectedItemRow: 1, itemsCount: 1})
      })
    })
  })

  describe('search', () => {
    beforeEach(() => {
      settings.set('projectHeaderTemplate', '# __HEADER__')
      settings.set('fileHeaderTemplate', '## __HEADER__')

      atom.project.removePath(FIXTURES_DIR)
      atom.project.addPath(Path.join(FIXTURES_DIR, 'project1'))
      atom.project.addPath(Path.join(FIXTURES_DIR, 'project2'))
    })

    describe('basic behavior', () => {
      let narrow
      const searchItemsWithQueryApple = {
        project1: {'p1-f1': ['p1-f1: apple'], 'p1-f2': ['p1-f2: apple']},
        project2: {'p2-f1': ['p2-f1: apple'], 'p2-f2': ['p2-f2: apple']}
      }
      const fileSetByMatch = {
        all: new Set(['project1/p1-f1', 'project1/p1-f2', 'project2/p2-f1', 'project2/p2-f2']),
        f1: new Set(['project1/p1-f1', 'project2/p2-f1']),
        f2: new Set(['project1/p1-f2', 'project2/p2-f2'])
      }

      beforeEach(async () => {
        narrow = await startNarrow('search', {query: 'apple'})
        await narrow.promiseForUiEvent('did-preview')
      })

      it('preview on cursor move with skipping header', async () => {
        const runPreviewCommand = command => {
          dispatchActiveEditor(command)
          return narrow.promiseForUiEvent('did-preview')
        }

        await narrow.ensure({
          query: 'apple',
          searchItems: searchItemsWithQueryApple,
          cursor: [3, 7],
          selectedItemRow: 3
        })

        const providerPane = narrow.provider.getPane()

        dispatchActiveEditor('core:move-up')
        await narrow.ensure({selectedItemRow: 3, cursor: [0, 5]})

        await runPreviewCommand('core:move-down')
        await narrow.ensure({selectedItemRow: 3, cursor: [3, 7]})
        assert(providerPane.getActiveItem().getPath() === narrow.ui.items.itemForRow(3).filePath)

        await runPreviewCommand('core:move-down')
        await narrow.ensure({selectedItemRow: 5, cursor: [5, 7]})
        assert(providerPane.getActiveItem().getPath() === narrow.ui.items.itemForRow(5).filePath)
        assert(narrow.ui.editor.element.hasFocus())

        await runPreviewCommand('core:move-down')
        await narrow.ensure({selectedItemRow: 8, cursor: [8, 7]})
        assert(providerPane.getActiveItem().getPath() === narrow.ui.items.itemForRow(8).filePath)

        await runPreviewCommand('core:move-down')
        await narrow.ensure({selectedItemRow: 10, cursor: [10, 7]})
        assert(providerPane.getActiveItem().getPath() === narrow.ui.items.itemForRow(10).filePath)
      })

      it('preview on query change by default( autoPreviewOnQueryChange )', async () => {
        narrow.ui.moveToPrompt()
        narrow.ui.editor.insertText(' f2')
        const providerPane = narrow.provider.getPane()
        await narrow.promiseForUiEvent('did-preview')
        await narrow.ensure({
          query: 'apple f2',
          searchItems: {
            project1: {'p1-f2': ['p1-f2: apple']},
            project2: {'p2-f2': ['p2-f2: apple']}
          },
          selectedItemRow: 3
        })
        assert(providerPane.getActiveItem().getPath() === narrow.ui.items.itemForRow(3).filePath)

        narrow.ui.editor.insertText(' p2')
        await narrow.promiseForUiEvent('did-preview')
        await narrow.ensure({
          query: 'apple f2 p2',
          searchItems: {
            project2: {'p2-f2': ['p2-f2: apple']}
          },
          selectedItemRow: 3
        })
        assert(providerPane.getActiveItem().getPath() === narrow.ui.items.itemForRow(3).filePath)
      })

      it('can filter files by select-files provider', async () => {
        await narrow.ensure({
          query: 'apple',
          searchItems: searchItemsWithQueryApple,
          cursor: [3, 7],
          selectedItemRow: 3
        })

        // Section0: Move to selected file.
        {
          const selectFiles = getNarrowForProvider(await narrow.ui.selectFiles())
          await selectFiles.ensure({
            query: '',
            itemTextSet: new Set(['project1/p1-f1', 'project1/p1-f2', 'project2/p2-f1', 'project2/p2-f2'])
          })

          assert(selectFiles.ui.editor.element.hasFocus())
          const promise = selectFiles.promiseForUiEvent('did-destroy')
          dispatchActiveEditor('core:move-down')
          dispatchActiveEditor('core:move-down') // Move to file "project1/p1-f2"
          dispatchActiveEditor('core:confirm')
          await promise

          // Ensure f1 matching files are excluded and not listed in narrow-editor.
          assert(narrow.ui.editor.element.hasFocus())
          assert.deepEqual(narrow.ui.excludedFiles, [])
          await narrow.ensure({
            searchItems: searchItemsWithQueryApple,
            cursor: [5, 7],
            selectedItemRow: 5
          })
        }

        // Section1: Exclude f1
        {
          const selectFiles = getNarrowForProvider(await narrow.ui.selectFiles())

          await selectFiles.ensure({query: '', itemTextSet: fileSetByMatch.all})
          await selectFiles.ensure('f1', {query: 'f1', itemTextSet: fileSetByMatch.f1})
          await selectFiles.ensure('f1!', {query: 'f1!', itemTextSet: fileSetByMatch.f2})

          assert(selectFiles.ui.editor.element.hasFocus())

          const promise = selectFiles.promiseForUiEvent('did-destroy')
          dispatchActiveEditor('core:confirm')
          await promise

          // Ensure f1 matching files are excluded and not listed in narrow-editor.
          assert(narrow.ui.editor.element.hasFocus())
          assert.deepEqual(narrow.ui.excludedFiles, [])
          await narrow.ensure({
            query: 'apple',
            searchItems: {
              project1: {'p1-f2': ['p1-f2: apple']},
              project2: {'p2-f2': ['p2-f2: apple']}
            },
            cursor: [3, 7],
            selectedItemRow: 3
          })
        }

        // Section2
        {
          const selectFiles = getNarrowForProvider(await narrow.ui.selectFiles())

          // selectFiles query are remembered until closing narrow-editor.
          await selectFiles.ensure({query: 'f1!', itemTextSet: fileSetByMatch.f2})

          // clear the file filter query
          selectFiles.ui.editor.deleteToBeginningOfLine()
          await selectFiles.promiseForUiEvent('did-refresh')

          // now all files are listable.
          await selectFiles.ensure({query: '', itemTextSet: fileSetByMatch.all})

          const promise = selectFiles.promiseForUiEvent('did-destroy')
          dispatchActiveEditor('core:confirm')
          await promise

          // ensure items for all files are listed and previously selected items are preserveed.
          assert(narrow.ui.editor.element.hasFocus())
          assert.deepEqual(narrow.ui.excludedFiles, [])
          await narrow.ensure({
            searchItems: searchItemsWithQueryApple,
            cursor: [3, 7],
            selectedItemRow: 3
          })
        }
      })
    })

    describe('searchCurrentWord with variable-includes-special-char language, PHP', async () => {
      const ensureSearch = async providerName => {
        const narrow = await startNarrow(providerName, {queryCurrentWord: true})
        assert(narrow.ui.editor.element.hasFocus())
        assert.deepEqual(narrow.ui.excludedFiles, [])

        const textA = $`
          $file
          # project1
          ## p1-f3.php
          $file = "p1-f3.php";
          # project2
          ## p2-f3.php
          $file = "p2-f3.php";
          `
        const textB = $`
          $file
          # project2
          ## p2-f3.php
          $file = "p2-f3.php";
          # project1
          ## p1-f3.php
          $file = "p1-f3.php";
          `

        await narrow.ensure({
          textAndSelectedItemTextOneOf: [
            {text: textA, selectedItemText: '$file = "p1-f3.php";'},
            {text: textB, selectedItemText: '$file = "p2-f3.php";'}
          ],
          cursor: [3, 0]
        })
      }

      beforeEach(async () => {
        await atom.packages.activatePackage('language-php')
        const phpFilePath = Path.join(FIXTURES_DIR, 'project1', 'p1-f3.php')
        const editor = await atom.workspace.open(phpFilePath)
        editor.setCursorBufferPosition([1, 0])
      })

      it('[atom-scan]', async () => {
        await ensureSearch('atom-scan')
      })

      it('search with ag', async () => {
        settings.set('Search.searcher', 'ag')
        await ensureSearch('search')
      })

      it('search with rg', async () => {
        settings.set('Search.searcher', 'rg')
        await ensureSearch('search')
      })
    })

    describe('search regex special char include search term', () => {
      const ensureByProvider = async (name, query, ensureOptions) => {
        const narrow = await startNarrow(name, {query})
        await narrow.ensure(ensureOptions)
        narrow.ui.destroy()
      }

      describe('search project1/p1-f', () => {
        const query = 'project1/p1-f'

        const textA = $`
          project1/p1-f
          # project1
          ## p1-f1
          path: project1/p1-f1
          ## p1-f2
          path: project1/p1-f2
          `

        const textB = $`
          project1/p1-f
          # project1
          ## p1-f2
          path: project1/p1-f2
          ## p1-f1
          path: project1/p1-f1
          `

        const ensureOptions = {
          textAndSelectedItemTextOneOf: [
            {text: textA, selectedItemText: 'path: project1/p1-f1'},
            {text: textB, selectedItemText: 'path: project1/p1-f2'}
          ],
          cursor: [3, 6]
        }

        it('[atom-scan]', async () => {
          await ensureByProvider('atom-scan', query, ensureOptions)
        })

        it('[search:ag]', async () => {
          settings.set('Search.searcher', 'ag')
          await ensureByProvider('atom-scan', query, ensureOptions)
        })

        it('[search:rg]', async () => {
          settings.set('Search.searcher', 'rg')
          await ensureByProvider('atom-scan', query, ensureOptions)
        })
      })

      describe('search a/b/c', () => {
        const query = 'a/b/c'

        const textA = $`
          a/b/c
          # project1
          ## p1-f1
          path: a/b/c
          ## p1-f2
          path: a/b/c
          `

        const textB = $`
          a/b/c
          # project1
          ## p1-f2
          path: a/b/c
          ## p1-f1
          path: a/b/c
          `

        const ensureOptions = {
          textAndSelectedItemTextOneOf: [
            {text: textA, selectedItemText: 'path: a/b/c'},
            {text: textB, selectedItemText: 'path: a/b/c'}
          ],
          cursor: [3, 6]
        }

        it('[atom-scan]', async () => {
          await ensureByProvider('atom-scan', query, ensureOptions)
        })

        it('[search:ag]', async () => {
          settings.set('Search.searcher', 'ag')
          await ensureByProvider('search', query, ensureOptions)
        })

        it('[search:rg]', async () => {
          settings.set('Search.searcher', 'rg')
          await ensureByProvider('search', query, ensureOptions)
        })
      })

      describe('search a/b/c', () => {
        let query = 'a\\/b\\/c'

        const textA = $`
          a\\/b\\/c
          # project1
          ## p1-f1
          path: a\\/b\\/c
          ## p1-f2
          path: a\\/b\\/c
          `

        const textB = $`
          a\\/b\\/c
          # project1
          ## p1-f2
          path: a\\/b\\/c
          ## p1-f1
          path: a\\/b\\/c
          `

        const ensureOptions = {
          textAndSelectedItemTextOneOf: [
            {text: textA, selectedItemText: 'path: a\\/b\\/c'},
            {text: textB, selectedItemText: 'path: a\\/b\\/c'}
          ],
          cursor: [3, 6]
        }

        it('[atom-scan]', async () => {
          await ensureByProvider('atom-scan', query, ensureOptions)
        })

        it('[search:ag]', async () => {
          settings.set('Search.searcher', 'ag')
          await ensureByProvider('search', query, ensureOptions)
        })

        it('[search:rg]', async () => {
          settings.set('Search.searcher', 'rg')
          await ensureByProvider('search', query, ensureOptions)
        })
      })
    })
  })
})
