const _ = require('underscore-plus')
const Path = require('path')
const {CompositeDisposable, File, Disposable} = require('atom')

// ProjectSymbols
// =========================
// - Provide project-wide tags information.
// - Greately depending on core-package `symbols-view`
// - Since this provider bollowing many function from `symbols-view`.

const Provider = require('./provider')
const {requireFrom, compareByPoint} = require('../utils')
const globalSubscriptions = require('../global-subscriptions')

const TagReader = requireFrom('symbols-view', 'tag-reader')
const {getTagLine} = requireFrom('symbols-view', 'symbols-view').prototype
const getTagsFile = requireFrom('symbols-view', './get-tags-file')

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
function watchTagsFiles () {
  unwatchTagsFiles()

  watchSubscriptions = new CompositeDisposable()
  for (const projectPath of atom.project.getPaths()) {
    const tagsFilePath = getTagsFile(projectPath)
    if (tagsFilePath) {
      const tagsFile = new File(tagsFilePath)
      watchSubscriptions.add(
        tagsFile.onDidChange(clearCachedItems),
        tagsFile.onDidDelete(clearCachedItems),
        tagsFile.onDidRename(clearCachedItems)
      )
    }
  }
}

function unwatchTagsFiles () {
  if (watchSubscriptions) watchSubscriptions.dispose()
  watchSubscriptions = null
}

// To unwatch on package deactivation.
globalSubscriptions.add(new Disposable(unwatchTagsFiles))

const itemForTag = function (tag) {
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
    filePath: Path.join(tag.directory, tag.file),
    text: tag.name,
    refreshPoint () {
      this.point = getTagLine(tag)
    }
  }
}

function refreshPointForFilePath (event) {
  const items = getCachedItems()
  if (items) {
    const filePath = event.path
    items.filter(item => item.filePath === filePath).forEach(item => item.refreshPoint())
  }
}

const Config = {
  showProjectHeader: true,
  showFileHeader: true,
  queryWordBoundaryOnByCurrentWordInvocation: true,
  refreshOnDidSave: true
}

module.exports = class ProjectSymbols {
  constructor (state) {
    this.provider = Provider.create({
      name: this.constructor.name,
      state: state,
      config: Config,
      willOpenUi: () => {
        // When user manually refresh, clear cache
        this.provider.subscriptions.add(this.provider.ui.onWillRefreshManually(clearCachedItems))
      },
      didBindEditor: this.didBindEditor.bind(this),
      didDestroy: this.stop.bind(this),
      getItems: this.getItems.bind(this)
    })
  }

  didBindEditor ({newEditor}) {
    // Refresh item.point in cachedItems for saved filePath.
    this.provider.subscribeEditor(newEditor.onDidSave(refreshPointForFilePath))
  }

  start (options) {
    return this.provider.start(options)
  }

  stop () {
    if (this.loadTagsTask) {
      this.loadTagsTask.terminate()
      this.loadTagsTask = null
    }
  }

  async getItems () {
    this.stop()
    // Refresh watching target tagFile on each execution to catch-up change in outer-world.
    watchTagsFiles()

    let items = getCachedItems()
    if (!items) {
      const tags = await new Promise(resolve => {
        this.loadTagsTask = TagReader.getAllTags(resolve)
      })

      // Better interests suggestion? I want this less noisy.
      // kinds cab be listed by `ctags --list-kinds`
      const kindOfInterests = 'cfmr'
      items = tags
        .filter(tag => kindOfInterests.includes(tag.kind))
        .map(itemForTag)
        .filter(item => item.point != null)
        .sort(compareByPoint)
      items = _.uniq(items, item => item.filePath + item.text)
      setCachedItems(items)
    }

    return items
  }
}
