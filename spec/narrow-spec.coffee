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

  describe "unit narrow:scan", ->
    [provider, ui, narrowEditor, narrowEditorElement] = []

    describe "integrated narrow:scan", ->
      [provider, ui] = []
      describe "start with empty qury", ->
        beforeEach ->
          runs ->
            provider = narrow('scan')

          waitsForPromise ->
            provider.start()

          runs ->
            ui = provider.ui
            narrowEditor = ui.editor
            narrowEditorElement = ui.editorElement

        it "c", ->
          expect(narrowEditorElement.classList.contains('narrow')).toBe(true)
          expect(narrowEditorElement.classList.contains('narrow-editor')).toBe(true)
          expect(narrowEditorElement.classList.contains('scan')).toBe(true)

  describe "integrated narrow:scan", ->
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
