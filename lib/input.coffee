{CompositeDisposable, Disposable} = require 'atom'

history = require './input-history-manager'

suppressEvent = (event) ->
  event.preventDefault()
  event.stopPropagation()

RegExpStateByProvider = {}

module.exports =
class Input
  regExp: null

  constructor: (@provider) ->
    history.reset()
    @disposables = new CompositeDisposable()

    @container = document.createElement('div')
    @container.className = 'narrow-input-container'
    @editor = atom.workspace.buildTextEditor(mini: true)
    @editorElement = @editor.element
    @editorElement.classList.add('narrow-input')

    atom.commands.add @editorElement,
      'narrow-input:toggle-regexp': => @toggleRegExp()

    @container.innerHTML = """
      <div class='options-container'>
        <span class='regex-search inline-block-tight btn'>.*</span>
      </div>
      <div class='editor-container'>
      </div>
      """

    editorContainer = @container.getElementsByClassName('editor-container')[0]
    editorContainer.appendChild(@editorElement)

    @regExpButton = @container.getElementsByClassName('regex-search')[0]
    @regExpButton.addEventListener('click', @toggleRegExp)
    @editorElement.addEventListener('click', suppressEvent)
    @regExp = RegExpStateByProvider[@provider.name] ? true
    @updateRegExpButton()

  toggleRegExp: (event) =>
    suppressEvent(event) if event?
    @regExp = not @regExp
    @updateRegExpButton()

  updateRegExpButton: ->
    @regExpButton.classList.toggle('btn-primary', @regExp)

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
      text: "\\s*desc"
      # text: @editor.getText()
      isRegExp: @regExp
    RegExpStateByProvider[@provider.name] = @regExp
    @provider = null
    @resolve(result)
    @destroy()
