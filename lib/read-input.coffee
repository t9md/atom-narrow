{CompositeDisposable, Disposable} = require 'atom'

history = require './input-history-manager'
{addToolTips} = require './utils'

suppressEvent = (event) ->
  event.preventDefault()
  event.stopPropagation()

class Input
  useRegex: null

  constructor: ->
    history.reset()
    @disposables = new CompositeDisposable()

    @container = document.createElement('div')
    @container.className = 'narrow-input-container'
    @editor = atom.workspace.buildTextEditor(mini: true)
    @editorElement = @editor.element
    @editorElement.classList.add('narrow-input')

    atom.commands.add @editorElement,
      'narrow-input:toggle-use-regex': => @toggleUseRegex()

    @container.innerHTML = """
      <div class='options-container'>
        <span class='use-regex inline-block-tight btn'>.*</span>
      </div>
      <div class='editor-container'>
      </div>
      """

    editorContainer = @container.getElementsByClassName('editor-container')[0]
    editorContainer.appendChild(@editorElement)

    @useRegexButton = @container.getElementsByClassName('use-regex')[0]
    @useRegexButton.addEventListener 'click', (event) =>
      suppressEvent(event)
      @toggleUseRegex()
    @container.addEventListener('click', suppressEvent)
    addToolTips(
      element: @useRegexButton
      commandName: 'narrow-input:toggle-use-regex'
      keyBindingTarget: @editorElement
    )

  toggleUseRegex: ->
    @updateUseRegexButton(@useRegex = not @useRegex)

  updateUseRegexButton: (value) ->
    @useRegexButton.classList.toggle('btn-primary', value)

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
      @updateUseRegexButton(@useRegex = entry.useRegex)
      @editor.setText(entry.text)

  readInput: (@useRegex) ->
    @updateUseRegexButton(@useRegex)

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
      useRegex: @useRegex
    )
    @destroy()

readInput = (args...) ->
  new Input().readInput(args...)

module.exports = readInput
