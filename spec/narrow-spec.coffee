_ = require 'underscore-plus'
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
  setActiveTextEditor
  setActiveTextEditorWithWaits
} = require "./spec-helper"
runCommand = dispatchEditorCommand

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

  waitsForStartNarrow = (providerName, options) ->
    waitsForPromise ->
      startNarrow(providerName, options).then (_narrow) ->
        {provider, ui, ensure} = narrow = _narrow

  waitsForStartScan = (options) -> waitsForStartNarrow('scan', options)

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
        narrow.waitsForDestroy -> runCommand('core:confirm')
        runs ->
          ensureEditor editor, cursor: [0, 3]
          expect(Ui.getSize()).toBe(0)

      it "land to confirmed item and keep open narrow-editor", ->
        settings.set('Scan.closeOnConfirm', false)
        narrow.waitsForConfirm -> runCommand('core:confirm')
        runs ->
          ensureEditor editor, cursor: [0, 3]
          expect(Ui.getSize()).toBe(1)

    describe "confirm-keep-open command", ->
      it "land to confirmed item and keep open narrow-editor even if closeOnConfirm was true", ->
        settings.set('Scan.closeOnConfirm', true)
        narrow.waitsForConfirm -> runCommand('narrow-ui:confirm-keep-open')
        runs ->
          ensureEditor editor, cursor: [0, 3]
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

          describe "initially left-pane active", ->
            it "open on existing right pane", ->
              paneForItem(editor).activate()
              ensureEditorIsActive(editor)
              ensurePaneLayoutAfterStart((ui) -> horizontal: [[editor], [editor2, ui.editor]])

          describe "initially right-pane active", ->
            it "open on previous adjacent pane", ->
              ensureEditorIsActive(editor2)
              ensurePaneLayoutAfterStart((ui) -> horizontal: [[editor, ui.editor], [editor2]])

        describe "vertical split", ->
          beforeEach ->
            waitsForPromise ->
              atom.workspace.open(null, split: 'down').then (_editor) ->
                editor2 = _editor
                ensurePaneLayout(vertical: [[editor], [editor2]])

          describe "initially ip-pane active", ->
            it "open on existing down pane", ->
              paneForItem(editor).activate()
              ensureEditorIsActive(editor)
              ensurePaneLayoutAfterStart((ui) -> vertical: [[editor], [editor2, ui.editor]])

          describe "initially iown pane active", ->
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
      runCommand('narrow:focus'); ensureEditorIsActive(editor)
      runCommand('narrow:focus'); ensureEditorIsActive(ui.editor)
      runCommand('narrow:focus'); ensureEditorIsActive(editor)

  describe "narrow:focus-prompt", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])
      waitsForStartScan()

    it "toggle focus between provider.editor and ui.editor", ->
      ui.editor.setCursorBufferPosition([1, 0])

      ensureEditorIsActive(ui.editor)
      ensure cursor: [1, 0], selectedItemRow: 1

      runCommand('narrow:focus-prompt'); ensureEditorIsActive(ui.editor)
      ensure cursor: [0, 0], selectedItemRow: 1

      # focus provider.editor
      runCommand('narrow:focus-prompt'); ensureEditorIsActive(editor)
      ensure cursor: [0, 0], selectedItemRow: 1

      # focus narrow-editor
      runCommand('narrow:focus-prompt'); ensureEditorIsActive(ui.editor)
      ensure cursor: [0, 0], selectedItemRow: 1

  describe "narrow:close", ->
    beforeEach ->
      editor.setText(appleGrapeLemmonText)
      editor.setCursorBufferPosition([0, 0])
      waitsForStartScan()

    it "close narrow-editor from outside of narrow-editor", ->
      expect(atom.workspace.getTextEditors()).toHaveLength(2)
      setActiveTextEditor(editor)
      ensureEditorIsActive(editor)
      runCommand('narrow:close')
      ensureEditorIsActive(editor)
      expect(atom.workspace.getTextEditors()).toHaveLength(1)

    it "continue close until no narrow-editor is exists", ->
      waitsForStartScan()
      waitsForStartScan()
      waitsForStartScan()

      runs ->
        expect(Ui.getSize()).toBe(4)
        setActiveTextEditor(editor); ensureEditorIsActive(editor)
        runCommand('narrow:close'); expect(Ui.getSize()).toBe(3)
        runCommand('narrow:close'); expect(Ui.getSize()).toBe(2)
        runCommand('narrow:close'); expect(Ui.getSize()).toBe(1)
        runCommand('narrow:close'); expect(Ui.getSize()).toBe(0)
        runCommand('narrow:close'); expect(Ui.getSize()).toBe(0)

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
        runCommand('narrow:refresh')

      runs ->
        ensure text: originalText

  describe "narrow:next-item, narrow:previous-item", ->
    nextItem = -> runs -> narrow.waitsForConfirm -> runCommand('narrow:next-item')
    previousItem = -> runs -> narrow.waitsForConfirm -> runCommand('narrow:previous-item')

    describe "basic behavior", ->
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
        setActiveTextEditor(editor); ensureEditorIsActive(editor)
        ensureEditor editor, cursor: [0, 0]

        _ensureEditor = (options) -> runs -> ensureEditor(editor, options)

        nextItem(); _ensureEditor cursor: [0, 1]
        nextItem(); _ensureEditor cursor: [0, 2]
        nextItem(); _ensureEditor cursor: [1, 3]
        nextItem(); _ensureEditor cursor: [0, 1]

        previousItem(); _ensureEditor cursor: [1, 3]
        previousItem(); _ensureEditor cursor: [0, 2]
        previousItem(); _ensureEditor cursor: [0, 1]

    describe "when cursor position is contained in item.range", ->
      beforeEach ->
        editor.setText """
          line 1
            line 2
          line 3
            line 4
          """
        editor.setCursorBufferPosition([0, 0])

        waitsForStartScan()

        runs ->
          ensure "line",
            text: """
              line
              1: 1: line 1
              2: 3:   line 2
              3: 1: line 3
              4: 3:   line 4
              """

      it "move to next/previous", ->
        jasmine.useRealClock()

        setActiveTextEditorWithWaits(editor)

        r1 = [[0, 0], [0, 3]] # `line` range of "line 1"
        r2 = [[1, 2], [1, 6]] # `line` range of "  line 2"
        r3 = [[2, 0], [2, 3]] # `line` range of "line 3"
        r4 = [[3, 2], [3, 6]] # `line` range of "  line 4"

        setCursor = (point) -> runs -> editor.setCursorBufferPosition(point)
        ensureCursor = (point) -> runs -> ensureEditor(editor, cursor: point)

        setCursor(r1[0]); nextItem(); ensureCursor([1, 2])
        setCursor(r1[1]); nextItem(); ensureCursor([1, 2])
        setCursor(r1[0]); previousItem(); ensureCursor([3, 2])
        setCursor(r1[1]); previousItem(); ensureCursor([3, 2])

        setCursor(r2[0]); nextItem(); ensureCursor([2, 0])
        setCursor(r2[1]); nextItem(); ensureCursor([2, 0])
        setCursor(r2[0]); previousItem(); ensureCursor([0, 0])
        setCursor(r2[1]); previousItem(); ensureCursor([0, 0])

        setCursor(r3[0]); nextItem(); ensureCursor([3, 2])
        setCursor(r3[1]); nextItem(); ensureCursor([3, 2])
        setCursor(r3[0]); previousItem(); ensureCursor([1, 2])
        setCursor(r3[1]); previousItem(); ensureCursor([1, 2])

        setCursor(r4[0]); nextItem(); ensureCursor([0, 0])
        setCursor(r4[1]); nextItem(); ensureCursor([0, 0])
        setCursor(r4[0]); previousItem(); ensureCursor([2, 0])
        setCursor(r4[1]); previousItem(); ensureCursor([2, 0])

  describe "auto reveal on start behavior( revealOnStartCondition )", ->
    [r1, r2, r3, r4, getEnsureStartState] = []
    beforeEach ->
      getEnsureStartState = (startOptions) ->
        (point, options) ->
          runs -> editor.setCursorBufferPosition(point)
          waitsForStartScan(startOptions)
          runs -> ensure(options)
          runs -> ui.destroy()

      r1 = [[0, 0], [0, 3]] # `line` range of "line 1"
      r2 = [[1, 2], [1, 6]] # `line` range of "  line 2"
      r3 = [[2, 0], [2, 3]] # `line` range of "line 3"
      r4 = [[3, 2], [3, 6]] # `line` range of "  line 4"

      editor.setText """
        line 1
          line 2
        line 3
          line 4
        """
      editor.setCursorBufferPosition([0, 0])

    describe "revealOnStartCondition = on-input( default )", ->
      beforeEach ->
        settings.set('Scan.revealOnStartCondition', 'on-input')

      it "auto reveal when initial query was provided", ->
        text = """
          line
          1: 1: line 1
          2: 3:   line 2
          3: 1: line 3
          4: 3:   line 4
          """
        ensureStartState = getEnsureStartState(queryCurrentWord: true)
        ensureStartState(r1[0], selectedItemText: "line 1", cursor: [1, 5], text: text)
        ensureStartState(r2[0], selectedItemText: "  line 2", cursor: [2, 5], text: text)
        ensureStartState(r3[0], selectedItemText: "line 3", cursor: [3, 5], text: text)
        ensureStartState(r4[0], selectedItemText: "  line 4", cursor: [4, 5], text: text)

      it "NOT auto reveal when no query was provided", ->
        text = """

          1: 1: line 1
          2: 1:   line 2
          3: 1: line 3
          4: 1:   line 4
          """
        ensureStartState = getEnsureStartState()
        options = {selectedItemText: "line 1", cursor: [0, 0], text: text}
        ensureStartState(r1[0], options)
        ensureStartState(r2[0], options)
        ensureStartState(r3[0], options)
        ensureStartState(r4[0], options)

    describe "revealOnStartCondition = never", ->
      beforeEach ->
        settings.set('Scan.revealOnStartCondition', 'never')

      it "NOT auto reveal when initial query was provided", ->
        text = """
          line
          1: 1: line 1
          2: 3:   line 2
          3: 1: line 3
          4: 3:   line 4
          """
        ensureStartState = getEnsureStartState(queryCurrentWord: true)
        options = {selectedItemText: "line 1", cursor: [0, 4], text: text}
        ensureStartState(r1[0], options)
        ensureStartState(r2[0], options)
        ensureStartState(r3[0], options)
        ensureStartState(r4[0], options)

      it "NOT auto reveal when no query was provided", ->
        text = """

          1: 1: line 1
          2: 1:   line 2
          3: 1: line 3
          4: 1:   line 4
          """
        ensureStartState = getEnsureStartState()
        options = {selectedItemText: "line 1", cursor: [0, 0], text: text}
        ensureStartState(r1[0], options)
        ensureStartState(r2[0], options)
        ensureStartState(r3[0], options)
        ensureStartState(r4[0], options)

    describe "revealOnStartCondition = always", ->
      beforeEach ->
        settings.set('Scan.revealOnStartCondition', 'always')

      it "auto reveal when initial query was provided", ->
        text = """
          line
          1: 1: line 1
          2: 3:   line 2
          3: 1: line 3
          4: 3:   line 4
          """
        ensureStartState = getEnsureStartState(queryCurrentWord: true)
        ensureStartState(r1[0], selectedItemText: "line 1", cursor: [1, 5], text: text)
        ensureStartState(r2[0], selectedItemText: "  line 2", cursor: [2, 5], text: text)
        ensureStartState(r3[0], selectedItemText: "line 3", cursor: [3, 5], text: text)
        ensureStartState(r4[0], selectedItemText: "  line 4", cursor: [4, 5], text: text)

      it "NOT auto reveal when no query was provided", ->
        text = """

          1: 1: line 1
          2: 1:   line 2
          3: 1: line 3
          4: 1:   line 4
          """
        ensureStartState = getEnsureStartState()
        ensureStartState(r1[0], selectedItemText: "line 1", cursor: [1, 5], text: text)
        ensureStartState(r2[0], selectedItemText: "  line 2", cursor: [2, 5], text: text)
        ensureStartState(r3[0], selectedItemText: "line 3", cursor: [3, 5], text: text)
        ensureStartState(r4[0], selectedItemText: "  line 4", cursor: [4, 5], text: text)

  describe "narrow-editor auto-sync selected-item to active editor", ->
    [editor2] = []

    beforeEach ->
      runs ->
        editor.setText """
          line 1

          line 3

          line 5

          line 7

          line 9

          """
        editor.setCursorBufferPosition([0, 0])

      waitsForPromise ->
        atom.workspace.open().then (_editor) ->
          editor2 = _editor
          editor2.setText """

            line 2

            line 4

            line 6

            line 8

            line 10
            """
          editor2.setCursorBufferPosition([0, 0])

      waitsForStartScan()

      runs ->
        ensureEditorIsActive(ui.editor)
        expect(provider.editor).toBe(editor2)
        ensure "line",
          text: """
            line
             2: 1: line 2
             4: 1: line 4
             6: 1: line 6
             8: 1: line 8
            10: 1: line 10
            """

    describe "re-bound to active text-editor", ->
      it "provider.editor is bound to active text-editor and auto-refreshed", ->
        jasmine.useRealClock()

        setActiveTextEditorWithWaits(editor)

        runs ->
          ensureEditorIsActive(editor)
          expect(provider.editor).toBe(editor)
          ensure
            text: """
              line
              1: 1: line 1
              3: 1: line 3
              5: 1: line 5
              7: 1: line 7
              9: 1: line 9
              """

        setActiveTextEditorWithWaits(editor2)

        runs ->
          ensureEditorIsActive(editor2)
          expect(provider.editor).toBe(editor2)
          ensure
            text: """
              line
               2: 1: line 2
               4: 1: line 4
               6: 1: line 6
               8: 1: line 8
              10: 1: line 10
              """

    describe "auto-sync selected-item to acitive-editor's cursor position", ->
      it "provider.editor is bound to active text-editor and auto-refreshed", ->
        jasmine.useRealClock()
        setActiveTextEditorWithWaits(editor)

        runs ->
          ensureEditorIsActive(editor)
          expect(provider.editor).toBe(editor)

          setCursor = (point) -> editor.setCursorBufferPosition(point)

          setCursor([0, 0])
          ensure selectedItemText: "line 1"
          setCursor([1, 0]); ensure selectedItemText: "line 1"
          setCursor([2, 0]); ensure selectedItemText: "line 3"
          setCursor([3, 0]); ensure selectedItemText: "line 3"
          setCursor([4, 0]); ensure selectedItemText: "line 5"
          editor.moveToBottom()
          ensureEditor editor, cursor: [9, 0]
          ensure selectedItemText: "line 9"

        setActiveTextEditorWithWaits(editor2)

        runs ->
          setCursor = (point) -> editor2.setCursorBufferPosition(point)

          expect(provider.editor).toBe(editor2)
          ensure selectedItemText: "line 2"
          setCursor([1, 0]); ensure selectedItemText: "line 2"
          setCursor([3, 0]); ensure selectedItemText: "line 4"
          setCursor([5, 0]); ensure selectedItemText: "line 6"
          setCursor([7, 0]); ensure selectedItemText: "line 8"

          editor2.moveToTop()
          ensureEditor editor2, cursor: [0, 0]
          ensure selectedItemText: "line 2"

  describe "scan", ->
    describe "with empty qury", ->
      confirm = -> narrow.waitsForDestroy -> runCommand('core:confirm')
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
