const {CompositeDisposable} = require("atom")
const {addToolTips, suppressEvent} = require("./utils")

// This is NOT Panel in Atom's terminology, Just naming.
class ControlBar {
  constructor(ui) {
    this.ui = ui
    const {editor, editorElement, provider, showSearchOption} = this.ui
    Object.assign(this, {editor, editorElement, provider, showSearchOption})

    this.container = document.createElement("div")
    this.container.className = "narrow-control-bar"
    this.container.innerHTML = `\
      <div class='base inline-block'>
        <a class='auto-preview'></a>
        <span class='provider-name'>${this.provider.dashName}</span>
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
      </div>\
      `

    // NOTE: Avoid mousedown event propagated up to belonging narrow-editor's element
    // If propagated, button clicking cause narrow-editor's cursor move etc See #123.
    this.container.addEventListener("mousedown", suppressEvent)

    const keyBindingTarget = this.editorElement
    this.toolTipsSpecs = []

    const elementFor = (name, {click, hideIf, selected, tips} = {}) => {
      const element = this.container.getElementsByClassName(name)[0]
      if (click) element.addEventListener("click", click)
      if (hideIf) element.style.display = "none"
      if (selected) element.classList.toggle("selected")
      if (tips)
        this.toolTipsSpecs.push({element, commandName: tips, keyBindingTarget})

      return element
    }

    this.elements = {
      autoPreview: elementFor("auto-preview", {
        click: this.ui.toggleAutoPreview,
        tips: "narrow-ui:toggle-auto-preview",
        selected: this.ui.autoPreview,
      }),
      protected: elementFor("protected", {
        click: this.ui.toggleProtected,
        tips: "narrow-ui:protect",
        selected: this.ui.protected,
      }),
      refresh: elementFor("refresh", {
        click: this.ui.refreshManually,
        tips: "narrow:refresh",
      }),
      itemCount: elementFor("item-count"),
      selectFiles: elementFor("select-files", {
        click: this.ui.selectFiles,
        hideIf: this.ui.boundToSingleFile,
        tips: "narrow-ui:select-files",
      }),
      searchIgnoreCase: elementFor("search-ignore-case", {
        click: this.ui.toggleSearchIgnoreCase,
        tips: "narrow-ui:toggle-search-ignore-case",
      }),
      searchWholeWord: elementFor("search-whole-word", {
        click: this.ui.toggleSearchWholeWord,
        tips: "narrow-ui:toggle-search-whole-word",
      }),
      searchUseRegex: elementFor("search-use-regex", {
        click: this.ui.toggleSearchUseRegex,
        tips: "narrow-ui:toggle-search-use-regex",
      }),
      searchRegex: elementFor("search-regex"),
    }

    elementFor("search-options", {hideIf: !this.showSearchOption})
  }

  containsElement(element) {
    return this.container.contains(element)
  }

  destroy() {
    if (this.toolTipDisposables) this.toolTipDisposables.dispose()
    if (this.marker) this.marker.destroy()
  }

  // Can be called multiple times
  // Why? When narrow-editor's prompt row itself was removed, need to redraw to recover.
  show() {
    if (this.marker) this.marker.destroy()
    this.marker = this.editor.markBufferPosition([0, 0])
    this.editor.decorateMarker(this.marker, {
      type: "block",
      item: this.container,
      position: "before",
    })

    if (!this.toolTipDisposables) {
      this.toolTipDisposables = new CompositeDisposable()
      this.toolTipsSpecs.map(toolTipsSpec =>
        this.toolTipDisposables.add(addToolTips(toolTipsSpec))
      )
    }
  }

  updateElements(states) {
    for (const elementName in states) {
      let invalid
      const element = this.elements[elementName]
      if (!element) continue
      const value = states[elementName]

      switch (elementName) {
        case "itemCount":
          element.textContent = value
          break
        case "searchRegex":
          if (value) {
            element.textContent = value.toString()
            invalid = false
          } else {
            element.textContent = states.searchTerm
            invalid = states.searchTerm.length > 0
          }
          element.classList.toggle("invalid", invalid)
          break
        case "refresh":
          element.classList.toggle("running", value)
          break
        default:
          element.classList.toggle("selected", value)
      }
    }
  }
}
module.exports = ControlBar
