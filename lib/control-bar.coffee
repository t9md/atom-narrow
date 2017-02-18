{CompositeDisposable} = require 'atom'

suppressEvent = (event) ->
  event.preventDefault()
  event.stopPropagation()

# This is NOT Panel in Atom's terminology, Just naming.
module.exports =
class ControlBar
  constructor: (@ui, {@showSearchOption}={}) ->
    {@editor, @provider} = @ui
    @stateElements = {}
    @container = document.createElement('div')
    @container.className = 'narrow-provider-panel'
    @container.innerHTML = """
      <div class='base inline-block'>
        <a class='auto-preview'></a>
        <span class='provider-name'>#{@provider.dashName}</span>
        <span class='item-counter'>0</span>
        <a class='refresh'></a>
        <a class='protected'></a>
      </div>
      """

    # NOTE: Avoid mousedown event propagated up to belonging narrow-editor's element
    # If propagated, button clicking cause narrow-editor's cursor move etc See #123.
    @container.addEventListener('mousedown', suppressEvent)

    # autoPreview
    # -------------------------
    @stateElements.autoPreview = @container.getElementsByClassName('auto-preview')[0]
    @stateElements.protected = @container.getElementsByClassName('protected')[0]
    @stateElements.autoPreview.addEventListener('click', @toggleAutoPreview)
    @stateElements.protected.addEventListener('click', @toggleProtected)

    itemCountElement = @container.getElementsByClassName('item-counter')[0]
    @ui.onDidRefresh =>
      itemCountElement.textContent = @ui.items.getCount()

    # loading
    refreshElement = @container.getElementsByClassName('refresh')[0]
    refreshElement.addEventListener('click', @refresh)

    @ui.onWillRefresh ->
      refreshElement.classList.add('running')
    @ui.onDidRefresh ->
      refreshElement.classList.remove('running')

    if @showSearchOption
      @setupSearchOption()

  setupSearchOption: ->
    element = document.createElement('div')
    element.classList.add('search-options', 'block')
    element.innerHTML = """
      <div class='btn-group btn-group-xs'>
        <button class='btn'>Aa</button>
        <button class='btn'>\\b</button>
      </div>
      <span class='search-term'></span>
      """
    @container.appendChild(element)

    # searchTerm
    searchTermElement = element.getElementsByClassName('search-term')[0]
    @ui.grammar.onDidChangeSearchTerm (regexp) ->
      searchTermElement.textContent = regexp?.toString() ? ''

    # searchOptions
    [ignoreCaseButton, wholeWordButton] = element.getElementsByTagName('button')
    @stateElements.ignoreCaseButton = ignoreCaseButton
    @stateElements.wholeWordButton = wholeWordButton
    ignoreCaseButton.addEventListener('click', @toggleSearchIgnoreCase)
    wholeWordButton.addEventListener('click', @toggleSearchWholeWord)

  destroy: ->
    @toolTipDisposables?.dispose()
    @marker?.destroy()

  # Can be called multiple times
  # Why? When narrow-editor's prompt row itself was removed, need to redraw to recover.
  show: ->
    @marker?.destroy()
    @marker = @editor.markBufferPosition([0, 0])
    @editor.decorateMarker(@marker, type: 'block', item: @container, position: 'before')

    if @showSearchOption
      @activateSearchOptionButtonToolTips()
    @syncStateElements()

  syncStateElements: ->
    states =
      autoPreview: @ui.autoPreview
      protected: @ui.protected

    if @showSearchOption
      states.ignoreCaseButton = @provider.searchIgnoreCase
      states.wholeWordButton = @provider.searchWholeWord
    @updateStateElements(states)

  updateStateElements: (states) ->
    for state, value of states
      @stateElements[state].classList.toggle('selected', value)

  refresh: (event) =>
    suppressEvent(event)
    @ui.refreshManually(force: true)

  toggleProtected: (event) =>
    suppressEvent(event)
    @ui.toggleProtected()

  toggleAutoPreview: (event) =>
    suppressEvent(event)
    @ui.toggleAutoPreview()

  toggleSearchIgnoreCase: (event) =>
    suppressEvent(event)
    @ui.toggleSearchIgnoreCase()

  toggleSearchWholeWord: (event) =>
    suppressEvent(event)
    @ui.toggleSearchWholeWord()

  activateSearchOptionButtonToolTips: ->
    @toolTipDisposables?.dispose()
    @toolTipDisposables = disposables = new CompositeDisposable

    disposables.add atom.tooltips.add @stateElements.wholeWordButton,
      title: "wholeWord"
      keyBindingCommand: 'narrow-ui:toggle-search-whole-word'
      keyBindingTarget: @ui.editorElement

    disposables.add atom.tooltips.add @stateElements.ignoreCaseButton,
      title: "ignoreCase"
      keyBindingCommand: 'narrow-ui:toggle-search-ignore-case'
      keyBindingTarget: @ui.editorElement
