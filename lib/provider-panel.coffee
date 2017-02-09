{CompositeDisposable} = require 'atom'

toggleSelected = (element, bool) ->
  element.classList.toggle('selected', bool)

suppressEvent: (event) ->
  event.preventDefault()
  event.stopPropagation()

# This is NOT Panel in Atom's terminology, Just naming.
module.exports =
class ProviderPanel
  constructor: (@ui, {@showSearchOption}={}) ->
    {@editor, @provider} = @ui
    @container = document.createElement('div')
    @container.className = 'narrow-provider-panel'
    @container.innerHTML = """
      <div class='base inline-block'>
        <span class='icon icon-eye-watch'></span>
        <span class='provider-name'>#{@provider.getDashName()}</span>
        <span class='item-counter'>0</span>
      </div>
      """

    itemCountElement = @container.getElementsByClassName('item-counter')[0]
    @ui.onDidRefresh =>
      itemCountElement.textContent = @ui.getNormalItems().length

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
      <span class='loading loading-spinner-tiny inline-block'></span>
      """
    @container.appendChild(element)

    # loading
    loadingElement = element.getElementsByClassName('loading')[0]
    @ui.onWillRefresh -> loadingElement.classList.remove('hide')
    @ui.onDidRefresh -> loadingElement.classList.add('hide')

    # searchTerm
    searchTermElement = element.getElementsByClassName('search-term')[0]
    @ui.grammar.onDidChangeSearchTerm (regexp) ->
      searchTermElement.textContent = regexp?.toString() ? ''

    # NOTE: Avoid mousedown event propagated up to belonging narrow-editor's element
    # If propagated, button clicking cause narrow-editor's cursor move etc See #123.
    @container.addEventListener('mousedown', suppressEvent)

    # searchOptions
    [@ignoreCaseButton, @wholeWordButton] = element.getElementsByTagName('button')
    @ignoreCaseButton.addEventListener('click', @toggleSearchIgnoreCase)
    @wholeWordButton.addEventListener('click', @toggleSearchWholeWord)

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
      @updateSearchOptionState()
      @activateSearchOptionButtonToolTips()

  updateSearchOptionState: ->
    toggleSelected(@ignoreCaseButton, @provider.searchIgnoreCase)
    toggleSelected(@wholeWordButton, @provider.searchWholeWord)

  toggleSearchIgnoreCase: (event) =>
    suppressEvent(event)
    @ui.toggleSearchIgnoreCase()

  toggleSearchWholeWord: (event) =>
    suppressEvent(event)
    @ui.toggleSearchWholeWord()

  activateSearchOptionButtonToolTips: ->
    @toolTipDisposables?.dispose()
    @toolTipDisposables = disposables = new CompositeDisposable

    disposables.add atom.tooltips.add @wholeWordButton,
      title: "wholeWord"
      keyBindingCommand: 'narrow-ui:toggle-search-whole-word'
      keyBindingTarget: @ui.editorElement

    disposables.add atom.tooltips.add @ignoreCaseButton,
      title: "ignoreCase"
      keyBindingCommand: 'narrow-ui:toggle-search-ignore-case'
      keyBindingTarget: @ui.editorElement
