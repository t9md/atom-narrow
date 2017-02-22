Ui = require '../lib/ui'
settings = require '../lib/settings'
{
  startNarrow
  dispatchCommand
  ensureCursorPosition
  ensureEditor
} = require "./spec-helper"

paneForItem = (item) ->
  atom.workspace.paneForItem(item)

# Main
# -------------------------
describe "narrow", ->
  [editor, editorElement, main] = []
  [provider, ui, ensure, narrow] = []
  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('narrow').then (pack) ->
        main = pack.mainModule

    waitsForPromise ->
      atom.workspace.open().then (_editor) ->
        editor = _editor
        editorElement = editor.element

  describe "narrow-editor open/close", ->
    beforeEach ->
      editor.setText """
        apple
        grape
        lemmon
        """
      editor.setCursorBufferPosition([0, 0])

    describe "directionToOpen settings", ->
      describe "right", ->
        describe "from one pane", ->
          beforeEach ->
            expect(atom.workspace.getPanes()).toHaveLength(1)
            settings.set('narrow.directionToOpen', 'right')

          it 'open on right pane', ->
            waitsForPromise ->
              startNarrow('scan').then ({ui}) ->
                expect(atom.workspace.getPanes()).toHaveLength(2)
                paneAxis = ui.getPane().getParent()
                expect(paneAxis.getOrientation()).toBe('horizontal')
                children = paneAxis.getChildren()
                expect(children).toHaveLength(2)
                expect(children[0]).toBe(ui.provider.getPane())
                expect(children[1]).toBe(ui.getPane())

        describe "from two pane", ->
          [editor2, paneAxis] = []

          describe "horizontal split", ->
            beforeEach ->
              waitsForPromise ->
                atom.workspace.open(null, split: 'right', activate: true, activateItem: true).then (_editor) ->
                  editor2 = _editor
                  editor2.setText("abc\ndef\n")

              runs ->
                expect(atom.workspace.getPanes()).toHaveLength(2)
                pane = paneForItem(editor2)
                paneAxis = pane.getParent()
                expect(paneAxis.getOrientation()).toBe('horizontal')

                children = paneAxis.getChildren()
                expect(children).toHaveLength(2)
                [p1, p2] = children
                expect(p1.getActiveItem()).toBe(editor)
                expect(p2.getActiveItem()).toBe(editor2)

            describe "left pane active", ->
              beforeEach ->
                paneForItem(editor).activate()
                ensureEditor editor, active: true

              it "open on existing right pane", ->
                waitsForPromise ->
                  startNarrow('scan').then ({ui}) ->
                    expect(ui.getPane().getParent()).toBe(paneAxis)
                    expect(paneAxis.getOrientation()).toBe('horizontal')

                    children = paneAxis.getChildren()
                    expect(children).toHaveLength(2)
                    [p1, p2] = children
                    expect(p1.getActiveItem()).toBe(editor)
                    expect(p2.getActiveItem()).toBe(ui.editor)

            describe "right pane active", ->
              beforeEach ->
                ensureEditor editor, active: false
                ensureEditor editor2, active: true

              it "open on previous adjacent pane", ->
                waitsForPromise ->
                  startNarrow('scan').then ({ui}) ->
                    expect(ui.getPane().getParent()).toBe(paneAxis)
                    expect(paneAxis.getOrientation()).toBe('horizontal')

                    children = paneAxis.getChildren()
                    expect(children).toHaveLength(2)
                    [p1, p2] = children
                    expect(p1.getActiveItem()).toBe(ui.editor)
                    expect(p2.getActiveItem()).toBe(editor2)

  describe "scan", ->
    describe "with empty qury", ->
      beforeEach ->
        editor.setText """
          apple
          grape
          lemmon
          """
        editor.setCursorBufferPosition([0, 0])

        waitsForPromise ->
          startNarrow('scan').then (_narrow) ->
            {provider, ui, ensure} = narrow = _narrow

      it "add css class to narrowEditorElement", ->
        expect(ui.editorElement.classList.contains('narrow')).toBe(true)
        expect(ui.editorElement.classList.contains('narrow-editor')).toBe(true)
        expect(ui.editorElement.classList.contains('scan')).toBe(true)

      it "initial state is whole buffer lines", ->
        ensure
          text: """

          1: 1: apple
          2: 1: grape
          3: 1: lemmon
          """

      it "can filter by query", ->
        ensure "app",
          text: """
            app
            1: 1: apple
            """
          selectedItemRow: 1
          itemsCount: 1

        ensure "r",
          text: """
            r
            2: 2: grape
            """
          selectedItemRow: 1
          itemsCount: 1

        ensure "l",
          text: """
            l
            1: 4: apple
            3: 1: lemmon
            """
          selectedItemRow: 1
          itemsCount: 2

      it "land to confirmed item", ->
        disposable = null

        runs ->
          ensure "l",
            text: """
              l
              1: 4: apple
              3: 1: lemmon
              """
            selectedItemRow: 1

        runs ->
          dispatchCommand(ui.editorElement, 'core:confirm')
          disposable = ui.editor.onDidDestroy -> disposable.dispose()
        waitsFor -> disposable.disposed
        runs -> ensureEditor editor, cursor: [0, 3]

      it "land to confirmed item", ->
        disposable = null

        runs ->
          ensure "mm",
            text: """
              mm
              3: 3: lemmon
              """
            selectedItemRow: 1
        runs ->
          dispatchCommand(ui.editorElement, 'core:confirm')
          disposable = ui.editor.onDidDestroy -> disposable.dispose()
        waitsFor -> disposable.disposed
        runs ->
          ensureEditor editor, cursor: [2, 2]

    describe "with queryCurrentWord", ->
      beforeEach ->
        editor.setText """
          apple
          grape
          lemmon
          """

      it "set current-word as initial query", ->
        waitsForPromise ->
          editor.setCursorBufferPosition([0, 0])
          startNarrow('scan', queryCurrentWord: true).then (narrow) ->
            narrow.ensure
              text: """
                apple
                1: 1: apple
                """
              selectedItemRow: 1
              itemsCount: 1
            runs -> narrow.ui.destroy()

        waitsForPromise ->
          editor.setCursorBufferPosition([1, 0])
          startNarrow('scan', queryCurrentWord: true).then (narrow) ->
            narrow.ensure
              text: """
                grape
                2: 1: grape
                """
              selectedItemRow: 1
              itemsCount: 1
            runs -> narrow.ui.destroy()

        waitsForPromise ->
          editor.setCursorBufferPosition([2, 0])
          startNarrow('scan', queryCurrentWord: true).then (narrow) ->
            narrow.ensure
              text: """
                lemmon
                3: 1: lemmon
                """
              selectedItemRow: 1
              itemsCount: 1
            runs -> narrow.ui.destroy()

    describe "narrow:focus", ->
      beforeEach ->
        editor.setText """
          apple
          grape
          lemmon
          """
        editor.setCursorBufferPosition([0, 0])

        waitsForPromise ->
          startNarrow('scan').then (narrow) ->
            {provider, ui, ensure} = narrow

      it "toggle focus between provider.editor and ui.editor", ->
        ensureEditor editor, active: false
        ensureEditor ui.editor, active: true
        dispatchCommand(atom.workspace.getActiveTextEditor().element, 'narrow:focus')
        ensureEditor editor, active: true
        ensureEditor ui.editor, active: false
        dispatchCommand(atom.workspace.getActiveTextEditor().element, 'narrow:focus')
        ensureEditor editor, active: false
        ensureEditor ui.editor, active: true

    describe "narrow:focus-prompt", ->
      focusPrompt = ->
        dispatchCommand(atom.workspace.getActiveTextEditor().element, 'narrow:focus-prompt')

      beforeEach ->
        editor.setText """
          apple
          grape
          lemmon
          """
        editor.setCursorBufferPosition([0, 0])

        waitsForPromise ->
          startNarrow('scan').then (narrow) ->
            {provider, ui, ensure} = narrow

      it "toggle focus between provider.editor and ui.editor", ->
        ui.editor.setCursorBufferPosition([1, 0])

        ensureEditor editor, active: false
        ensureEditor ui.editor, active: true
        ensure cursor: [1, 0], selectedItemRow: 1


        focusPrompt() # focus from item-area to prompt
        ensureEditor editor, active: false
        ensureEditor ui.editor, active: true
        ensure cursor: [0, 0], selectedItemRow: 1

        focusPrompt() # focus provider.editor
        ensureEditor editor, active: true
        ensureEditor ui.editor, active: false
        ensure cursor: [0, 0], selectedItemRow: 1

        focusPrompt() # focus narrow-editor
        ensureEditor editor, active: false
        ensureEditor ui.editor, active: true
        ensure cursor: [0, 0], selectedItemRow: 1

    describe "narrow:close", ->
      beforeEach ->
        editor.setText """
          apple
          grape
          lemmon
          """
        editor.setCursorBufferPosition([0, 0])

        waitsForPromise ->
          startNarrow('scan').then (narrow) ->
            {provider, ui, ensure} = narrow

      it "close narrow-editor from outside of narrow-editor", ->
        expect(atom.workspace.getTextEditors()).toHaveLength(2)
        paneForItem(editor).activate()
        ensureEditor editor, active: true, alive: true
        ensureEditor ui.editor, active: false, alive: true
        dispatchCommand(editor.element, 'narrow:close')
        ensureEditor editor, active: true, alive: true
        ensureEditor ui.editor, active: false, alive: false
        expect(atom.workspace.getTextEditors()).toHaveLength(1)

      it "continue close until no narrow-editor is exists", ->
        waitsForPromise -> startNarrow('scan')
        waitsForPromise -> startNarrow('scan')
        waitsForPromise -> startNarrow('scan')

        runs ->
          expect(Ui.getSize()).toBe(4)
          paneForItem(editor).activate()
          ensureEditor editor, active: true
          dispatchCommand(editor.element, 'narrow:close')
          expect(Ui.getSize()).toBe(3)
          dispatchCommand(editor.element, 'narrow:close')
          expect(Ui.getSize()).toBe(2)
          dispatchCommand(editor.element, 'narrow:close')
          expect(Ui.getSize()).toBe(1)
          dispatchCommand(editor.element, 'narrow:close')
          expect(Ui.getSize()).toBe(0)
          dispatchCommand(editor.element, 'narrow:close')
          expect(Ui.getSize()).toBe(0)

    describe "narrow:refresh", ->
      beforeEach ->
        editor.setText """
          apple
          grape
          lemmon
          """
        editor.setCursorBufferPosition([0, 0])

        waitsForPromise ->
          startNarrow('scan').then (_narrow) ->
            {provider, ui, ensure} = narrow = _narrow

      it "redraw items when item area was mutated", ->
        originalText = ui.editor.getText()

        narrow.waitsForRefresh ->
          range = [[1, 0], ui.editor.getEofBufferPosition()]
          ui.editor.setTextInBufferRange(range, 'abc\ndef\n')
          ensure text: "\nabc\ndef\n"

        narrow.waitsForRefresh ->
          dispatchCommand(editorElement, 'narrow:refresh')

        runs ->
          ensure text: originalText

    describe "narrow:next-item, narrow:previous-item", ->
      beforeEach ->
        editor.setText """
          apple
          grape
          lemmon
          """
        editor.setCursorBufferPosition([0, 0])

        waitsForPromise ->
          startNarrow('scan').then (_narrow) ->
            {provider, ui, ensure} = narrow = _narrow

        runs ->
          ensure "p",
            text: """
              p
              1: 2: apple
              1: 3: apple
              2: 4: grape
              """

      it "move to next/previous item with wrap", ->
        ui.activateProviderPane()
        ensureEditor editor, active: true, cursor: [0, 0]
        nextItem = -> narrow.waitsForConfirm -> dispatchCommand(editorElement, 'narrow:next-item')
        previousItem = -> narrow.waitsForConfirm -> dispatchCommand(editorElement, 'narrow:previous-item')

        runs -> nextItem(); runs -> ensureEditor editor, cursor: [0, 1]
        runs -> nextItem(); runs -> ensureEditor editor, cursor: [0, 2]
        runs -> nextItem(); runs -> ensureEditor editor, cursor: [1, 3]
        runs -> nextItem(); runs -> ensureEditor editor, cursor: [0, 1]

        runs -> previousItem(); runs -> ensureEditor editor, cursor: [1, 3]
        runs -> previousItem(); runs -> ensureEditor editor, cursor: [0, 2]
        runs -> previousItem(); runs -> ensureEditor editor, cursor: [0, 1]
