const Provider = require('./provider')
const {getProjectPaths, scanItemsForFilePath, scanItemsForBuffer} = require('../utils')

const Searcher = require('../searcher')
const Path = require('path')
let searcherIsAvailable = false

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

module.exports = class Search {
  constructor (state) {
    this.provider = Provider.create({
      name: this.constructor.name,
      state: state,
      config: Config,
      getItems: this.getItems.bind(this),
      willOpenUi: () => {
        // FIXME: Just to wait for initialization of provider.searchOptions
        this.searcher = new Searcher(this.provider.searchOptions)
      },
      didDestroy: () => {
        if (this.searcher) {
          this.searcher.cancel()
          this.searcher = null
        }
      },
      willSaveState: () => {
        return {projects: this.projects}
      }
    })
  }

  start (options = {}) {
    this.projects = this.projects || getProjectPaths(options.currentProject ? this.provider.editor : null)
    if (this.projects) {
      return this.provider.start(options)
    }
  }

  // Return promise
  search () {
    const modifiedBuffers = atom.project.getBuffers().filter(buffer => buffer.isModified() && buffer.getPath())
    const unscannedModifiedBuffers = new Set(modifiedBuffers)
    const filePathsForModifiedBuffer = new Set(modifiedBuffers.map(buffer => buffer.getPath()))
    const {searchRegex} = this.provider.searchOptions

    let resolveSearchPromise
    const searchPromise = new Promise(resolve => {
      resolveSearchPromise = resolve
    })

    let finished = 0
    const onFinish = project => {
      // Append directory separator to avoid unwanted partial match.
      // make `atom` to `atom/` to avoid matches to project name like `atom-keymaps`.
      const projectPrefix = project + Path.sep
      for (const buffer of unscannedModifiedBuffers) {
        if (buffer.getPath().startsWith(projectPrefix)) {
          this.provider.updateItems(scanItemsForBuffer(buffer, searchRegex))
          unscannedModifiedBuffers.delete(buffer)
        }
      }

      finished++
      if (finished === this.projects.length) {
        resolveSearchPromise()
      }
    }

    const onItems = items => {
      const itemsForNonModifiedFile = items.filter(item => !filePathsForModifiedBuffer.has(item.filePath))
      this.provider.updateItems(itemsForNonModifiedFile)
    }

    for (const project of this.projects) {
      this.searcher.searchProject(project, onItems, onFinish)
    }
    return searchPromise
  }

  async getItems ({filePath}) {
    this.searcher.cancel()
    const searcher = this.provider.getConfig('searcher')

    const executable = await this.isExecutable(searcher)
    if (!executable) {
      return []
    }

    const {searchRegex} = this.provider.searchOptions
    if (!searchRegex) {
      return []
    }

    this.searcher.setCommand(searcher)
    if (filePath) {
      if (atom.project.contains(filePath)) {
        return scanItemsForFilePath(filePath, searchRegex)
      } else {
        return []
      }
    } else {
      await this.search()
      return []
    }
  }

  async isExecutable (searcherCommand) {
    if (!searcherIsAvailable) {
      const status = await this.searcher.runCommandPromisified(searcherCommand)
      searcherIsAvailable = status === 0
      if (!searcherIsAvailable) {
        const message = [
          `atom-arrow`,
          `- \`${searcherCommand}\` is not available in your PATH.`,
          `- You can choose another searcherCommand from setting of narrow.`,
          `- Or install/add \`${searcherCommand}\` to PATH`
        ].join('\n')
        atom.notifications.addWarning(message, {dismissable: true})
      }
    }
    return searcherIsAvailable
  }
}
