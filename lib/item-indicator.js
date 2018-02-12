module.exports = class ItemIndicator {
  constructor (editor, items) {
    this.editor = editor
    items.onDidChangeSelectedItem(({newItem}) => {
      this.update({row: newItem._row})
    })

    this.gutter = this.editor.addGutter({
      name: 'narrow-item-indicator',
      priority: 100
    })
    this.item = document.createElement('span')
    this.states = {row: null, protected: false}
  }

  render () {
    if (this.marker) this.marker.destroy()
    this.marker = this.editor.markBufferPosition([this.states.row, 0])
    this.gutter.decorateMarker(this.marker, {
      class: this.states.protected ? 'narrow-ui-item-indicator-protected' : 'narrow-ui-item-indicator',
      item: this.item
    })
  }

  update (states = {}) {
    Object.assign(this.states, states)
    this.render(this.states)
  }

  destroy () {
    if (this.marker) this.marker.destroy()
  }
}
