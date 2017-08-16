"use babel"

const {Point, Range} = require("atom")
const ProviderBase = require("./provider-base")
const {scanItemsForFilePath} = require("../utils")

const providerConfig = {
  supportDirectEdit: false,
  showColumnOnLineHeader: true,
  showProjectHeader: true,
  showFileHeader: true,
  itemHaveRange: true,
  showSearchOption: true,
  supportCacheItems: true,
  useFirstQueryAsSearchTerm: true,
  supportFilePathOnlyItemsUpdate: true,
  refreshOnDidStopChanging: true,
}

class AtomScan extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
    this.itemizeResult = this.itemizeResult.bind(this)
  }

  itemizeResult(result) {
    if (result && result.matches && result.matches.length) {
      const {filePath, matches} = result
      const items = matches.map(({range, lineText, lineTextOffset}) => {
        range = Range.fromObject(range)
        return {
          filePath: filePath,
          text: lineText,
          point: range.start,
          range: range,
          translateRange() {
            return this.range.translate([0, -lineTextOffset])
          },
        }
      })
      this.updateItems(items)
    }
  }

  async getItems({filePath}) {
    if (this.scanPromise) this.scanPromise.cancel()

    const {searchRegex} = this.searchOptions

    if (!searchRegex) {
      return this.finishUpdateItems([])
    }

    if (filePath) {
      const items = atom.project.contains(filePath) ? await scanItemsForFilePath(filePath, searchRegex) : []
      this.finishUpdateItems(items)
    } else {
      this.scanPromise = atom.workspace.scan(searchRegex, this.itemizeResult).then(message => {
        this.scanPromise = null
        // Relying on Atom's workspace.scan's specific implementation
        // `workspace.scan` return cancellable promise.
        // When cancelled, promise is NOT rejected, instead it's resolved with 'cancelled' message
        if (message === "cancelled") return

        this.finishUpdateItems()
      })
    }
  }
}

module.exports = AtomScan
