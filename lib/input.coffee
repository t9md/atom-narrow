{Disposable, CompositeDisposable} = require 'atom'
{registerElement} = require './utils'

# InputBase, InputElementBase
# -------------------------
class Input extends HTMLElement
  createdCallback: ->
    @innerHTML = """
    <div class='narrow-search-container'>
      <atom-text-editor mini id="narrow-search-input"></atom-text-editor>
    </div>
    """
    @panel = atom.workspace.addBottomPanel(item: this, visible: false)
    this

  destroy: ->
    @editor.destroy()
    @panel?.destroy()
    {@editor, @panel, @editorElement} = {}
    @remove()

  handleEvents: ->
    atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'core:cancel': => @cancel()
      'blur': => @cancel() unless @finished

  readInput: ->
    unless @editorElement
      @editorElement = document.getElementById("narrow-search-input")
      @editor = @editorElement.getModel()

    @finished = false
    @panel.show()
    @editorElement.focus()
    @commandSubscriptions = @handleEvents()

    # Cancel on tab switch
    disposable = atom.workspace.onDidChangeActivePaneItem =>
      disposable?.dispose()
      @cancel() unless @finished

    new Promise (resolve) =>
      @resolve = resolve

  confirm: ->
    @resolve(@editor.getText())
    @cancel()

  cancel: ->
    @commandSubscriptions?.dispose()
    @resolve = null
    @finished = true
    atom.workspace.getActivePane().activate()
    @editor.setText ''
    @panel?.hide()

module.exports = registerElement 'narrow-search-input',
  prototype: Input.prototype
