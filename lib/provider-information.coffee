toggleSelected = (element, bool) ->
  element.classList.toggle('selected', bool)

module.exports =
class ProviderInformation
  constructor: (@ui) ->
    {@editor, @provider} = @ui

    @container = document.createElement('div')
    @container.className = 'narrow-provider-information'
    # <span class='loading loading-spinner-tiny inline-block'></span>
      # <span class='eye icon icon-eye-watch'></span>
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

    @ui.grammar.onDidChangeSearchTerm (source) =>
      @searchTermElement.textContent = source

    [@ignoreCaseButton, @wholeWordButton] = @container.getElementsByTagName('button')
    @ignoreCaseButton.addEventListener('click', @toggleSearchIgnoreCase)
    @wholeWordButton.addEventListener('click', @toggleSearchWholeWord)

  toggleSearchIgnoreCase: => @ui.toggleSearchIgnoreCase()
  toggleSearchWholeWord: => @ui.toggleSearchWholeWord()

  updateOptionState: ->
    toggleSelected(@ignoreCaseButton, @provider.searchIgnoreCase)
    toggleSelected(@wholeWordButton, @provider.searchWholeWord)

  show: ->
    @editor.decorateMarker @editor.markBufferPosition([0, 0]),
      type: 'block'
      item: @container
      position: 'before'
    @updateOptionState()

  destroy: ->
    @marker?.destroy()
