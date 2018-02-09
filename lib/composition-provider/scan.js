const {Point, Range} = require('atom')
const Provider = require('./provider')
const {scanItemsForBuffer} = require('../utils')

function itemize (text, row) {
  const point = new Point(row, 0)
  return {
    text: text,
    point: point,
    range: new Range(point, point)
  }
}

module.exports = class Scan {
  constructor () {
    this.provider = Provider.create({
      name: 'Scan',
      config: {
        boundToSingleFile: true,
        supportDirectEdit: true,
        showColumnOnLineHeader: true,
        itemHaveRange: true,
        showSearchOption: true,
        supportCacheItems: true,
        useFirstQueryAsSearchTerm: true,
        refreshOnDidStopChanging: true
      },
      getItems: () => this.getItems()
    })
  }

  start (options) {
    return this.provider.start(options)
  }

  getItems () {
    const {searchRegex} = this.provider.searchOptions
    const {buffer} = this.provider.editor
    const items = searchRegex ? scanItemsForBuffer(buffer, searchRegex) : buffer.getLines().map(itemize)
    this.provider.finishUpdateItems(items)
  }
}
