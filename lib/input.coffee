{CompositeDisposable, Disposable} = require 'atom'

module.exports =
class Input
  constructor: ->
    @disposables = new CompositeDisposable()

    @container = document.createElement('div')
    @container.className = 'narrow-input-container'
    @editor = atom.workspace.buildTextEditor(mini: true)
    @editorElement = @editor.element
    @editorElement.classList.add('narrow-input')
    @container.appendChild(@editorElement)

  destroy: ->
    return if @destroyed
    @destroyed = true
    @editor.destroy()
    @panel.destroy()
    @disposables.dispose()
    atom.workspace.getActivePane().activate()

  readInput: ->
    @panel = atom.workspace.addBottomPanel(item: @container, visible: true)
    @disposables.add atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'core:cancel': => @destroy()

    @disposables.add atom.workspace.onDidChangeActivePaneItem(@destroy)

    # Cancel on mouse click
    destroy = @destroy.bind(this)
    clientEditorElement = atom.workspace.getActiveTextEditor().element
    clientEditorElement.addEventListener('click', destroy)
    @disposables.add new Disposable ->
      clientEditorElement.removeEventListener('click', destroy)

    @editorElement.focus()
    new Promise (@resolve) =>

  confirm: ->
    @resolve(@editor.getText())
    @destroy()
