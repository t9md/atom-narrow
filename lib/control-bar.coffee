{CompositeDisposable} = require 'atom'
{addToolTips, suppressEvent} = require './utils'


# This is NOT Panel in Atom's terminology, Just naming.
module.exports =
class ControlBar
  constructor: (@ui) ->
    {@editor, @editorElement, @provider, @showSearchOption} = @ui

    @container = document.createElement('div')
    @container.className = 'narrow-control-bar'
    @container.innerHTML = """
      <div class='base inline-block'>
        <a class='auto-preview'></a>
        <span class='provider-name'>#{@provider.dashName}</span>
        <span class='item-count'>0</span>
        <a class='refresh'></a>
        <a class='protected'></a>
        <a class='select-files'></a>
      </div>
      <div class='btn-group btn-group-xs'>
        <button class='btn search-ignore-case'>Aa</button>
        <button class='btn search-whole-word'>\\b</button>
        <button class='btn search-use-regex'>.*</button>
      </div>
      <span class='search-regex'></span>
      """

    # NOTE: Avoid mousedown event propagated up to belonging narrow-editor's element
    # If propagated, button clicking cause narrow-editor's cursor move etc See #123.
    @container.addEventListener('mousedown', suppressEvent)

    elementFor = (name) => @container.getElementsByClassName(name)[0]
    hideElement = (name) => @elements[name].style.display = 'none'

    @elements =
      autoPreview: elementFor('auto-preview')
      protected: elementFor('protected')
      refresh: elementFor('refresh')
      itemCount: elementFor('item-count')
      selectFiles: elementFor('select-files')
      searchIgnoreCase: elementFor('search-ignore-case')
      searchWholeWord: elementFor('search-whole-word')
      searchUseRegex: elementFor('search-use-regex')
      searchRegex: elementFor('search-regex')

    if @provider.boundToSingleFile
      hideElement('selectFiles')

    unless @showSearchOption
      for elementName in ['searchIgnoreCase', 'searchWholeWord', 'searchUseRegex', 'searchRegex']
        hideElement(elementName)

    @addClickEvents()

  addClickEvents: ->
    clickEvents =
      autoPreview: @ui.toggleAutoPreview
      protected: @ui.toggleProtected
      refresh: @ui.refreshManually
      selectFiles: @ui.selectFiles
      searchIgnoreCase: @ui.toggleSearchIgnoreCase
      searchWholeWord: @ui.toggleSearchWholeWord
      searchUseRegex: @ui.toggleSearchUseRegex

    for elementName, fn of clickEvents when element = @elements[elementName]
      element.addEventListener('click', fn)

  destroy: ->
    @toolTipDisposables?.dispose()
    @marker?.destroy()

  # Can be called multiple times
  # Why? When narrow-editor's prompt row itself was removed, need to redraw to recover.
  show: ->
    @marker?.destroy()
    @marker = @editor.markBufferPosition([0, 0])
    @editor.decorateMarker(@marker, type: 'block', item: @container, position: 'before')

    @toolTipDisposables ?= @addToolTips()

    @updateElements
      autoPreview: @ui.autoPreview
      protected: @ui.protected

  updateElements: (states) ->
    for elementName, value of states when element = @elements[elementName]
      switch elementName
        when 'itemCount'
          element.textContent = value
        when 'searchRegex'
          element.textContent = value?.toString() ? ''
        when 'refresh'
          element.classList.toggle('running', value)
        else
          element.classList.toggle('selected', value)

  addToolTips: ->
    tooltips =
      autoPreview: "narrow-ui:toggle-auto-preview"
      protected: "narrow-ui:protect"
      refresh: "narrow:refresh"
      selectFiles: "narrow-ui:select-files"
      searchWholeWord: "narrow-ui:toggle-search-whole-word"
      searchIgnoreCase: "narrow-ui:toggle-search-ignore-case"
      searchUseRegex: "narrow-ui:toggle-search-use-regex"

    disposables = new CompositeDisposable
    keyBindingTarget = @editorElement
    for elementName, commandName of tooltips when element = @elements[elementName]
      disposables.add(addToolTips({element, commandName, keyBindingTarget}))
    disposables
