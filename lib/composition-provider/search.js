'use babel'

const Provider = require('./provider')
const {getProjectPaths, scanItemsForFilePath, scanItemsForBuffer} = require('../utils')

const Searcher = require('../searcher')
const Path = require('path')
const _ = require('underscore-plus')

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
  static searcherIsAvailable = false

  constructor (...args) {
    // FIXME: This is set to true in spec to test easily
    this.searchInOrdered = atom.inSpecMode()

    this.provider = Provider.create({
      name: this.constructor.name,
      config: Config,
      getItems: this.getItems.bind(this),
      onDestroyed: () => {
        if (this.searcher) {
          this.searcher.cancel()
          this.searcher = null
        }
      }
    })
  }

  start (options) {
    this.projects = this.projects || getProjectPaths(options.currentProject ? this.provider.editor : null)
    if (this.projects) {
      this.searcher = new Searcher(this.provider.searchOptions)
      this.provider.start(options)
    }
  }

  // getState () {
  //   return this.mergeState(super.getState(), {projects: this.projects})
  // }

  search () {
    const projectsToSearch = this.projects.slice()
    const modifiedBuffers = atom.project.getBuffers().filter(buffer => buffer.isModified() && buffer.getPath())
    const modifiedBuffersScanned = new Set()
    const {searchRegex} = this.provider.searchOptions

    const scanBuffer = buffer => {
      if (!modifiedBuffersScanned.includes(buffer)) {
        this.updateItems(scanItemsForBuffer(buffer, searchRegex))
        modifiedBuffersScanned.push(buffer)
      }
    }

    let finished = 0
    const onFinish = project => {
      finished++
      // Append directory separator to avoid unwanted partial match.
      // make `atom` to `atom/` to avoid matches to project name like `atom-keymaps`.
      const isSameProject = buffer => buffer.getPath().startsWith(project + Path.sep)
      modifiedBuffers.filter(isSameProject).forEach(scanBuffer)

      if (projectsToSearch.length) {
        searchNextProject()
        return
      }

      if (finished === this.projects.length) {
        this.provider.finishUpdateItems()
      }
    }

    const updateItemsIfNotModified = items => {
      items = items.filter(item => !atom.project.isPathModified(item.filePath))
      this.updateItems(items)
    }

    const searchNextProject = () => {
      this.searcher.searchProject(projectsToSearch.shift(), updateItemsIfNotModified, onFinish)
    }

    if (this.searchInOrdered) {
      searchNextProject()
    } else {
      while (projectsToSearch.length) searchNextProject()
    }
  }

  updateItems (items) {
    if (this.searchInOrdered) items = _.sortBy(items, item => item.filePath)
    this.provider.updateItems(items)
  }

  async getItems ({filePath}) {
    this.searcher.cancel()
    const searcher = this.provider.getConfig('searcher')

    const executable = await !this.isExecutable(searcher)
    if (!executable || !this.provider.searchOptions) {
      return this.provider.finishUpdateItems([])
    }

    const {searchRegex} = this.provider.searchOptions
    if (!searchRegex) {
      return this.provider.finishUpdateItems([])
    }

    this.searcher.setCommand(searcher)
    if (filePath) {
      if (atom.project.contains(filePath)) {
        this.provider.finishUpdateItems(await scanItemsForFilePath(filePath, searchRegex))
      } else {
        this.provider.finishUpdateItems([])
      }
    } else {
      this.search()
    }
  }

  async isExecutable (searcherCommand) {
    if (!this.constructor.searcherIsAvailable) {
      const status = await this.searcher.runCommandPromisified(searcherCommand)
      this.constructor.searcherIsAvailable = status === 0
      if (!this.constructor.searcherIsAvailable) {
        const message = [
          `atom-arrow`,
          `- \`${searcherCommand}\` is not available in your PATH.`,
          `- You can choose another searcherCommand from setting of narrow.`,
          `- Or install/add \`${searcherCommand}\` to PATH`
        ].join('\n')
        atom.notifications.addWarning(message, {dismissable: true})
      }
    }
    return this.constructor.searcherIsAvailable
  }
}
