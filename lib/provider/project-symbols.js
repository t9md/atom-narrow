"use babel"
const _ = require("underscore-plus")
const path = require("path")
const {CompositeDisposable, File, Disposable} = require("atom")

// ProjectSymbols
// =========================
// - Provide project-wide tags information.
// - Greately depending on core-package `symbols-view`
// - Since this provider bollowing many function from `symbols-view`.

const ProviderBase = require("./provider-base")
const {requireFrom, compareByPoint} = require("../utils")
const globalSubscriptions = require("../global-subscriptions")

const TagReader = requireFrom("symbols-view", "tag-reader")
const {getTagLine} = requireFrom("symbols-view", "symbols-view").prototype
const getTagsFile = requireFrom("symbols-view", "./get-tags-file")

// Manage cache globally
// -------------------------
let _cachedItems = null
const setCachedItems = items => (_cachedItems = items)
const getCachedItems = () => _cachedItems
const clearCachedItems = () => (_cachedItems = null)

// Watch change of tags file in outer-world
// -------------------------
let watchSubscriptions = null
// Refresh watch target tags file on each execution
function watchTagsFiles() {
  unwatchTagsFiles()

  watchSubscriptions = new CompositeDisposable()
  for (const projectPath of atom.project.getPaths()) {
    const tagsFilePath = getTagsFile(projectPath)
    if (tagsFilePath) {
      const tagsFile = new File(tagsFilePath)
      watchSubscriptions.add(tagsFile.onDidChange(clearCachedItems))
      watchSubscriptions.add(tagsFile.onDidDelete(clearCachedItems))
      watchSubscriptions.add(tagsFile.onDidRename(clearCachedItems))
    }
  }
}

function unwatchTagsFiles() {
  if (watchSubscriptions) watchSubscriptions.dispose()
  watchSubscriptions = null
}

// To unwatch on package deactivation.
globalSubscriptions.add(new Disposable(unwatchTagsFiles))

const itemForTag = function(tag) {
  // Getting point at items generation timing is slow, but intentional.
  // Need to prepare point at item generation timing.
  // To support syncToEditor can compare item.point with editor's cursor position.
  // It's slower than delaying point settlement on confirm timing, but I intentionally
  // taking benefits of syncToEditor.
  // [BUG] this approach have disadvantage, need to think about following.
  // - Result is cached, so not cahange-aware
  // - Point determination by getTagLine is done by searching tags.pattern, so it resilient agains small changes.
  // - If point determined at confirmation, it less likely to land incorrect position.
  return {
    point: getTagLine(tag),
    filePath: path.join(tag.directory, tag.file),
    text: tag.name,
    refreshPoint() {
      this.point = getTagLine(tag)
    },
  }
}

const providerConfig = {
  showProjectHeader: true,
  showFileHeader: true,
  queryWordBoundaryOnByCurrentWordInvocation: true,
  refreshOnDidSave: true,
}

class ProjectSymbols extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  onBindEditor({newEditor}) {
    // Refresh item.point in cachedItems for saved filePath.
    this.subscribeEditor(newEditor.onDidSave(refreshPointForFilePath))

    function refreshPointForFilePath(event) {
      const items = getCachedItems()
      if (!items) return

      const filePath = event.path
      items.filter(item => item.filePath === filePath).map(item => item.refreshPoint())
    }
  }

  destroy() {
    this.stop()
    super.destroy()
  }

  stop() {
    if (this.loadTagsTask) {
      this.loadTagsTask.terminate()
      this.loadTagsTask = null
    }
  }

  initialize() {
    // When user manually refresh, clear cache
    this.subscriptions.add(this.ui.onWillRefreshManually(clearCachedItems))
  }

  readTags() {
    return new Promise(resolve => {
      this.loadTagsTask = TagReader.getAllTags(resolve)
    })
  }

  async getItems() {
    this.stop()
    // Refresh watching target tagFile on each execution to catch-up change in outer-world.
    watchTagsFiles()

    const cache = getCachedItems()
    if (cache) {
      this.finishUpdateItems(cache)
      return
    }

    const tags = await this.readTags()

    // Better interests suggestion? I want this less noisy.
    const kindOfInterests = "cfm"
    let items = tags
      .filter(tag => kindOfInterests.includes(tag.kind))
      .map(itemForTag)
      .filter(item => item.point != null)
      .sort(compareByPoint)
    items = _.uniq(items, item => item.filePath + item.text)
    setCachedItems(items)
    this.finishUpdateItems(items)
  }
}
module.exports = ProjectSymbols
