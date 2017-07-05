const {Point, Range} = require("atom")
const ProviderBase = require("./provider-base")

const providerConfig = {
  boundToSingleFile: true,
  supportDirectEdit: true,
  showColumnOnLineHeader: true,
  itemHaveRange: true,
  showSearchOption: true,
  supportCacheItems: true,
  useFirstQueryAsSearchTerm: true,
  refreshOnDidStopChanging: true,
}

function itemize(text, row) {
  const point = new Point(row, 0)
  return {
    text: text,
    point: point,
    range: new Range(point, point),
  }
}

class Scan extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  getItems() {
    this.updateSearchState()

    const {searchRegex} = this.searchOptions
    const {buffer} = this.editor
    const items = searchRegex
      ? this.scanItemsForBuffer(buffer, searchRegex)
      : buffer.getLines().map(itemize)

    this.finishUpdateItems(items)
  }
}

module.exports = Scan
