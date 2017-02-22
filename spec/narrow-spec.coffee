Ui = require '../lib/ui'
{
  startNarrow
  dispatchCommand
  ensureCursorPosition
  ensureEditor
} = require "./spec-helper"

# Main
# -------------------------
describe "narrow", ->
  [editor, editorElement, main] = []
  [provider, ui, ensure] = []
  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('narrow').then (pack) ->
        main = pack.mainModule

    waitsForPromise ->
      atom.workspace.open().then (_editor) ->
        editor = _editor
        editorElement = editor.element

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
          startNarrow('scan').then (narrow) ->
            {provider, ui, ensure} = narrow

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
        runs ->
          ensure "l",
            text: """
              l
              1: 4: apple
              3: 1: lemmon
              """
            selectedItemRow: 1

        waitsForPromise ->
          ui.confirm().then ->
            ensureEditor editor, cursor: [0, 3]

      it "land to confirmed item", ->
        runs ->
          ensure "mm",
            text: """
              mm
              3: 3: lemmon
              """
            selectedItemRow: 1
        waitsForPromise ->
          ui.confirm().then ->
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
        atom.workspace.paneForItem(editor).activate()
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
          atom.workspace.paneForItem(editor).activate()
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
