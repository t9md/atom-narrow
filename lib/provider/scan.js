const { Point, Range } = require("atom")
const { cloneRegExp } = require("../utils")
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

class Scan extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  getItems() {
    this.updateSearchState()

    const { buffer } = this.editor
    const { searchRegex } = this.searchOptions

    if (searchRegex) {
      this.finishUpdateItems(this.scanItemsForBuffer(buffer, searchRegex))
    } else {
      this.finishUpdateItems(buffer.getLines().map(itemize))

      function itemize(text, row) {
        const point = new Point(row, 0)
        return { text, point, range: new Range(point, point) }
      }
    }
  }
}

module.exports = Scan
