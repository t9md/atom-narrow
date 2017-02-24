{CompositeDisposable, Disposable} = require 'atom'

history = new (require './input-history-manager')

module.exports =
class Input
  constructor: ->
    history.reset()
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

  setPrevious: ->
    @editor.setText(history.get('previous'))

  setNext: ->
    @editor.setText(history.get('next'))

  readInput: ->
    @panel = atom.workspace.addBottomPanel(item: @container, visible: true)
    @disposables.add atom.commands.add @editorElement,
      'core:confirm': => @confirm()
      'core:cancel': => @destroy()
      'core:move-up': => @setPrevious()
      'core:move-down': => @setNext()

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
    text = @editor.getText()
    history.save(text)
    @resolve(text)
    @destroy()
