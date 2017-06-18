const {CompositeDisposable, Point, Range} = require("atom")

const {
  getVisibleEditors,
  isNarrowEditor,
  cloneRegExp,
  isNormalItem,
  arrayForRange,
  getVisibleBufferRange,
} = require("./utils")

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

    const {editor} = this.ui

    this.markerLayers = {
      searchTerm: editor.addMarkerLayer(),
      filterMatch: editor.addMarkerLayer(),
    }

    this.decorationLayers = {
      searchTerm: editor.decorateMarkerLayer(this.markerLayers.searchTerm, {
        type: "text",
        class: "narrow-search-term",
      }),
      filterMatch: editor.decorateMarkerLayer(this.markerLayers.filterMatch, {
        type: "text",
        class: "narrow-filter-match",
      }),
    }

    if (this.itemHaveRange) {
      this.subscriptions.add(this.ui.onDidRefresh(this.refreshAll.bind(this)))
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

  clearNarrowEditorHighlight() {
    this.markerLayers.searchTerm.clear()
    this.markerLayers.filterMatch.clear()
  }

  // FIXME, update highlight at onDidChangeScrollTop
  highlightNarrowEditorForSearchTerm(items) {
    if (!this.regExp) return

    const markerLayer = this.markerLayers.searchTerm
    let row = this.ui.items.getRowForItem(items[0]) - 1

    for (const item of items) {
      row++
      let {range} = item
      if (!range) continue

      if (item._lineHeader) {
        range = range.translate([0, item._lineHeader.length])
      }
      markerLayer.markBufferRange([[row, range.start.column], [row, range.end.column]], {
        invalidate: "inside",
      })
    }
  }

  // FIXME, update highlight at onDidChangeScrollTop
  highlightNarrowEditorForFilterMatch(items, filterPatterns) {
    const markerLayer = this.markerLayers.filterMatch
    const startRow = this.ui.items.getRowForItem(items[0])
    const endRow = startRow + items.length
    const bufferLines = this.ui.editor.buffer.getLines()

    filterPatterns = filterPatterns.map(re => new RegExp(re.source, re.flags + "g"))

    for (let row = startRow; row <= endRow; row++) {
      if (!this.ui.items.isNormalItemRow(row)) return

      const lineText = bufferLines[row]

      for (let regex of filterPatterns) {
        regex.lastIndex = 0
        let match
        while ((match = regex.exec(lineText))) {
          const matchText = match[0]
          if (!matchText) break // Avoid infinite loop in zero length match(in regex /^/)
          markerLayer.markBufferRange([[row, match.index], [row, regex.lastIndex]], {
            invalidate: "inside",
          })
        }
      }
    }
  }

  setRegExp(regExp) {
    this.regExp = regExp
  }

  destroy() {
    this.markerLayers.searchTerm.destroy()
    this.markerLayers.filterMatch.destroy()
    this.decorationLayers.searchTerm.destroy()
    this.decorationLayers.filterMatch.destroy()

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
