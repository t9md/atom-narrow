Ui = require '../lib/ui'
settings = require '../lib/settings'
{
  startNarrow
  ensureCursorPosition
  ensureEditor
  ensurePaneLayout
  ensureEditorIsActive
  dispatchEditorCommand
  paneForItem
} = require "./spec-helper"

appleGrapeLemmonText = """
  apple
  grape
  lemmon
  """
# Main
# -------------------------
describe "narrow", ->
  [editor, editorElement] = []
  [provider, ui, ensure, narrow] = []

  waitsForStartScan = ->
    waitsForPromise ->
      startNarrow('scan').then (_narrow) ->
        {provider, ui, ensure} = narrow = _narrow

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('narrow')

    waitsForPromise ->
      atom.workspace.open().then (_editor) ->
        editor = _editor
        editorElement = editor.element

  describe "confirm family", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])
      waitsForStartScan()
      runs ->
        ensure "l",
          text: """
            l
            1: 4: apple
            3: 1: lemmon
            """
          selectedItemRow: 1

    describe "closeOnConfirm settings", ->
      it "land to confirmed item and close narrow-editor", ->
        settings.set('Scan.closeOnConfirm', true)
        narrow.waitsForDestroy -> dispatchEditorCommand('core:confirm')
        runs ->
          ensureEditor editor, cursor: [0, 3]
          ensureEditor ui.editor, alive: false
          expect(Ui.getSize()).toBe(0)

      it "land to confirmed item and keep open narrow-editor", ->
        settings.set('Scan.closeOnConfirm', false)
        narrow.waitsForConfirm -> dispatchEditorCommand('core:confirm')
        runs ->
          ensureEditor editor, cursor: [0, 3]
          ensureEditor ui.editor, alive: true
          expect(Ui.getSize()).toBe(1)

    describe "confirm-keep-open command", ->
      it "land to confirmed item and keep open narrow-editor even if closeOnConfirm was true", ->
        settings.set('Scan.closeOnConfirm', true)
        narrow.waitsForConfirm -> dispatchEditorCommand('narrow-ui:confirm-keep-open')
        runs ->
          ensureEditor editor, cursor: [0, 3]
          ensureEditor ui.editor, alive: true
          expect(Ui.getSize()).toBe(1)

  describe "narrow-editor open/close", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])

    describe "directionToOpen settings", ->
      ensurePaneLayoutAfterStart = (fn) ->
        waitsForPromise -> startNarrow('scan').then ({ui}) -> ensurePaneLayout(fn(ui))

      describe "from one pane", ->
        beforeEach ->
          ensurePaneLayout [editor]

        describe "right", ->
          it 'open on right pane', ->
            settings.set('directionToOpen', 'right')
            ensurePaneLayoutAfterStart((ui) -> horizontal: [[editor], [ui.editor]])

        describe "down", ->
          it 'open on down pane', ->
            settings.set('directionToOpen', 'down')
            ensurePaneLayoutAfterStart((ui) -> vertical: [[editor], [ui.editor]])

      describe "from two pane", ->
        [editor2] = []
        beforeEach ->
          settings.set('directionToOpen', 'right')

        describe "horizontal split", ->
          beforeEach ->
            waitsForPromise ->
              atom.workspace.open(null, split: 'right').then (_editor) ->
                editor2 = _editor
                ensurePaneLayout(horizontal: [[editor], [editor2]])

          describe "left pane active", ->
            it "open on existing right pane", ->
              paneForItem(editor).activate()
              ensureEditorIsActive(editor)
              ensurePaneLayoutAfterStart((ui) -> horizontal: [[editor], [editor2, ui.editor]])

          describe "right pane active", ->
            it "open on previous adjacent pane", ->
              ensureEditorIsActive(editor2)
              ensurePaneLayoutAfterStart((ui) -> horizontal: [[editor, ui.editor], [editor2]])

        describe "vertical split", ->
          beforeEach ->
            waitsForPromise ->
              atom.workspace.open(null, split: 'down').then (_editor) ->
                editor2 = _editor
                ensurePaneLayout(vertical: [[editor], [editor2]])

          describe "up-pane active", ->
            it "open on existing down pane", ->
              paneForItem(editor).activate()
              ensureEditorIsActive(editor)
              ensurePaneLayoutAfterStart((ui) -> vertical: [[editor], [editor2, ui.editor]])

          describe "down pane active", ->
            it "open on previous adjacent pane", ->
              ensureEditorIsActive(editor2)
              ensurePaneLayoutAfterStart((ui) -> vertical: [[editor, ui.editor], [editor2]])

  describe "narrow:focus", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])
      waitsForStartScan()

    it "toggle focus between provider.editor and ui.editor", ->
      ensureEditorIsActive(ui.editor)
      dispatchEditorCommand('narrow:focus')
      ensureEditorIsActive(editor)
      dispatchEditorCommand('narrow:focus')
      ensureEditorIsActive(ui.editor)

  describe "narrow:focus-prompt", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])
      waitsForStartScan()

    it "toggle focus between provider.editor and ui.editor", ->
      ui.editor.setCursorBufferPosition([1, 0])

      ensureEditorIsActive(ui.editor)
      ensure cursor: [1, 0], selectedItemRow: 1

      dispatchEditorCommand('narrow:focus-prompt') # focus from item-area to prompt
      ensureEditorIsActive(ui.editor)
      ensure cursor: [0, 0], selectedItemRow: 1

      dispatchEditorCommand('narrow:focus-prompt') # focus provider.editor
      ensureEditorIsActive(editor)
      ensure cursor: [0, 0], selectedItemRow: 1

      dispatchEditorCommand('narrow:focus-prompt') # focus narrow-editor
      ensureEditorIsActive(ui.editor)
      ensure cursor: [0, 0], selectedItemRow: 1

  describe "narrow:close", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])
      waitsForStartScan()

    it "close narrow-editor from outside of narrow-editor", ->
      expect(atom.workspace.getTextEditors()).toHaveLength(2)
      paneForItem(editor).activate()
      ensureEditorIsActive(editor)
      dispatchEditorCommand('narrow:close')
      ensureEditorIsActive(editor)
      expect(atom.workspace.getTextEditors()).toHaveLength(1)

    it "continue close until no narrow-editor is exists", ->
      waitsForStartScan()
      waitsForStartScan()
      waitsForStartScan()

      runs ->
        expect(Ui.getSize()).toBe(4)
        paneForItem(editor).activate()
        ensureEditorIsActive(editor)
        dispatchEditorCommand('narrow:close')
        expect(Ui.getSize()).toBe(3)
        dispatchEditorCommand('narrow:close')
        expect(Ui.getSize()).toBe(2)
        dispatchEditorCommand('narrow:close')
        expect(Ui.getSize()).toBe(1)
        dispatchEditorCommand('narrow:close')
        expect(Ui.getSize()).toBe(0)
        dispatchEditorCommand('narrow:close')
        expect(Ui.getSize()).toBe(0)

  describe "narrow:refresh", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])
      waitsForStartScan()

    it "redraw items when item area was mutated", ->
      originalText = ui.editor.getText()

      narrow.waitsForRefresh ->
        range = [[1, 0], ui.editor.getEofBufferPosition()]
        ui.editor.setTextInBufferRange(range, 'abc\ndef\n')
        ensure text: "\nabc\ndef\n"

      narrow.waitsForRefresh ->
        dispatchEditorCommand('narrow:refresh')

      runs ->
        ensure text: originalText

  describe "narrow:next-item, narrow:previous-item", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])
      waitsForStartScan()

      runs ->
        ensure "p",
          text: """
            p
            1: 2: apple
            1: 3: apple
            2: 4: grape
            """

    it "move to next/previous item with wrap", ->
      paneForItem(editor).activate()
      ensureEditorIsActive(editor)
      ensureEditor editor, cursor: [0, 0]
      nextItem = -> narrow.waitsForConfirm -> dispatchEditorCommand('narrow:next-item')
      previousItem = -> narrow.waitsForConfirm -> dispatchEditorCommand('narrow:previous-item')

      runs -> nextItem(); runs -> ensureEditor editor, cursor: [0, 1]
      runs -> nextItem(); runs -> ensureEditor editor, cursor: [0, 2]
      runs -> nextItem(); runs -> ensureEditor editor, cursor: [1, 3]
      runs -> nextItem(); runs -> ensureEditor editor, cursor: [0, 1]

      runs -> previousItem(); runs -> ensureEditor editor, cursor: [1, 3]
      runs -> previousItem(); runs -> ensureEditor editor, cursor: [0, 2]
      runs -> previousItem(); runs -> ensureEditor editor, cursor: [0, 1]

  describe "scan", ->
    describe "with empty qury", ->
      confirm = -> narrow.waitsForDestroy -> dispatchEditorCommand('core:confirm')
      beforeEach ->
        editor.setText(appleGrapeLemmonText)
        editor.setCursorBufferPosition([0, 0])
        waitsForStartScan()

      it "add css class to narrowEditorElement", ->
        ensure classListContains: ['narrow', 'narrow-editor', 'scan']

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

        runs -> confirm(); runs -> ensureEditor editor, cursor: [0, 3]

      it "land to confirmed item", ->
        runs ->
          ensure "mm",
            text: """
              mm
              3: 3: lemmon
              """
            selectedItemRow: 1
        runs -> confirm(); runs -> ensureEditor editor, cursor: [2, 2]

    describe "with queryCurrentWord", ->
      beforeEach ->
        editor.setText(appleGrapeLemmonText)

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
