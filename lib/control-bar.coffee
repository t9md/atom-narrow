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
      <div class='search-options inline-block'>
        <div class='btn-group btn-group-xs'>
          <button class='btn search-ignore-case'>Aa</button>
          <button class='btn search-whole-word'>\\b</button>
          <button class='btn search-use-regex'>.*</button>
        </div>
        <span class='search-regex'></span>
      </div>
      """

    # NOTE: Avoid mousedown event propagated up to belonging narrow-editor's element
    # If propagated, button clicking cause narrow-editor's cursor move etc See #123.
    @container.addEventListener('mousedown', suppressEvent)
    # @toolTipDisposables = new CompositeDisposable
    keyBindingTarget = @editorElement
    @toolTipsSpecs = []

    elementFor = (name, {click, hideIf, selected, tips}={}) =>
      element = @container.getElementsByClassName(name)[0]
      if click
        element.addEventListener('click', click)
      if hideIf
        element.style.display = 'none'
      if selected
        element.classList.toggle('selected')
      if tips
        @toolTipsSpecs.push({element, commandName: tips, keyBindingTarget})
      element

    @elements =
      autoPreview: elementFor 'auto-preview',
        click: @ui.toggleAutoPreview
        tips: "narrow-ui:toggle-auto-preview"
        selected: @ui.autoPreview
      protected: elementFor 'protected',
        click: @ui.toggleProtected
        tips: "narrow-ui:protect"
        selected: @ui.protected
      refresh: elementFor 'refresh',
        click: @ui.refreshManually
        tips: "narrow:refresh"
      itemCount: elementFor 'item-count'
      selectFiles: elementFor 'select-files',
        click: @ui.selectFiles,
        hideIf: @provider.boundToSingleFile
        tips: "narrow-ui:select-files"
      searchIgnoreCase: elementFor 'search-ignore-case',
        click: @ui.toggleSearchIgnoreCase
        tips: "narrow-ui:toggle-search-ignore-case"
      searchWholeWord: elementFor 'search-whole-word',
        click: @ui.toggleSearchWholeWord
        tips: "narrow-ui:toggle-search-whole-word"
      searchUseRegex: elementFor 'search-use-regex',
        click: @ui.toggleSearchUseRegex
        tips: "narrow-ui:toggle-search-use-regex"
      searchRegex: elementFor 'search-regex'

    elementFor('search-options', hideIf: not @showSearchOption)

  destroy: ->
    @toolTipDisposables?.dispose()
    @marker?.destroy()

  # Can be called multiple times
  # Why? When narrow-editor's prompt row itself was removed, need to redraw to recover.
  show: ->
    @marker?.destroy()
    @marker = @editor.markBufferPosition([0, 0])
    @editor.decorateMarker(@marker, type: 'block', item: @container, position: 'before')

    unless @toolTipDisposables?
      @toolTipDisposables = new CompositeDisposable
      for toolTipsSpec in @toolTipsSpecs
        @toolTipDisposables.add(addToolTips(toolTipsSpec))

  updateElements: (states) ->
    for elementName, value of states when element = @elements[elementName]
      switch elementName
        when 'itemCount'
          element.textContent = value
        when 'searchRegex'
          if value?
            element.textContent = value.toString()
            invalid = false
          else
            element.textContent = states.searchTerm
            invalid = states.searchTerm.length isnt 0
          element.classList.toggle('invalid', invalid)
        when 'refresh'
          element.classList.toggle('running', value)
        else
          element.classList.toggle('selected', value)
