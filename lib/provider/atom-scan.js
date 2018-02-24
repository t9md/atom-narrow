const {Range} = require('atom')
const Provider = require('./provider')
const {scanItemsForFilePath} = require('../utils')

const Config = {
  supportDirectEdit: true,
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

module.exports = class AtomScan {
  constructor (state) {
    this.provider = Provider.create({
      name: this.constructor.name,
      state: state,
      config: Config,
      getItems: this.getItems.bind(this),
      didDestroy: () => {
        if (this.scanPromise) {
          this.scanPromise.cancel()
          this.scanPromise = null
        }
      }
    })
  }

  start (options) {
    return this.provider.start(options)
  }

  async itemizeResult ({filePath, matches}) {
    const buffer = await atom.project.bufferForPath(filePath)
    const items = []
    for (const match of matches) {
      const range = Range.fromObject(match.range)
      items.push({
        filePath: filePath,
        text: buffer.lineForRow(range.start.row),
        point: range.start,
        range: range
      })
    }
    this.provider.updateItems(items)
  }

  async getItems ({filePath}) {
    if (this.scanPromise) this.scanPromise.cancel()

    const {searchRegex} = this.provider.searchOptions
    if (!searchRegex) {
      return []
    }

    if (filePath) {
      if (atom.project.contains(filePath)) {
        return scanItemsForFilePath(filePath, searchRegex)
      } else {
        return []
      }
    } else {
      const itemizePromises = []
      this.scanPromise = atom.workspace.scan(searchRegex, result => {
        if (result && result.matches && result.matches.length) {
          itemizePromises.push(this.itemizeResult(result))
        }
      })

      const message = await this.scanPromise
      this.scanPromise = null
      if (message !== 'cancelled') {
        // Relying on Atom's workspace.scan's specific implementation
        // `workspace.scan` return cancellable promise.
        // When cancelled, promise is NOT rejected, instead it's resolved with 'cancelled' message
        await Promise.all(itemizePromises)
        return []
      }
    }
  }
}
