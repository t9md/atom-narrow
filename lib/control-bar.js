"use babel"
/** @jsx etch.dom */

const {camelize, dasherize} = require("underscore-plus")
const {CompositeDisposable} = require("atom")
const {addToolTips, suppressEvent} = require("./utils")

const etch = require("etch")
etch.setScheduler(atom.views)
const $ = etch.dom

function t(baseText, bool, textToToggle = "selected") {
  return bool ? `${baseText} ${textToToggle}` : baseText
}

class ControlBar {
  constructor(ui, props = {}) {
    this.ui = ui
    this.props = props
    etch.initialize(this)

    // NOTE: Avoid mousedown event propagated up to belonging narrow-editor's element
    // If propagated, button clicking cause narrow-editor's cursor move etc See #123.
    this.element.addEventListener("mousedown", suppressEvent)
    this.toolTipsSpecs = this.buildToolTipsSpecs()
  }

  buildToolTipsSpecs() {
    const toolTips = [
      {ref: "autoPreview", command: "narrow-ui:toggle-auto-preview"},
      {ref: "protect", command: "narrow-ui:protect"},
      {ref: "refresh", command: "narrow:refresh"},
      {ref: "selectFiles", command: "narrow-ui:select-files"},
      {ref: "searchIgnoreCase", command: "narrow-ui:toggle-search-ignore-case"},
      {ref: "searchWholeWord", command: "narrow-ui:toggle-search-whole-word"},
      {ref: "searchUseRegex", command: "narrow-ui:toggle-search-use-regex"},
    ]

    const keyBindingTarget = this.ui.editorElement
    toolTips.forEach(toolTip => {
      toolTip.element = this.refs[toolTip.ref]
      toolTip.keyBindingTarget = keyBindingTarget
    })
    return toolTips.filter(toolTips => toolTips.element)
  }

  render() {
    const ui = this.ui

    const [searchRegexToShow, searchRegexIsInvalid] = this.props.searchRegex
      ? [this.props.searchRegex.toString(), false]
      : [this.props.searchTerm || "", true]

    const a = (ref, onClick = null) => {
      const className = t(dasherize(ref), this.props[ref])
      return $.a({ref, className, onClick})
    }

    const button = (ref, onClick = null, content) => {
      const className = t("btn " + dasherize(ref), this.props[ref])
      return $.button({ref, className, onClick}, content)
    }

    return $.div(
      {className: "narrow-control-bar"},
      $.div(
        {className: "base inline-block"},
        a("autoPreview", ui.toggleAutoPreview),
        $.span({className: "provider-name"}, ui.provider.dashName),
        $.span({className: "item-count"}, this.props.itemCount),
        a("refresh", ui.refreshManually),
        a("protected", ui.toggleProtected),
        !ui.boundToSingleFile ? a("selectFiles", ui.selectFiles) : null
      ),
      ui.showSearchOption
        ? $.div(
            {className: "search-options inline-block"},
            $.div(
              {className: "btn-group btn-group-xs"},
              button("searchIgnoreCase", ui.toggleSearchIgnoreCase, "Aa"),
              button("searchWholeWord", ui.toggleSearchWholeWord, "\\b"),
              button("searchUseRegex", ui.toggleSearchUseRegex, ".*")
            ),
            $.span(
              {className: t("search-regex", searchRegexIsInvalid, "invalid")},
              searchRegexToShow
            )
          )
        : null
    )
  }

  update(props = {}, children) {
    Object.assign(this.props, props)
    etch.update(this)
  }

  containsElement(element) {
    return this.element.contains(element)
  }

  destroy() {
    if (this.toolTipDisposables) this.toolTipDisposables.dispose()
    if (this.marker) this.marker.destroy()
  }

  // Can be called multiple times
  // Why? When narrow-editor's prompt row itself was removed, need to redraw to recover.
  show() {
    if (this.marker) this.marker.destroy()
    const {editor} = this.ui
    this.marker = editor.markBufferPosition([0, 0])
    editor.decorateMarker(this.marker, {
      type: "block",
      item: this.element,
      position: "before",
    })

    if (!this.toolTipDisposables) {
      this.toolTipDisposables = new CompositeDisposable()
      this.toolTipsSpecs.map(toolTipsSpec => this.toolTipDisposables.add(addToolTips(toolTipsSpec)))
    }
  }
}
module.exports = ControlBar
