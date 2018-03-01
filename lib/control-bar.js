const {CompositeDisposable} = require('atom')
const {suppressEvent} = require('./utils')
const _ = require('underscore-plus')

// ControlBar is small tool-bar which resides at top of narror-editor.
// A control-bar is embededde to narrow-editor by block decoration.
module.exports = class ControlBar {
  constructor (ui) {
    this.ui = ui
    this.element = document.createElement('div')
    this.element.className = 'narrow-control-bar'
    this.element.innerHTML = `\
      <div class='base inline-block'>
        <a class='auto-preview'></a>
        <a class='provider-name'>${this.ui.provider.dashName}</a>
        <span class='item-count'>0</span>
        <a class='refresh'></a>
        <a class='protected'></a>
        <a class='select-files'></a>
        <a class='inline-git-diff'></a>
      </div>
      <div class='search-options inline-block'>
        <div class='btn-group btn-group-xs'>
          <button class='btn search-ignore-case'>Aa</button>
          <button class='btn search-whole-word'>\\b</button>
          <button class='btn search-use-regex'>.*</button>
        </div>
        <span class='search-regex'></span>
      </div>\
      `

    // NOTE: Avoid mousedown event propagated up to belonging narrow-editor's element
    // If propagated, button clicking cause narrow-editor's cursor move etc See #123.
    this.element.addEventListener('mousedown', suppressEvent)

    const keyBindingTarget = this.ui.editorElement
    this.toolTipsSpecs = []

    const setElement = (name, {click, hideIf, selected, tips, command} = {}) => {
      const element = this.element.getElementsByClassName(name)[0]
      if (command) {
        click = event => {
          suppressEvent(event)
          atom.commands.dispatch(keyBindingTarget, command)
        }
        tips = command
      }
      if (click) element.addEventListener('click', click)
      if (hideIf) element.style.display = 'none'
      if (selected) element.classList.add('selected')
      if (tips) this.toolTipsSpecs.push({element, commandName: tips, keyBindingTarget})
      return element
    }

    this.elements = {
      autoPreview: setElement('auto-preview', {
        selected: this.ui.autoPreview,
        command: 'narrow-ui:toggle-auto-preview'
      }),
      protected: setElement('protected', {
        selected: this.ui.protected,
        command: 'narrow-ui:protect'
      }),
      refresh: setElement('refresh', {command: 'narrow-ui:refresh'}),
      itemCount: setElement('item-count'),
      selectFiles: setElement('select-files', {
        hideIf: this.ui.boundToSingleFile,
        command: 'narrow-ui:select-files'
      }),
      inlineGitDiff: setElement('inline-git-diff', {
        hideIf: this.ui.provider.dashName !== 'git-diff-all',
        command: 'narrow-ui:git-diff-all-toggle-inline-diff'
      }),
      searchIgnoreCase: setElement('search-ignore-case', {command: 'narrow-ui:toggle-search-ignore-case'}),
      searchWholeWord: setElement('search-whole-word', {command: 'narrow-ui:toggle-search-whole-word'}),
      searchUseRegex: setElement('search-use-regex', {command: 'narrow-ui:toggle-search-use-regex'}),
      searchRegex: setElement('search-regex')
    }

    setElement('provider-name', {command: 'narrow-ui:relocate'})
    setElement('search-options', {hideIf: !this.ui.showSearchOption})
  }

  containsElement (element) {
    return this.element.contains(element)
  }

  destroy () {
    if (this.toolTipDisposables) this.toolTipDisposables.dispose()
    if (this.marker) this.marker.destroy()
  }

  // Can be called multiple times
  // Why? When narrow-editor's prompt row itself was removed, need to redraw to recover.
  show () {
    const editor = this.ui.editor
    if (this.marker) this.marker.destroy()
    this.marker = editor.markBufferPosition([0, 0])

    this.marker.onDidChange(({newHeadBufferPosition}) => {
      // When query include new line( like "query\n" ) was inserted,
      // marker row updated and control-bar rendered at odd position.
      // So we need to re-render control-bar at top of narrow-editor here.
      if (newHeadBufferPosition.row > 0) this.show()
    })

    editor.decorateMarker(this.marker, {
      type: 'block',
      item: this.element,
      position: 'before'
    })

    if (!this.toolTipDisposables) {
      const disposables = this.toolTipsSpecs.map(({element, commandName, keyBindingTarget}) => {
        return atom.tooltips.add(element, {
          title: _.humanizeEventName(commandName.split(':').pop()),
          keyBindingCommand: commandName,
          keyBindingTarget: keyBindingTarget
        })
      })
      this.toolTipDisposables = new CompositeDisposable(...disposables)
    }
  }

  updateElements (states) {
    for (const name in states) {
      const element = this.elements[name]
      if (!element) continue

      const value = states[name]

      if (name === 'itemCount') {
        element.textContent = value
      } else if (name === 'searchRegex') {
        if (value) {
          element.textContent = value.toString()
          element.invalid = false
        } else {
          element.textContent = states.searchTerm
          element.invalid = states.searchTerm.length
        }
      } else if (name === 'refresh') {
        element.classList.toggle('running', value)
      } else {
        element.classList.toggle('selected', value)
      }
    }
  }
}
