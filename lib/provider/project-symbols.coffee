_ = require 'underscore-plus'
path = require 'path'
{Point, CompositeDisposable, File, Disposable} = require 'atom'

# ProjectSymbols
# =========================
# - Provide project-wide tags information.
# - Greately depending on core-package `symbols-view`
# - Since this provider bollowing many function from `symbols-view`.

ProviderBase = require './provider-base'
{requireFrom} = require '../utils'
globalSubscriptions = require '../global-subscriptions'

TagReader = requireFrom('symbols-view', 'tag-reader')
{getTagLine} = requireFrom('symbols-view', 'symbols-view').prototype
getTagsFile = requireFrom('symbols-view', './get-tags-file')

# Manage cache globally
# -------------------------
_cachedItems = null
setCachedItems = (items) -> _cachedItems = items
getCachedItems = -> _cachedItems
clearCachedItems = -> _cachedItems = null

# Watch change of tags file in outer-world
# -------------------------
watchSubscriptions = null
# Refresh watch target tags file on each execution
watchTagsFiles = ->
  unwatchTagsFiles()

  watchSubscriptions = new CompositeDisposable()
  for projectPath in atom.project.getPaths()
    tagsFilePath = getTagsFile(projectPath)
    if tagsFilePath
      tagsFile = new File(tagsFilePath)
      watchSubscriptions.add(tagsFile.onDidChange(clearCachedItems))
      watchSubscriptions.add(tagsFile.onDidDelete(clearCachedItems))
      watchSubscriptions.add(tagsFile.onDidRename(clearCachedItems))

unwatchTagsFiles = ->
  watchSubscriptions?.dispose()
  watchSubscriptions = null

# To unwatch on package deactivation.
globalSubscriptions.add new Disposable ->
  unwatchTagsFiles()

itemForTag = (tag) ->
  # Getting point at items generation timing is slow, but intentional.
  # Need to prepare point at item generation timing.
  # To support syncToEditor can compare item.point with editor's cursor position.
  # It's slower than delaying point settlement on confirm timing, but I intentionally
  # taking benefits of syncToEditor.
  # [BUG] this approach have disadvantage, need to think about following.
  # - Result is cached, so not cahange-aware
  # - Point determination by getTagLine is done by searching tags.pattern, so it resilient agains small changes.
  # - If point determined at confirmation, it less likely to land incorrect position.
  return null unless point = getTagLine(tag)
  {
    point: point
    filePath: path.join(tag.directory, tag.file)
    text: tag.name
  }

module.exports =
class ProjectSymbols extends ProviderBase
  includeHeaderGrammar: true
  supportCacheItems: false # manage manually

  destroy: ->
    @stop()
    super

  stop: ->
    @loadTagsTask?.terminate()

  getItems: ->
    @stop()
    # Refresh watching target tagFile on each execution to catch-up change in outer-world.
    watchTagsFiles()

    # Better interests suggestion? I want this less noisy.
    kindOfInterests = 'cfm'

    new Promise (resolve) =>
      cache = getCachedItems()
      if cache?
        return resolve(cache)

      @loadTagsTask = TagReader.getAllTags (tags) =>
        items = tags
          .filter (tag) -> tag.kind in kindOfInterests
          .map(itemForTag)
          .filter (item) -> item?
          .sort (a, b) -> a.point.compare(b.point)
        items = _.uniq items, (item) -> item.filePath + item.text
        items = @getItemsWithHeaders(items)
        setCachedItems(items)
        resolve(items)

  filterItems: (items, filterSpec) ->
    @getItemsWithoutUnusedHeader(super)
