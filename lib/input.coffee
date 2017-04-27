{CompositeDisposable, Disposable} = require 'atom'

history = require './input-history-manager'

suppressEvent = (event) ->
  event.preventDefault()
  event.stopPropagation()

module.exports =
class Input
  regExp: false

  constructor: ->
    history.reset()
    @disposables = new CompositeDisposable()

    @container = document.createElement('div')
    @container.className = 'narrow-input-container'
    @editor = atom.workspace.buildTextEditor(mini: true)
    @editorElement = @editor.element
    @editorElement.classList.add('narrow-input')

    @container.innerHTML = """
      <div class='options-container'>
        <span class='regex-search inline-block-tight btn'>.*</span>
      </div>
      <div class='editor-container'>
      </div>
      """

    editorContainer = @container.getElementsByClassName('editor-container')[0]
    editorContainer.appendChild(@editorElement)

    @regexButton = @container.getElementsByClassName('regex-search')[0]
    @regexButton.classList.toggle('btn-primary', @regExp)

    @regexButton.addEventListener('click', @toggleRegExp)
    @editorElement.addEventListener('click', suppressEvent)

  toggleRegExp: (event) =>
    suppressEvent(event)
    @regExp = not @regExp
    @regexButton.classList.toggle('btn-primary', @regExp)

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

    destroy = @destroy.bind(this)
    @disposables.add atom.workspace.onDidChangeActivePaneItem(destroy)

    # Cancel on mouse click
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.addEventListener('click', destroy)
    @disposables.add new Disposable ->
      workspaceElement.removeEventListener('click', destroy)

    @editorElement.focus()
    new Promise (@resolve) =>

  confirm: ->
    result =
      text: @editor.getText()
      isRegExp: @regExp
    @resolve(result)
    @destroy()
