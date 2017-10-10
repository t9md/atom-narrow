"use babel"

const ProviderBase = require("./provider-base")
const {getProjectPaths, scanItemsForFilePath, scanItemsForBuffer} = require("../utils")

const Searcher = require("../searcher")
const path = require("path")
const _ = require("underscore-plus")

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

class Search extends ProviderBase {
  static searcherIsAvailable = false

  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
    this.updateItemsIfNotModified = this.updateItemsIfNotModified.bind(this)
    this.updateItems = this.updateItems.bind(this)

    // FIXME: This is set to true in spec to test easily
    this.searchInOrdered = atom.inSpecMode()
  }

  getState() {
    return this.mergeState(super.getState(), {projects: this.projects})
  }

  checkReady() {
    if (this.reopened) return true

    if (!this.projects) {
      this.projects = getProjectPaths(this.options.currentProject ? this.editor : null)
    }
    return this.projects
  }

  initialize() {
    this.searcher = new Searcher(this.searchOptions)
  }

  search() {
    const projectsToSearch = this.projects.slice()
    const modifiedBuffers = atom.project.getBuffers().filter(buffer => buffer.isModified() && buffer.getPath())
    const modifiedBuffersScanned = []
    const {searchRegex} = this.searchOptions

    const scanBuffer = buffer => {
      if (modifiedBuffersScanned.includes(buffer)) return

      this.updateItems(scanItemsForBuffer(buffer, searchRegex))
      modifiedBuffersScanned.push(buffer)
    }

    let finished = 0
    const onFinish = project => {
      finished++
      // project += path.sep
      // Append directory separator to avoid unwanted partial match.
      // make `atom` to `atom/` to avoid matches to project name like `atom-keymaps`.
      const isSameProject = buffer => buffer.getPath().startsWith(project + path.sep)
      modifiedBuffers.filter(isSameProject).map(scanBuffer)

      if (projectsToSearch.length) {
        searchNextProject()
        return
      }

      if (finished === this.projects.length) this.finishUpdateItems()
    }

    const searchNextProject = () => {
      this.searcher.searchProject(projectsToSearch.shift(), this.updateItemsIfNotModified, onFinish)
    }

    if (this.searchInOrdered) {
      searchNextProject()
    } else {
      while (projectsToSearch.length) searchNextProject()
    }
  }

  updateItemsIfNotModified(items) {
    items = items.filter(item => !atom.project.isPathModified(item.filePath))
    this.updateItems(items)
  }

  updateItems(items) {
    if (this.searchInOrdered) items = _.sortBy(items, item => item.filePath)
    super.updateItems(items)
  }

  destroy() {
    this.searcher.cancel()
    this.searcher = null
    super.destroy()
  }

  async getItems({filePath}) {
    this.searcher.cancel()
    const searcher = this.getConfig("searcher")

    if (!this.constructor.searcherIsAvailable) {
      const status = await this.searcher.runCommandPromisified(searcher)
      this.constructor.searcherIsAvailable = status === 0
      if (!this.constructor.searcherIsAvailable) {
        const message = [
          `atom-arrow`,
          `- \`${searcher}\` is not available in your PATH.`,
          `- You can choose another searcher from setting of narrow.`,
          `- Or install/add \`${searcher}\` to PATH`,
        ].join("\n")
        atom.notifications.addWarning(message, {dismissable: true})
        return this.finishUpdateItems([])
      }
    }

    this.searcher.setCommand(searcher)

    const {searchRegex} = this.searchOptions

    if (!searchRegex) {
      return this.finishUpdateItems([])
    }

    if (filePath) {
      const items = atom.project.contains(filePath) ? await scanItemsForFilePath(filePath, searchRegex) : []
      this.finishUpdateItems(items)
    } else {
      this.search()
    }
  }
}
module.exports = Search
