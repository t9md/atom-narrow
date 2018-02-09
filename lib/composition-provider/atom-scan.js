'use babel'

const {Range} = require('atom')
const Provider = require('./provider')
const {scanItemsForFilePath} = require('../utils')

const Config = {
  supportDirectEdit: false,
  showColumnOnLineHeader: true,
  showProjectHeader: true,
  showFileHeader: true,
  itemHaveRange: true,
  showSearchOption: true,
  supportCacheItems: true,
  useFirstQueryAsSearchTerm: true,
  supportFilePathOnlyItemsUpdate: true,
  refreshOnDidStopChanging: true
}

function createItemsFromScanResult ({filePath, matches}) {
  return matches.map(({range, lineText, lineTextOffset}) => {
    range = Range.fromObject(range)
    return {
      filePath: filePath,
      text: lineText,
      point: range.start,
      range: range,
      translateRange () {
        return this.range.translate([0, -lineTextOffset])
      }
    }
  })
}

module.exports = class AtomScan {
  constructor () {
    this.provider = Provider.create({
      name: this.constructor.name,
      config: Config,
      getItems: this.getItems.bind(this),
      onDestroyed: () => {
        if (this.scanPromise) {
          this.scanPromise.cancel()
          this.scanPromise = null
        }
      }
    })
  }

  async getItems ({filePath}) {
    if (this.scanPromise) this.scanPromise.cancel()

    const {searchRegex} = this.provider.searchOptions
    if (!searchRegex) {
      return this.provider.finishUpdateItems([])
    }

    if (filePath) {
      if (atom.project.contains(filePath)) {
        this.provider.finishUpdateItems(await scanItemsForFilePath(filePath, searchRegex))
      } else {
        this.provider.finishUpdateItems([])
      }
    } else {
      this.scanPromise = atom.workspace.scan(searchRegex, result => {
        if (result && result.matches && result.matches.length) {
          this.provider.updateItems(createItemsFromScanResult(result))
        }
      })

      const message = await this.scanPromise
      this.scanPromise = null
      if (message !== 'cancelled') {
        // Relying on Atom's workspace.scan's specific implementation
        // `workspace.scan` return cancellable promise.
        // When cancelled, promise is NOT rejected, instead it's resolved with 'cancelled' message
        this.provider.finishUpdateItems()
      }
    }
  }
}
