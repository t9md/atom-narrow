const {CompositeDisposable, Point, Range} = require("atom")

const {getVisibleEditors, isNarrowEditor, getPrefixedTextLengthInfo} = require("./utils")

module.exports = class Highlighter {
  constructor(ui) {
    this.ui = ui
    this.boundToSingleFile = ui.boundToSingleFile
    this.itemHaveRange = ui.itemHaveRange
    this.provider = ui.provider

    this.regExp = null
    this.lineMarker = null

    this.markerLayerByEditor = new Map()
    this.decorationLayerByEditor = new Map()

    this.markerLayers = {}
    this.decorationLayers = {}
    this.createMarkerLayer("searchTerm", "search-term")
    this.createMarkerLayer("searchTermForPrompt", "search-term")

    this.createMarkerLayer("includeFilter", "include-filter")
    this.createMarkerLayer("includeFilterForPrompt", "include-filter")

    this.createMarkerLayer("excludeFilterForPrompt", "exclude-filter")

    this.createMarkerLayer("headerForFile", "header-file")
    this.createMarkerLayer("headerForProject", "header-project")

    this.createMarkerLayer("truncationIndicator", "truncation-indicator")

    this.subscriptions = new CompositeDisposable(
      ui.onDidRefresh(() => {
        if (this.itemHaveRange) this.refreshAll()
      }),
      ui.onDidConfirm(() => this.clearCurrentAndLineMarker()),
      ui.onDidPreview(({editor, item}) => {
        this.clearCurrentAndLineMarker()
        this.drawLineMarker(editor, item)
        if (this.itemHaveRange) {
          this.highlightEditor(editor)
          this.highlightCurrentItem(editor, item)
        }
      })
    )
  }

  markRange(layerName, range) {
    return this.markerLayers[layerName].markBufferRange(range, {invalidate: "inside"})
  }

  createMarkerLayer(layerName, className) {
    const markerLayer = this.ui.editor.addMarkerLayer()
    const decorationLayer = this.ui.editor.decorateMarkerLayer(markerLayer, {
      type: "text",
      class: "narrow-syntax--" + className,
    })
    this.markerLayers[layerName] = markerLayer
    this.decorationLayers[layerName] = decorationLayer
  }

  highlightPrompt({includeFilters, excludeFilters, searchTerm}) {
    // Manage marker for prompt highlight separately.
    // Because
    //  - Normal highlight is done at rendering phase of refresh, it's delayed.
    //  - But I want prompt highlight update without delay.
    const {searchTermForPrompt, includeFilterForPrompt, excludeFilterForPrompt} = this.markerLayers
    searchTermForPrompt.clear()
    includeFilterForPrompt.clear()
    excludeFilterForPrompt.clear()

    if (searchTerm) searchTermForPrompt.markBufferRange(searchTerm)
    for (const range of includeFilters) includeFilterForPrompt.markBufferRange(range)
    for (const range of excludeFilters) excludeFilterForPrompt.markBufferRange(range)
  }

  clearItemsHighlightOnNarrowEditor() {
    this.markerLayers.headerForFile.clear()
    this.markerLayers.headerForProject.clear()
    this.markerLayers.searchTerm.clear()
    this.markerLayers.includeFilter.clear()
    this.markerLayers.truncationIndicator.clear()
  }

  highlightItemsOnNarrowEditor(items, filterSpec) {
    const includeFilters = filterSpec ? filterSpec.include.map(re => new RegExp(re.source, re.flags + "g")) : null

    for (const item of items) {
      const row = item._uiRow

      if (item.header) {
        this.markRange(item.filePath ? "headerForFile" : "headerForProject", this.ui.editor.bufferRangeForBufferRow(row))
        continue
      }

      // These variables are used to calculate offset for highlight
      const {lineHeaderLength, truncationIndicatorLength, totalLength} = getPrefixedTextLengthInfo(item)

      // We can highlight searchTerm only for item with range.
      if (item.range) {
        const range = item.translateRange ? item.translateRange() : item.range
        this.markRange("searchTerm", [[row, range.start.column + totalLength], [row, range.end.column + totalLength]])
      }

      if (includeFilters) {
        const lineText = this.ui.editor.lineTextForBufferRow(row).slice(totalLength)
        for (const regex of includeFilters) {
          regex.lastIndex = 0
          let match
          while ((match = regex.exec(lineText))) {
            const matchText = match[0]
            if (!matchText) break // Avoid infinite loop in zero length match(in regex /^/)
            this.markRange("includeFilter", [[row, match.index + totalLength], [row, regex.lastIndex + totalLength]])
          }
        }
      }

      if (truncationIndicatorLength) {
        const range = [[row, lineHeaderLength], [row, lineHeaderLength + truncationIndicatorLength]]
        this.markRange("truncationIndicator", range)
      }
    }
  }

  setRegExp(regExp) {
    this.regExp = regExp
  }

  destroy() {
    for (const name in this.markerLayers) this.markerLayers[name].destroy()
    for (const name in this.decorationLayers) this.decorationLayers[name].destroy()

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

    for (const {range} of items) {
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
      if (decorationLayer) decorationLayer.setPropertiesForMarker(this.currentItemMarker, null)

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
    if (this.lineMarker) {
      this.lineMarker.destroy()
      this.lineMarker = null
    }
  }

  // flash
  // -------------------------
  clearFlashMarker() {
    if (this.clearFlashTimeoutID) {
      clearTimeout(this.clearFlashTimeoutID)
      this.clearFlashTimeoutID = null
    }

    if (this.flashMarker) {
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
    this.clearFlashTimeoutID = setTimeout(() => this.clearFlashMarker(), 1000)
  }
}
