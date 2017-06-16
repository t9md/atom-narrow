const {CompositeDisposable, Point, Range} = require("atom")

const {getVisibleEditors, isNarrowEditor, cloneRegExp, isNormalItem} = require("./utils")

module.exports = class Highlighter {
  constructor(ui) {
    this.ui = ui
    this.boundToSingleFile = ui.boundToSingleFile
    this.itemHaveRange = ui.itemHaveRange
    this.itemHaveRange = ui.itemHaveRange
    this.provider = ui.provider

    this.regExp = null
    this.lineMarker = null

    this.markerLayerByEditor = new Map()
    this.decorationLayerByEditor = new Map()

    this.subscriptions = new CompositeDisposable()

    this.subscriptions.add(
      this.ui.onDidRefresh(() => {
        this.highlightNarrowEditorForQuery()
        this.highlightNarrowEditorForKeyword()
      })
    )

    if (this.itemHaveRange) {
      this.subscriptions.add(
        this.ui.onDidRefresh(() => {
          this.refreshAll()
        })
      )
    }

    this.subscriptions.add(this.ui.onDidConfirm(() => this.clearCurrentAndLineMarker()))

    this.subscriptions.add(
      this.ui.onDidPreview(({editor, item}) => {
        this.clearCurrentAndLineMarker()
        this.drawLineMarker(editor, item)
        if (this.itemHaveRange) {
          this.highlightEditor(editor)
          this.highlightCurrentItem(editor, item)
        }
      })
    )
  }

  highlightNarrowEditorForQuery() {
    if (!this.regExp) return

    const {editor} = this.ui

    if (this.markerLayerForUi) {
      this.markerLayerForUi.clear()
    } else {
      this.markerLayerForUi = editor.addMarkerLayer()
      this.decorationLayerForUi = editor.decorateMarkerLayer(this.markerLayerForUi, {
        type: "text",
        class: "narrow-match-query",
      })
    }

    const lines = editor.buffer.getLines()
    lines.forEach((line, row) => {
      const item = this.ui.items.getItemForRow(row)
      if (!isNormalItem(item)) return

      let {range} = item
      if (item._lineHeader != null) {
        range = range.translate([0, item._lineHeader.length])
      }
      this.markerLayerForUi.markBufferRange([[row, range.start.column], [row, range.end.column]], {
        invalidate: "inside",
      })
    })
  }

  highlightNarrowEditorForKeyword() {
    if (!this.filterPatterns) return

    const {editor} = this.ui

    if (this.markerLayerForKeyword) {
      this.markerLayerForKeyword.clear()
    } else {
      this.markerLayerForKeyword = editor.addMarkerLayer()
      this.decorationLayerForKeyword = editor.decorateMarkerLayer(this.markerLayerForKeyword, {
        type: "text",
        class: "narrow-match-keyword",
      })
    }
    for (let regex of this.filterPatterns) {
      const {flags} = regex
      editor.scan(new RegExp(regex.source, flags + "g"), ({range}) => {
        if (!this.ui.items.isNormalItemRow(range.start.row)) return
        this.markerLayerForKeyword.markBufferRange(range, {invalidate: "inside"})
      })
    }
  }

  setRegExp(regExp) {
    this.regExp = regExp
  }

  setFilterPatterns(patterns) {
    this.filterPatterns = patterns
  }

  destroy() {
    if (this.markerLayerForUi) this.markerLayerForUi.destroy()
    if (this.decorationLayerForUi) this.decorationLayerForUi.destroy()
    if (this.markerLayerForKeyword) this.markerLayerForKeyword.destroy()
    if (this.decorationLayerForKeyword) this.decorationLayerForKeyword.destroy()

    this.clear()
    this.clearCurrentAndLineMarker()
    this.subscriptions.dispose()
  }

  // Highlight items
  // -------------------------
  refreshAll() {
    this.clear()
    for (const editor of getVisibleEditors()) {
      if (!isNarrowEditor(editor)) this.highlightEditor(editor)
    }
  }

  clear() {
    this.markerLayerByEditor.forEach(markerLayer => markerLayer.destroy())
    this.markerLayerByEditor.clear()

    this.decorationLayerByEditor.forEach(decorationLayer => decorationLayer.destroy())
    this.decorationLayerByEditor.clear()
  }

  highlightEditor(editor) {
    if (
      !this.regExp ||
      this.regExp.source === "." || // Avoid uselessly highlight all character in buffer.
      this.markerLayerByEditor.has(editor) ||
      (this.boundToSingleFile && editor !== this.provider.editor)
    ) {
      return
    }

    const markerLayer = editor.addMarkerLayer()
    const decorationLayer = editor.decorateMarkerLayer(markerLayer, {
      type: "highlight",
      class: "narrow-match",
    })

    this.markerLayerByEditor.set(editor, markerLayer)
    this.decorationLayerByEditor.set(editor, decorationLayer)
    const items = this.ui.getNormalItemsForEditor(editor)

    for (let item of items) {
      const range = item.range
      if (range) markerLayer.markBufferRange(range, {invalidate: "inside"})
    }
  }

  clearCurrentAndLineMarker() {
    this.clearLineMarker()
    this.clearCurrentItemHiglight()
  }

  // modify current item decoration
  // -------------------------
  highlightCurrentItem(editor, {range}) {
    // console.trace()
    const decorationLayer = this.decorationLayerByEditor.get(editor)
    if (!decorationLayer) return

    const startBufferRow = range.start.row
    const markers = decorationLayer.getMarkerLayer().findMarkers({startBufferRow})

    for (const marker of markers) {
      if (marker.getBufferRange().isEqual(range)) {
        decorationLayer.setPropertiesForMarker(marker, {
          type: "highlight",
          class: "narrow-match current",
        })
        this.currentItemEditor = editor
        this.currentItemMarker = marker
        return
      }
    }
  }

  clearCurrentItemHiglight() {
    let decorationLayer
    if (this.currentItemEditor) {
      decorationLayer = this.decorationLayerByEditor.get(this.currentItemEditor)
      if (decorationLayer) {
        decorationLayer.setPropertiesForMarker(this.currentItemMarker, null)
      }
      this.currentItemEditor = null
      this.currentItemMarker = null
    }
  }

  // line marker
  // -------------------------
  hasLineMarker() {
    return this.lineMarker != null
  }

  drawLineMarker(editor, item) {
    this.lineMarker = editor.markBufferPosition(item.point)
    editor.decorateMarker(this.lineMarker, {
      type: "line",
      class: "narrow-line-marker",
    })
  }

  clearLineMarker() {
    if (this.lineMarker != null) {
      this.lineMarker.destroy()
      this.lineMarker = null
    }
  }

  // flash
  // -------------------------
  clearFlashMarker() {
    if (this.clearFlashTimeoutID != null) {
      clearTimeout(this.clearFlashTimeoutID)
      this.clearFlashTimeoutID = null
    }

    if (this.flashMarker != null) {
      this.flashMarker.destroy()
      this.flashMarker = null
    }
  }

  flashItem(editor, item) {
    if (!this.itemHaveRange) return

    this.clearFlashMarker()
    this.flashMarker = editor.markBufferRange(item.range)
    editor.decorateMarker(this.flashMarker, {
      type: "highlight",
      class: "narrow-match flash",
    })
    this.clearFlashTimeoutID = setTimeout(this.clearFlashMarker.bind(this), 1000)
  }
}
