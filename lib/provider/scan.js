const {Point, Range} = require('atom')
const Provider = require('./provider')
const {scanItemsForBuffer} = require('../utils')

const Config = {
  boundToSingleFile: true,
  supportDirectEdit: true,
  showColumnOnLineHeader: true,
  itemHaveRange: true,
  showSearchOption: true,
  supportCacheItems: true,
  useFirstQueryAsSearchTerm: true,
  refreshOnDidStopChanging: true
}

module.exports = class Scan {
  constructor (state) {
    this.provider = Provider.create({
      name: this.constructor.name,
      state: state,
      config: Config,
      getItems: () => this.getItems()
    })
  }

  start (options) {
    return this.provider.start(options)
  }

  getItems () {
    const {searchRegex} = this.provider.searchOptions
    const buffer = this.provider.editor.buffer
    if (searchRegex) {
      return scanItemsForBuffer(buffer, searchRegex)
    } else {
      return buffer.getLines().map((text, row) => {
        const point = new Point(row, 0)
        return {
          text: text,
          point: point,
          range: new Range(point, point)
        }
      })
    }
  }
}
