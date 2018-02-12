module.exports = class GroupedHighlight {
  constructor (editor, classNameByName) {
    this.editor = editor
    this.markerLayerByName = {}
    this.decorationLayerByName = {}

    for (const name in classNameByName) {
      this.addLayer(name, classNameByName[name])
    }
  }

  addLayer (name, className) {
    const markerLayer = this.editor.addMarkerLayer()
    const decorationLayer = this.editor.decorateMarkerLayer(markerLayer, {type: 'text', class: className})
    this.markerLayerByName[name] = markerLayer
    this.decorationLayerByName[name] = decorationLayer
  }

  destroy () {
    Object.values(this.markerLayerByName).forEach(layer => layer.destroy())
    Object.values(this.decorationLayerByName).forEach(layer => layer.destroy())
  }

  clear () {
    Object.values(this.markerLayerByName).forEach(layer => layer.clear())
  }

  markRange (layerName, range, options) {
    this.markerLayerByName[layerName].markBufferRange(range, options)
  }
}
