module.exports = class ItemIndicator {
  constructor(editor) {
    this.editor = editor
    this.gutter = this.editor.addGutter({
      name: "narrow-item-indicator",
      priority: 100,
    })
    this.item = document.createElement("span")
    this.states = {row: null, protected: false}
  }

  render() {
    if (this.marker) this.marker.destroy()

    const className = this.states.protected ? "narrow-ui-item-indicator-protected" : "narrow-ui-item-indicator"

    this.marker = this.editor.markBufferPosition([this.states.row, 0])
    this.gutter.decorateMarker(this.marker, {
      class: className,
      item: this.item,
    })
  }

  update(states = {}) {
    for (let state in states) {
      const value = states[state]
      this.states[state] = value
    }
    this.render(this.states)
  }

  destroy() {
    if (this.marker) this.marker.destroy()
  }
}
