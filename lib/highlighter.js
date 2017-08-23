const {CompositeDisposable, Point, Range} = require("atom")

const {getVisibleEditors, isNarrowEditor, cloneRegExp, isNormalItem, arrayForRange} = require("./utils")

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

    this.subscriptions = new CompositeDisposable()

    const {editor} = this.ui
    this.markerLayers = {}
    this.decorationLayers = {}
    this.createMarkerLayer("searchTerm", "search-term")
    this.createMarkerLayer("searchTermForPrompt", "search-term")
    this.createMarkerLayer("includeFilter", "include-filter")
    this.createMarkerLayer("truncationIndicator", "truncation-indicator")
    this.createMarkerLayer("includeFilterForPrompt", "include-filter")
    this.createMarkerLayer("excludeFilterForPrompt", "exclude-filter")
    this.createMarkerLayer("header", "header")

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

  createMarkerLayer(layerName, className) {
    const {editor} = this.ui
    const markerLayer = editor.addMarkerLayer()
    const decorationLayer = editor.decorateMarkerLayer(markerLayer, {
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

    if (searchTerm) {
      searchTermForPrompt.markBufferRange(searchTerm)
    }
    for (const include of includeFilters) {
      includeFilterForPrompt.markBufferRange(include)
    }
    for (const exclude of excludeFilters) {
      excludeFilterForPrompt.markBufferRange(exclude)
    }
  }

  clearItemsHighlightOnNarrowEditor() {
    this.markerLayers.header.clear()
    this.markerLayers.searchTerm.clear()
    this.markerLayers.includeFilter.clear()
    this.markerLayers.truncationIndicator.clear()
  }

  highlightItemsOnNarrowEditor(items, filterSpec) {
    const {
      header: headerLayer,
      searchTerm: searchTermLayer,
      includeFilter: includeFilterLayer,
      truncationIndicator: truncationIndicatorLayer,
    } = this.markerLayers

    const includeFilters = filterSpec ? filterSpec.include.map(re => new RegExp(re.source, re.flags + "g")) : null

    let itemRow = this.ui.items.getRowForItem(items[0]) - 1
    for (const item of items) {
      itemRow++

      if (item.header) {
        const range = this.ui.editor.bufferRangeForBufferRow(itemRow)
        headerLayer.markBufferRange(range, {invalidate: "inside"})
        continue
      }

      // These variables are used to calculate offset for highlight
      const lineHeaderLength = item._lineHeader ? item._lineHeader.length : 0
      const truncationIndicatorLength = item._truncationIndicator ? item._truncationIndicator.length : 0
      const skipLength = lineHeaderLength + truncationIndicatorLength

      // We can highlight searchTerm only for item with range.
      if (item.range) {
        let range = item.translateRange ? item.translateRange() : item.range
        range = [[itemRow, range.start.column + skipLength], [itemRow, range.end.column + skipLength]]
        searchTermLayer.markBufferRange(range, {invalidate: "inside"})
      }

      if (includeFilters) {
        const lineText = this.ui.editor.lineTextForBufferRow(itemRow).slice(skipLength)
        for (const regex of includeFilters) {
          regex.lastIndex = 0
          let match
          while ((match = regex.exec(lineText))) {
            const matchText = match[0]
            if (!matchText) break // Avoid infinite loop in zero length match(in regex /^/)
            const range = [[itemRow, match.index + skipLength], [itemRow, regex.lastIndex + skipLength]]
            includeFilterLayer.markBufferRange(range, {invalidate: "inside"})
          }
        }
      }

      if (truncationIndicatorLength) {
        const range = [[itemRow, lineHeaderLength], [itemRow, lineHeaderLength + truncationIndicatorLength]]
        truncationIndicatorLayer.markBufferRange(range, {invalidate: "inside"})
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
