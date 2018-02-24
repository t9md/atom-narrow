// This is kind of META provider, invoked from UI.
// Provide narrow-ui to select narrowing target files.
const {Point} = require('atom')
const Provider = require('./provider')
const settings = require('../settings')
const {relativizeFilePath} = require('../utils')

const queryByProviderName = {}

const Config = {
  boundToSingleFile: true,
  supportCacheItems: true,
  supportReopen: false,
  needRestoreEditorState: false
}

module.exports = class SelectFiles {
  static getLastQuery (providerName) {
    let query
    if (settings.get('SelectFiles.rememberQuery')) {
      query = queryByProviderName[providerName]
    }
    return query || ''
  }

  constructor (clientUi) {
    this.clientUi = clientUi

    this.provider = Provider.create({
      name: this.constructor.name,
      config: Config,
      didDestroy: () => {
        if (this.clientUi.isAlive()) {
          this.clientUi.focus({autoPreview: false})
        }
      },
      didConfirmItem: this.didConfirmItem.bind(this),
      getItems: () => this.getItems()
    })
  }

  start (options) {
    return this.provider.start(options)
  }

  getItems () {
    const filePaths = this.clientUi.getFilePathsForAllItems()
    return filePaths.map(filePath => ({
      text: relativizeFilePath(filePath),
      filePath,
      point: new Point(0, 0)
    }))
  }

  // Must return undefined, when non null value was returned
  // Ui treat it as openable editor instance and try to open it.
  async didConfirmItem (item) {
    if (this.clientUi.isAlive()) {
      const queryForSelectFiles = this.provider.ui.lastQuery
      await this.clientUi.resetQueryForSelectFiles(queryForSelectFiles)
      this.clientUi.narrowEditor.moveToItemForFilePath(item.filePath)
      queryByProviderName[this.clientUi.provider.name] = queryForSelectFiles
    }
    this.provider.ui.destroy()
  }
}
