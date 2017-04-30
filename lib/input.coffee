{CompositeDisposable, Disposable} = require 'atom'

history = require './input-history-manager'
{addToolTips} = require './utils'

suppressEvent = (event) ->
  event.preventDefault()
  event.stopPropagation()

module.exports =
class Input
  regExp: null

  constructor: ->
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
    @regExpButton.addEventListener 'click', (event) ->
      suppressEvent(event)
      @toggleRegExp()
    @editorElement.addEventListener('click', suppressEvent)
    addToolTips(
      element: @regExpButton
      commandName: 'narrow-input:toggle-regexp'
      keyBindingTarget: @editorElement
    )

  toggleRegExp: ->
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
    @recallHistory('previous')

  setNext: ->
    @recallHistory('next')

  recallHistory: (direction) ->
    if entry = history.get(direction)
      @regExp = entry.isRegExp
      @updateRegExpButton()
      @editor.setText(entry.text)

  readInput: (@regExp) ->
    @updateRegExpButton()

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
    @provider = null
    @resolve(
      text: @editor.getText()
      isRegExp: @regExp
    )
    @destroy()
