const {getVisibleEditors} = require('./utils')
let Ui

module.exports = class Highlighter {
  constructor (ui) {
    this.ui = ui
    this.items = ui.items
    this.boundToSingleFile = ui.boundToSingleFile

    this.regExp = null
    this.lineMarker = null

    this.markerLayerByEditor = new Map()
    this.decorationLayerByEditor = new Map()
  }

  setRegExp (regExp) {
    this.regExp = regExp
  }

  destroy () {
    this.clearEditorHighlight()
    this.clearCurrentAndLineMarker()
  }

  // Highlight items
  // -------------------------
  refreshAll () {
    if (!Ui) Ui = require('./ui')

    this.clearEditorHighlight()
    for (const editor of getVisibleEditors()) {
      if (!Ui.has(editor)) {
        this.highlightEditor(editor)
      }
    }
  }

  clearEditorHighlight () {
    this.markerLayerByEditor.forEach(layer => layer.destroy())
    this.markerLayerByEditor.clear()

    this.decorationLayerByEditor.forEach(layer => layer.destroy())
    this.decorationLayerByEditor.clear()
  }

  highlightEditor (editor) {
    if (
      !this.regExp ||
      this.regExp.source === '.' || // Avoid uselessly highlight all character in buffer.
      this.markerLayerByEditor.has(editor) ||
      (this.boundToSingleFile && editor !== this.ui.provider.editor)
    ) {
      return
    }

    const markerLayer = this.addLayer(editor)
    const items = this.items.getNormalItems(editor.getPath())
    for (const {range} of items) {
      if (range) markerLayer.markBufferRange(range, {invalidate: 'inside'})
    }
  }

  addLayer (editor) {
    const markerLayer = editor.addMarkerLayer()
    const decorationLayer = editor.decorateMarkerLayer(markerLayer, {
      type: 'highlight',
      class: 'narrow-match'
    })
    this.markerLayerByEditor.set(editor, markerLayer)
    this.decorationLayerByEditor.set(editor, decorationLayer)
    return markerLayer
  }

  clearCurrentAndLineMarker () {
    this.clearLineMarker()
    this.clearCurrentItemHiglight()
  }

  // modify current item decoration
  // -------------------------
  highlightCurrentItem (editor, {range}) {
    const decorationLayer = this.decorationLayerByEditor.get(editor)
    if (!decorationLayer) return

    const startBufferRow = range.start.row
    const markers = decorationLayer.getMarkerLayer().findMarkers({startBufferRow})

    for (const marker of markers) {
      if (marker.getBufferRange().isEqual(range)) {
        decorationLayer.setPropertiesForMarker(marker, {
          type: 'highlight',
          class: 'narrow-match current'
        })
        this.currentItemEditor = editor
        this.currentItemMarker = marker
        return
      }
    }
  }

  clearCurrentItemHiglight () {
    let decorationLayer
    if (this.currentItemEditor) {
      decorationLayer = this.decorationLayerByEditor.get(this.currentItemEditor)
      if (decorationLayer) decorationLayer.setPropertiesForMarker(this.currentItemMarker, null)

      this.currentItemEditor = null
      this.currentItemMarker = null
    }
  }

  // line marker
  // -------------------------
  hasLineMarker () {
    return this.lineMarker != null
  }

  drawLineMarker (editor, item) {
    this.lineMarker = editor.markBufferPosition(item.point)
    editor.decorateMarker(this.lineMarker, {
      type: 'line',
      class: 'narrow-line-marker'
    })
  }

  clearLineMarker () {
    if (this.lineMarker) {
      this.lineMarker.destroy()
      this.lineMarker = null
    }
  }

  // flash
  // -------------------------
  clearFlashMarker () {
    if (this.clearFlashTimeoutID) {
      clearTimeout(this.clearFlashTimeoutID)
      this.clearFlashTimeoutID = null
    }

    if (this.flashMarker) {
      this.flashMarker.destroy()
      this.flashMarker = null
    }
  }

  flashItem (editor, item) {
    this.clearFlashMarker()
    this.flashMarker = editor.markBufferRange(item.range)
    editor.decorateMarker(this.flashMarker, {
      type: 'highlight',
      class: 'narrow-match flash'
    })
    this.clearFlashTimeoutID = setTimeout(() => this.clearFlashMarker(), 1000)
  }
}
