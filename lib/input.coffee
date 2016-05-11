{Disposable, CompositeDisposable} = require 'atom'

# InputBase, InputElementBase
# -------------------------
class Input extends HTMLElement
  createdCallback: ->
    @innerHTML = """
      <atom-text-editor mini class="narrow-search-input"></atom-text-editor>
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
      @editorElement = @firstChild
      @editor= @editorElement.getModel()

    @finished = false
    @panel.show()
    @editorElement.focus()
    @commandSubscriptions = @handleEvents()

    # Cancel on tab switch
    disposable = atom.workspace.onDidChangeActivePaneItem =>
      disposable.dispose()
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

module.exports = document.registerElement 'narrow-search-input',
  extends: 'div'
  prototype: Input.prototype
