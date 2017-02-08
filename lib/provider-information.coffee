{CompositeDisposable} = require 'atom'

toggleSelected = (element, bool) ->
  element.classList.toggle('selected', bool)

module.exports =
class ProviderInformation
  constructor: (@ui) ->
    {@editor, @provider} = @ui
    @disposables = new CompositeDisposable

    @container = document.createElement('div')
    @container.className = 'narrow-provider-information'
    @container.innerHTML = """
    <div class='block'>
      <span class='loading loading-spinner-tiny inline-block'></span>
      <span class='provider-name'>#{@provider.getDashName()}</span>
      <span class='item-counter'>0</span>
      <div class='btn-group btn-group-xs'>
        <button class='btn'>Aa</button>
        <button class='btn'>\\b</button>
      </div>
      <span class='search-term'></span>
    </div>
    """

    loadingElement = @container.getElementsByClassName('loading')[0]
    itemCountElement = @container.getElementsByClassName('item-counter')[0]
    @searchTermElement = @container.getElementsByClassName('search-term')[0]
    willRefreshClassName = 'search-progress loading loading-spinner-tiny inline-block'
    didRefreshClassName = 'search-progress ready icon icon-eye-watch'
    @ui.onWillRefresh ->
      loadingElement.className = willRefreshClassName
    @ui.onDidRefresh =>
      itemCountElement.textContent = @ui.getNormalItems().length
      loadingElement.className = didRefreshClassName

    @ui.grammar.onDidChangeSearchTerm (regexp) =>
      @searchTermElement.textContent = regexp?.toString() ? ''

    [@ignoreCaseButton, @wholeWordButton] = @container.getElementsByTagName('button')
    @ignoreCaseButton.addEventListener('click', @toggleSearchIgnoreCase)
    @wholeWordButton.addEventListener('click', @toggleSearchWholeWord)

  destroy: ->
    @disposables.destroy()
    @marker?.destroy()

  show: ->
    @editor.decorateMarker @editor.markBufferPosition([0, 0]),
      type: 'block'
      item: @container
      position: 'before'
    @updateOptionState()
    @activateToolTips()

  updateOptionState: ->
    toggleSelected(@ignoreCaseButton, @provider.searchIgnoreCase)
    toggleSelected(@wholeWordButton, @provider.searchWholeWord)

  toggleSearchIgnoreCase: => @ui.toggleSearchIgnoreCase()
  toggleSearchWholeWord: => @ui.toggleSearchWholeWord()

  activateToolTips: ->
    @disposables.add atom.tooltips.add @wholeWordButton,
      title: "wholeWord"
      keyBindingCommand: 'narrow-ui:toggle-search-whole-word'
      keyBindingTarget: @ui.editorElement

    @disposables.add atom.tooltips.add @ignoreCaseButton,
      title: "ignoreCase"
      keyBindingCommand: 'narrow-ui:toggle-search-ignore-case'
      keyBindingTarget: @ui.editorElement
