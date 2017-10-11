// This is kind of META provider, invoked from UI.
// Provide narrow-ui to select narrowing target files.
const {Point} = require("atom")
const _ = require("underscore-plus")
const ProviderBase = require("./provider-base")
const settings = require("../settings")
const {relativizeFilePath} = require("../utils")

const queryByProviderName = {}

const providerConfig = {
  boundToSingleFile: true,
  supportCacheItems: true,
  supportReopen: false,
  needRestoreEditorState: false,
}

class SelectFiles extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  static getLastQuery(providerName) {
    if (settings.get("SelectFiles.rememberQuery")) {
      const query = queryByProviderName[providerName]
      if (query) return query
    }
    return ""
  }

  initialize() {
    const {clientUi} = this.options
    this.clientUi = clientUi
    this.ui.onDidDestroy(() => {
      if (clientUi.isAlive()) clientUi.focus({autoPreview: false})
    })
  }

  getItems() {
    const filePaths = this.clientUi.getFilePathsForAllItems()
    this.finishUpdateItems(
      filePaths.map(filePath => ({
        text: relativizeFilePath(filePath),
        filePath,
        point: new Point(0, 0),
      }))
    )
  }

  confirmed(item) {
    if (this.clientUi.isAlive()) {
      const queryForSelectFiles = this.ui.lastQuery
      this.clientUi.resetQueryForSelectFiles(queryForSelectFiles)
      this.clientUi.moveToItemForFilePath(item.filePath)
      queryByProviderName[this.clientUi.provider.name] = queryForSelectFiles
    }

    this.ui.editor.destroy()
    return Promise.resolve(null)
  }
}
module.exports = SelectFiles
