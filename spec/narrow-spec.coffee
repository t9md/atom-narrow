_ = require 'underscore-plus'
Ui = require '../lib/ui'
fs = require 'fs-plus'
path = require 'path'
settings = require '../lib/settings'
{
  startNarrow
  reopen
  getNarrowForUi
  ensureCursorPosition
  ensureEditor
  ensurePaneLayout
  ensureEditorIsActive
  dispatchEditorCommand
  paneForItem
  setActiveTextEditor
  setActiveTextEditorWithWaits
} = require "./helper"
runCommand = dispatchEditorCommand

appleGrapeLemmonText = """
  apple
  grape
  lemmon
  """
# Main
# -------------------------
describe "narrow", ->
  [editor, editorElement, provider, ui, ensure, narrow] = []

  waitsForStartNarrow = (providerName, options) ->
    waitsForPromise ->
      startNarrow(providerName, options).then (_narrow) ->
        {provider, ui, ensure} = narrow = _narrow

  waitsForStartScan = (options) -> waitsForStartNarrow('scan', options)

  beforeEach ->
    waitsForPromise ->
      activationPromise = atom.packages.activatePackage('narrow')
      atom.workspace.open().then (_editor) ->
        editor = _editor
        editorElement = editor.element

        # HACK: Activate command by toggle setting command, it's most side-effect-less.
        originalValue = settings.get('Search.startByDoubleClick')
        atom.commands.dispatch(editor.element, 'narrow:toggle-search-start-by-double-click')
        settings.set('Search.startByDoubleClick', originalValue)

      activationPromise

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

  describe "reopen", ->
    [narrows] = []
    beforeEach ->
      narrows = []
      editor.setText("1\n2\n3\n4\n5\n6\n7\n8\n9\na\nb")
      editor.setCursorBufferPosition([0, 0])
      for n in [0..10]
        waitsForPromise -> startNarrow('scan').then (n) -> narrows.push(n)

    it "reopen closed narrow editor up to 10 recent", ->
      waitsForReopen = ->
        waitsForPromise -> reopen()
      ensureUiSize = (size) ->
        runs -> expect(Ui.getSize()).toBe(size)
      ensureText = (text) ->
        runs -> expect(atom.workspace.getActiveTextEditor().getText()).toBe(text)

      runs ->
        narrows[0].ensure "1", text: "1\n1: 1: 1"
        narrows[1].ensure "2", text: "2\n2: 1: 2"
        narrows[2].ensure "3", text: "3\n3: 1: 3"
        narrows[3].ensure "4", text: "4\n4: 1: 4"
        narrows[4].ensure "5", text: "5\n5: 1: 5"
        narrows[5].ensure "6", text: "6\n6: 1: 6"
        narrows[6].ensure "7", text: "7\n7: 1: 7"
        narrows[7].ensure "8", text: "8\n8: 1: 8"
        narrows[8].ensure "9", text: "9\n9: 1: 9"
        narrows[9].ensure "a", text: "a\n10: 1: a"
        narrows[10].ensure "b", text: "b\n11: 1: b"

      ensureUiSize(11)

      runs -> ui.destroy() for {ui} in narrows

      ensureUiSize(0)

      waitsForReopen(); ensureText("b\n11: 1: b"); ensureUiSize(1)
      waitsForReopen(); ensureText("a\n10: 1: a"); ensureUiSize(2)
      waitsForReopen(); ensureText("9\n9: 1: 9"); ensureUiSize(3)
      waitsForReopen(); ensureText("8\n8: 1: 8"); ensureUiSize(4)
      waitsForReopen(); ensureText("7\n7: 1: 7"); ensureUiSize(5)
      waitsForReopen(); ensureText("6\n6: 1: 6"); ensureUiSize(6)
      waitsForReopen(); ensureText("5\n5: 1: 5"); ensureUiSize(7)
      waitsForReopen(); ensureText("4\n4: 1: 4"); ensureUiSize(8)
      waitsForReopen(); ensureText("3\n3: 1: 3"); ensureUiSize(9)
      waitsForReopen(); ensureText("2\n2: 1: 2"); ensureUiSize(10)
      runs -> expect(reopen()).toBeFalsy()
      ensureUiSize(10)

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
    [points, pointsA] = []
    getEnsureStartState = (startOptions) ->
      (point, options) ->
        runs -> editor.setCursorBufferPosition(point)
        waitsForStartScan(startOptions)
        runs -> ensure(options)
        runs -> ui.destroy()

    beforeEach ->
      headerLength = "1: 1: ".length
      points = [
        [0, 0] # `line` start of "line 1"
        [1, 2] # `line` start of "  line 2"
        [2, 0] # `line` start of "line 3"
        [3, 2] # `line` start of "  line 4"
      ]
      pointsA = [
        [1, 0 + headerLength]
        [2, 2 + headerLength]
        [3, 0 + headerLength]
        [4, 2 + headerLength]
      ]

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
        ensureStartState(points[0], cursor: pointsA[0], text: text, selectedItemText: 'line 1')
        ensureStartState(points[1], cursor: pointsA[1], text: text, selectedItemText: '  line 2')
        ensureStartState(points[2], cursor: pointsA[2], text: text, selectedItemText: 'line 3')
        ensureStartState(points[3], cursor: pointsA[3], text: text, selectedItemText: '  line 4')

      it "NOT auto reveal when no query was provided", ->
        text = """

          1: 1: line 1
          2: 1:   line 2
          3: 1: line 3
          4: 1:   line 4
          """
        ensureStartState = getEnsureStartState()
        options = {selectedItemText: "line 1", cursor: [0, 0], text: text}
        for point in points
          ensureStartState(point, options)

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
        for point in points
          ensureStartState(point, options)

      it "NOT auto reveal when no query was provided", ->
        text = """

          1: 1: line 1
          2: 1:   line 2
          3: 1: line 3
          4: 1:   line 4
          """
        ensureStartState = getEnsureStartState()
        options = {selectedItemText: "line 1", cursor: [0, 0], text: text}
        for point in points
          ensureStartState(point, options)

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
        ensureStartState points[0], cursor: pointsA[0], text: text, selectedItemText: 'line 1'
        ensureStartState points[1], cursor: pointsA[1], text: text, selectedItemText: '  line 2'
        ensureStartState points[2], cursor: pointsA[2], text: text, selectedItemText: 'line 3'
        ensureStartState points[3], cursor: pointsA[3], text: text, selectedItemText: '  line 4'

      it "auto reveal when initial query was provided when multiple match on same line", ->
        lineText = "line line line line"
        editor.setText(lineText)

        text = """
          line
          1: 1: line line line line
          1: 6: line line line line
          1:11: line line line line
          1:16: line line line line
          """
        ensureStartState = getEnsureStartState(queryCurrentWord: true)
        headerLength = "1:16: ".length
        points = [
          [0, 0]
          [0, 5]
          [0, 10]
          [0, 15]
        ]
        pointsA = [
          [1, 0 + headerLength]
          [2, 5 + headerLength]
          [3, 10 + headerLength]
          [4, 15 + headerLength]
        ]
        for point, i in points
          ensureStartState(point, cursor: pointsA[i], text: text, selectedItemText: lineText)

      it "auto reveal for based on current line of bound-editor", ->
        text = """

          1: 1: line 1
          2: 1:   line 2
          3: 1: line 3
          4: 1:   line 4
          """
        ensureStartState = getEnsureStartState()
        ensureStartState(points[0], cursor: [1, 6], text: text, selectedItemText: "line 1")
        ensureStartState(points[1], cursor: [2, 6], text: text, selectedItemText: "  line 2")
        ensureStartState(points[2], cursor: [3, 6], text: text, selectedItemText: "line 3")
        ensureStartState(points[3], cursor: [4, 6], text: text, selectedItemText: "  line 4")

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

  describe "search", ->
    [p1, p1f1, p1f2, p1f3] = []
    [p2, p2f1, p2f2, p2f3] = []
    beforeEach ->
      runs ->
        p1 = atom.project.resolvePath("project1")
        p1f1 = path.join(p1, "p1-f1")
        p1f2 = path.join(p1, "p1-f2")
        p1f3 = path.join(p1, "p1-f3.php")
        p2 = atom.project.resolvePath("project2")
        p2f1 = path.join(p2, "p2-f1")
        p2f2 = path.join(p2, "p2-f2")
        p2f3 = path.join(p2, "p2-f3.php")

        fixturesDir = atom.project.getPaths()[0]
        atom.project.removePath(fixturesDir)
        atom.project.addPath(p1)
        atom.project.addPath(p2)

    describe "basic behavior", ->
      beforeEach ->
        waitsForStartNarrow('search', search: 'apple')

      it "preview on cursor move with skipping header", ->
        moveUpWithPreview = ->
          narrow.waitsForPreview -> runCommand('core:move-up')
        moveDownWithPreview = ->
          narrow.waitsForPreview -> runCommand('core:move-down')

        ensure
          text: """

            # project1
            ## p1-f1
            1: 8: p1-f1: apple
            ## p1-f2
            1: 8: p1-f2: apple
            # project2
            ## p2-f1
            1: 8: p2-f1: apple
            ## p2-f2
            1: 8: p2-f2: apple
            """
          cursor: [3, 13]
          selectedItemText: "p1-f1: apple"

        runs ->
          runCommand('core:move-up')
          ensure
            selectedItemText: "p1-f1: apple"
            cursor: [0, 0]

        runs -> moveDownWithPreview()

        runs ->
          ensure
            selectedItemText: "p1-f1: apple"
            cursor: [3, 13]
            filePathForProviderPane: p1f1

        runs -> moveDownWithPreview()

        runs ->
          ensure
            selectedItemText: "p1-f2: apple"
            cursor: [5, 13]
            filePathForProviderPane: p1f2
          ensureEditorIsActive(ui.editor)

        runs -> moveDownWithPreview()

        runs ->
          ensure
            selectedItemText: "p2-f1: apple"
            cursor: [8, 13]
            filePathForProviderPane: p2f1

        runs -> moveDownWithPreview()

        runs ->
          ensure
            selectedItemText: "p2-f2: apple"
            cursor: [10, 13]
            filePathForProviderPane: p2f2

      it "preview on query change by default( autoPreviewOnQueryChange )", ->
        jasmine.useRealClock()

        runs ->
          narrow.waitsForPreview ->
            ui.moveToPrompt()
            ui.editor.insertText("f2")
        runs ->
          ensure
            text: """
              f2
              # project1
              ## p1-f2
              1: 8: p1-f2: apple
              # project2
              ## p2-f2
              1: 8: p2-f2: apple
              """
            selectedItemText: "p1-f2: apple"
            filePathForProviderPane: p1f2

        runs ->
          narrow.waitsForPreview ->
            ui.editor.insertText(" p2")
        runs ->
          ensure
            text: """
              f2 p2
              # project2
              ## p2-f2
              1: 8: p2-f2: apple
              """
            selectedItemText: "p2-f2: apple"
            filePathForProviderPane: p2f2

      it "can filter files by selet-files provider", ->
        selectFiles = null

        runs ->
          ensure
            text: """

              # project1
              ## p1-f1
              1: 8: p1-f1: apple
              ## p1-f2
              1: 8: p1-f2: apple
              # project2
              ## p2-f1
              1: 8: p2-f1: apple
              ## p2-f2
              1: 8: p2-f2: apple
              """
            cursor: [3, 13]
            selectedItemText: "p1-f1: apple"

        waitsForPromise ->
          ui.selectFiles().then (_ui) ->
            selectFiles = getNarrowForUi(_ui)

        runs ->
          # Start select-files provider from search result ui.
          selectFiles.ensure
            text: """

              project1/p1-f1
              project1/p1-f2
              project2/p2-f1
              project2/p2-f2
              """

        runs ->
          # select f1
          selectFiles.ensure "f1",
            text: """
              f1
              project1/p1-f1
              project2/p2-f1
              """

        runs ->
          # then negate by ending `!`
          selectFiles.ensure "f1!",
            text: """
              f1!
              project1/p1-f2
              project2/p2-f2
              """

        runs ->
          selectFiles.waitsForDestroy -> runCommand('core:confirm')

        runs ->
          # Ensure f1 matching files are excluded and not listed in narrow-editor.
          ensureEditorIsActive(ui.editor)
          expect(ui.excludedFiles).toEqual([
            p1f1
            p2f1
          ])
          ensure
            text: """

              # project1
              ## p1-f2
              1: 8: p1-f2: apple
              # project2
              ## p2-f2
              1: 8: p2-f2: apple
              """
            cursor: [0, 0]
            selectedItemText: "p1-f2: apple"

        waitsForPromise ->
          ui.selectFiles().then (_ui) ->
            selectFiles = getNarrowForUi(_ui)

        runs ->
          # selectFiles query are remembered until closing narrow-editor.
          selectFiles.ensure
            text: """
              f1!
              project1/p1-f2
              project2/p2-f2
              """

        runs ->
          # clear the file filter query
          selectFiles.waitsForRefresh ->
            selectFiles.ui.editor.deleteToBeginningOfLine()

        runs ->
          # now all files are listable.
          selectFiles.ensure
            text: """

              project1/p1-f1
              project1/p1-f2
              project2/p2-f1
              project2/p2-f2
              """

        runs ->
          selectFiles.waitsForDestroy -> runCommand('core:confirm')

        runs ->
          # ensure items for all files are listed and previously selected items are preserveed.
          ensureEditorIsActive(ui.editor)
          expect(ui.excludedFiles).toEqual([])
          ensure
            text: """

              # project1
              ## p1-f1
              1: 8: p1-f1: apple
              ## p1-f2
              1: 8: p1-f2: apple
              # project2
              ## p2-f1
              1: 8: p2-f1: apple
              ## p2-f2
              1: 8: p2-f2: apple
              """
            cursor: [0, 0]
            selectedItemText: "p1-f2: apple"

    describe "searchCurrentWord with variable-includes-special-char language, PHP", ->
      ensureFindPHPVar = ->
        ensureEditorIsActive(ui.editor)
        expect(ui.excludedFiles).toEqual([])
        ensure
          text: """

            # project1
            ## p1-f3.php
            2: 1: $file = "p1-f3.php";
            # project2
            ## p2-f3.php
            2: 1: $file = "p2-f3.php";
            """
          cursor: [3, 6]
          selectedItemText: '$file = "p1-f3.php";'

      beforeEach ->
        waitsForPromise ->
          atom.packages.activatePackage('language-php')

        waitsForPromise ->
          atom.workspace.open(p1f3).then (phpEditor) ->
            # place cursor on `$file`
            phpEditor.setCursorBufferPosition([1, 0])

      it "[atom-scan]", ->
        waitsForStartNarrow('atom-scan', searchCurrentWord: true)
        runs -> ensureFindPHPVar()

      it "search with ag", ->
        settings.set('Search.searcher', 'ag')
        waitsForStartNarrow('search', searchCurrentWord: true)
        runs -> ensureFindPHPVar()

      it "search with rg", ->
        settings.set('Search.searcher', 'rg')
        waitsForStartNarrow('search', searchCurrentWord: true)
        runs -> ensureFindPHPVar()

    describe "search regex special char include search term", ->
      [search, ensureOptions] = []
      resultText =
        "project1/p1-f": """

            # project1
            ## p1-f1
            2: 7: path: project1/p1-f1
            ## p1-f2
            2: 7: path: project1/p1-f2
            """
        "a/b/c": """

            # project1
            ## p1-f1
            3: 7: path: a/b/c
            ## p1-f2
            3: 7: path: a/b/c
            """
        "a\\/b\\/c": """

            # project1
            ## p1-f1
            4: 7: path: a\\/b\\/c
            ## p1-f2
            4: 7: path: a\\/b\\/c
            """
      beforeEach ->
        [search, ensureOptions] = [] # null reset

      describe "search project1/p1-f", ->
        beforeEach ->
          search = 'project1/p1-f'
          ensureOptions =
            text: resultText[search]
            cursor: [3, 12]
            selectedItemText: 'path: project1/p1-f1'

        it "[atom-scan]", ->
          waitsForStartNarrow('atom-scan', {search})
          runs -> ensure(ensureOptions)

        it "[search:ag]", ->
          settings.set('Search.searcher', 'ag')
          waitsForStartNarrow('search', {search})
          runs -> ensure(ensureOptions)

        it "[search:rg]", ->
          settings.set('Search.searcher', 'rg')
          waitsForStartNarrow('search', {search})
          runs -> ensure(ensureOptions)

      describe "search a/b/c", ->
        beforeEach ->
          search = 'a/b/c'
          ensureOptions =
            text: resultText[search]
            cursor: [3, 12]
            selectedItemText: 'path: a/b/c'

        it "[atom-scan]", ->
          waitsForStartNarrow('atom-scan', {search})
          runs -> ensure(ensureOptions)

        it "[search:ag]", ->
          settings.set('Search.searcher', 'ag')
          waitsForStartNarrow('search', {search})
          runs -> ensure(ensureOptions)

        it "[search:rg]", ->
          settings.set('Search.searcher', 'rg')
          waitsForStartNarrow('search', {search})
          runs -> ensure(ensureOptions)

      describe "search a/b/c", ->
        beforeEach ->
          search = 'a\\/b\\/c'
          ensureOptions =
            text: resultText[search]
            cursor: [3, 12]
            selectedItemText: 'path: a\\/b\\/c'

        it "[atom-scan]", ->
          waitsForStartNarrow('atom-scan', {search})
          runs -> ensure(ensureOptions)

        it "[search:ag]", ->
          settings.set('Search.searcher', 'ag')
          waitsForStartNarrow('search', {search})
          runs -> ensure(ensureOptions)

        it "[search:rg]", ->
          settings.set('Search.searcher', 'rg')
          waitsForStartNarrow('search', {search})
          runs -> ensure(ensureOptions)
