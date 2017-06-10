const ProviderBase = require("./provider-base")
const {getProjectPaths} = require("../utils")
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
  searchInOrdered: false, // NOTE: This is set to true in spec to test easily
}

class Search extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
    this.updateItemsIfNotModified = this.updateItemsIfNotModified.bind(this)
    this.updateItems = this.updateItems.bind(this)
  }

  getState() {
    return this.mergeState(super.getState(), {projects: this.projects})
  }

  checkReady() {
    if (this.reopened) return true

    if (!this.projects) {
      this.projects = getProjectPaths(
        this.options.currentProject ? this.editor : null
      )
    }
    return this.projects
  }

  initialize() {
    this.searcher = new Searcher(this.searchOptions)
  }

  searchFilePath(filePath) {
    const {searchRegex} = this.searchOptions
    this.scanItemsForFilePath(filePath, searchRegex).then(items =>
      this.finishUpdateItems(items)
    )
  }

  search() {
    const projectsToSearch = this.projects.slice()
    const modifiedBuffers = atom.project
      .getBuffers()
      .filter(buffer => buffer.isModified() && buffer.getPath())
    const modifiedBuffersScanned = []
    const {searchRegex} = this.searchOptions

    const scanBuffer = buffer => {
      if (modifiedBuffersScanned.includes(buffer)) return

      this.updateItems(this.scanItemsForBuffer(buffer, searchRegex))
      modifiedBuffersScanned.push(buffer)
    }

    let finished = 0
    const onFinish = project => {
      finished++
      // project += path.sep
      // Append directory separator to avoid unwanted partial match.
      // make `atom` to `atom/` to avoid matches to project name like `atom-keymaps`.
      project += path.sep
      const isSameProject = buffer => buffer.getPath().startsWith(project)
      modifiedBuffers.filter(isSameProject).map(scanBuffer)

      if (projectsToSearch.length) {
        searchNextProject()
      } else {
        if (finished === this.projects.length) {
          modifiedBuffers.map(scanBuffer)
          return this.finishUpdateItems()
        }
      }
    }

    const searchNextProject = () => {
      this.searcher.searchProject(
        projectsToSearch.shift(),
        this.updateItemsIfNotModified,
        onFinish
      )
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

  getItems({filePath}) {
    this.searcher.cancel()
    this.updateSearchState()
    this.searcher.setCommand(this.getConfig("searcher"))
    this.ui.grammar.update()

    if (this.searchOptions.searchRegex) {
      if (filePath) {
        if (!atom.project.contains(filePath)) {
          // When non project file was saved. We have nothing todo, so just return old @items.
          this.finishUpdateItems([])
        } else {
          this.searchFilePath(filePath)
        }
      } else {
        this.search()
      }
    } else {
      this.finishUpdateItems([])
    }
  }
}
module.exports = Search
