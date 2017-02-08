{CompositeDisposable} = require 'atom'

toggleSelected = (element, bool) ->
  element.classList.toggle('selected', bool)

module.exports =
class ProviderInformation
  constructor: (@ui) ->
    {@editor, @provider} = @ui
    @container = document.createElement('div')
    @container.className = 'narrow-provider-information'
    @container.innerHTML = """
    <div class='block'>
      <span class='icon icon-eye-watch'></span>
      <span class='provider-name'>#{@provider.getDashName()}</span>
      <span class='item-counter'>0</span>
      <div class='btn-group btn-group-xs'>
        <button class='btn'>Aa</button>
        <button class='btn'>\\b</button>
      </div>
      <span class='search-term'></span>
      <span class='loading loading-spinner-tiny inline-block'></span>
    </div>
    """

    loadingElement = @container.getElementsByClassName('loading')[0]
    itemCountElement = @container.getElementsByClassName('item-counter')[0]
    @searchTermElement = @container.getElementsByClassName('search-term')[0]

    @ui.onWillRefresh ->
      loadingElement.classList.remove('hide')

    @ui.onDidRefresh =>
      itemCountElement.textContent = @ui.getNormalItems().length
      loadingElement.classList.add('hide')

    @ui.grammar.onDidChangeSearchTerm (regexp) =>
      @searchTermElement.textContent = regexp?.toString() ? ''

    [@ignoreCaseButton, @wholeWordButton] = @container.getElementsByTagName('button')
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
    @updateOptionState()
    @activateToolTips()

  updateOptionState: ->
    toggleSelected(@ignoreCaseButton, @provider.searchIgnoreCase)
    toggleSelected(@wholeWordButton, @provider.searchWholeWord)

  toggleSearchIgnoreCase: => @ui.toggleSearchIgnoreCase()
  toggleSearchWholeWord: => @ui.toggleSearchWholeWord()

  activateToolTips: ->
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
