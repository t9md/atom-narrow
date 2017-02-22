Ui = require '../lib/ui'

narrow = (providerName, options) ->
  klass = require("../lib/provider/#{providerName}")
  editor = atom.workspace.getActiveTextEditor()
  new klass(editor, options)

# Main
# -------------------------
describe "narrow", ->
  [editor, editorElement, main] = []
  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('narrow').then (pack) ->
        main = pack.mainModule

    waitsForPromise ->
      atom.workspace.open().then (_editor) ->
        editor = _editor
        editorElement = editor.element

  describe "from internal", ->
    [provider, ui, narrowEditor, narrowEditorElement] = []

    describe "scan", ->
      [waitsForRefresh, ensureNarrowEditor, refreshHandler] = []

      waitsForRefresh = (fn) ->
        refreshHandler.reset()
        fn()
        waitsFor ->
          refreshHandler.callCount > 0

      ensureNarrowEditor = (args...) ->
        runs ->
          switch args.length
            when 1 then [options] = args
            when 2 then [query, options] = args

          if query?
            waitsForRefresh ->
              ui.setQuery(query)

          runs ->
            if options.itemsCount?
              expect(ui.items.getCount()).toBe(options.itemsCount)

            if options.selectedItemRow?
              expect(ui.items.getRowForSelectedItem()).toBe(options.selectedItemRow)

            if options.text?
              expect(narrowEditor.getText()).toBe(options.text)

            if options.cursor?
              expect(narrowEditor.getCursorBufferPosition()).toEqual(options.cursor)

      describe "start with empty qury", ->
        beforeEach ->
          refreshHandler = jasmine.createSpy("refreshHandler")

          editor.setText """
            apple
            grape
            lemmon
            """

          runs ->
            provider = narrow('scan')

          waitsForPromise ->
            provider.start()

          runs ->
            ui = provider.ui
            narrowEditor = ui.editor
            narrowEditorElement = ui.editorElement
            ui.onDidRefresh(refreshHandler)

        it "add css class to narrowEditorElement", ->
          expect(narrowEditorElement.classList.contains('narrow')).toBe(true)
          expect(narrowEditorElement.classList.contains('narrow-editor')).toBe(true)
          expect(narrowEditorElement.classList.contains('scan')).toBe(true)

        it "narrowEditor", ->
          ensureNarrowEditor
            text: """

            1: 1: apple
            2: 1: grape
            3: 1: lemmon
            """

        it "filter by query", ->
          ensureNarrowEditor "app",
            text: """
              app
              1: 1: apple
              """
            itemsCount:1
            selectedItemRow: 1

          ensureNarrowEditor "r",
            text: """
              r
              2: 2: grape
              """
            selectedItemRow: 1
            itemsCount: 1

          ensureNarrowEditor "l",
            text: """
              l
              1: 4: apple
              3: 1: lemmon
              """
            selectedItemRow: 1
            itemsCount: 2

  xdescribe "integrated narrow:scan", ->
    [refreshHandler, narrowEditor] = []

    beforeEach ->
      refreshHandler = jasmine.createSpy("refreshHandler")
      editor.setText """
        apple
        grape
        lemmon
        """

    it "open narrow-editor", ->
      runs ->
        expect(atom.workspace.getTextEditors()).toHaveLength(1)
        atom.commands.dispatch(editorElement, "narrow:scan")

      waitsFor ->
        Ui.uiByEditor.size > 0

      runs ->
        expect(atom.workspace.getTextEditors()).toHaveLength(2)
        narrowEditor = atom.workspace.getActiveTextEditor()
        ui = Ui.get(atom.workspace.getActiveTextEditor())
        narrowEditorElement = ui.editorElement
        ui.onDidRefresh(refreshHandler)

        expect(narrowEditorElement.classList.contains('narrow')).toBe(true)
        expect(narrowEditorElement.classList.contains('narrow-editor')).toBe(true)
        expect(narrowEditorElement.classList.contains('scan')).toBe(true)
        expect(narrowEditor.getText()).toBe """

          1: 1: apple
          2: 1: grape
          3: 1: lemmon
          """
        expect(narrowEditor.getCursorBufferPosition()).toEqual([0, 0])

      runs ->
        narrowEditor.insertText("a")

      waitsFor ->
        refreshHandler.callCount > 0

      runs ->
        expect(narrowEditor.getText()).toBe """
          a
          1: 1: apple
          2: 3: grape
          """

      runs ->
        refreshHandler.reset()
        narrowEditor.insertText("pp")

      waitsFor ->
        refreshHandler.callCount > 0

      runs ->
        expect(narrowEditor.getText()).toBe """
          app
          1: 1: apple
          """

      runs ->
        refreshHandler.reset()
        narrowEditor.deleteToBeginningOfLine()

      waitsFor ->
        refreshHandler.callCount > 0

      runs ->
        expect(narrowEditor.getText()).toBe """

          1: 1: apple
          2: 1: grape
          3: 1: lemmon
          """
