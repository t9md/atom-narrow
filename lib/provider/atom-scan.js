const {Point, Range} = require("atom")
const ProviderBase = require("./provider-base")
const SearchOptions = require("../search-options")

const providerConfig = {
  supportDirectEdit: true,
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
  }

  scanWorkspace() {
    function itemizeResult(result) {
      if (result && result.matches && result.matches.length) {
        const {filePath, matches} = result
        const items = matches.map(({range, lineText}) => {
          range = Range.fromObject(range)
          return {
            filePath: filePath,
            text: lineText,
            point: range.start,
            range: range,
          }
        })
        this.updateItems(items)
      }
    }

    const scanPromise = atom.workspace
      .scan(this.searchOptions.searchRegex, itemizeResult.bind(this))
      .then(message => {
        // Relying on Atom's workspace.scan's specific implementation
        // `workspace.scan` return cancellable promise.
        // When cancelled, promise is NOT rejected, instead it's resolved with 'cancelled' message
        if (message === "canceled") {
          console.log("canceled")
          return
        }

        this.scanPromise = null
        this.finishUpdateItems()
      })

    return scanPromise
  }

  search(event) {
    if (this.scanPromise) {
      this.scanPromise.cancel()
      this.scanPromise = null
    }

    const {filePath} = event
    if (!filePath) {
      this.scanPromise = this.scanWorkspace()
      return
    }

    if (atom.project.contains(filePath)) {
      const searchRegex = this.searchOptions.searchRegex
      this.scanItemsForFilePath(filePath, searchRegex).then(this.finishUpdateItems)
    } else {
      // When non project file was saved. We have nothing todo, so just return old @items.
      this.finishUpdateItems([])
    }
  }

  getItems(event) {
    this.updateSearchState()
    if (this.searchOptions.searchRegex) {
      this.search(event)
    } else {
      this.finishUpdateItems([])
    }
  }
}

module.exports = AtomScan
