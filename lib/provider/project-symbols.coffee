_ = require 'underscore-plus'
path = require 'path'
{CompositeDisposable, File, Disposable} = require 'atom'

# ProjectSymbols
# =========================
# - Provide project-wide tags information.
# - Greately depending on core-package `symbols-view`
# - Since this provider bollowing many function from `symbols-view`.

ProviderBase = require './provider-base'
{requireFrom, compareByPoint} = require '../utils'
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
  {
    point: getTagLine(tag)
    filePath: path.join(tag.directory, tag.file)
    text: tag.name
    refreshPoint: -> @point = getTagLine(tag)
  }

module.exports =
class ProjectSymbols extends ProviderBase
  showLineHeader: false
  queryWordBoundaryOnByCurrentWordInvocation: true

  onBindEditor: ({newEditor}) ->
    # Refresh item.point in cachedItems for saved filePath.
    @subscribeEditor newEditor.onDidSave (event) ->
      return unless items = getCachedItems()
      filePath = event.path
      for item in items when item.filePath is filePath
        item.refreshPoint()

  destroy: ->
    @stop()
    super

  stop: ->
    @loadTagsTask?.terminate()

  initialize: ->
    # When user manually refresh, clear cache
    @subscriptions.add @ui.onWillRefreshManually(clearCachedItems)

  readTags: ->
    new Promise (resolve) =>
      @loadTagsTask = TagReader.getAllTags (tags) ->
        resolve(tags)

  getItems: ->
    @stop()
    # Refresh watching target tagFile on each execution to catch-up change in outer-world.
    watchTagsFiles()

    return cache if cache = getCachedItems()

    @readTags().then (tags) ->
      # Better interests suggestion? I want this less noisy.
      kindOfInterests = 'cfm'

      items = tags
        .filter (tag) -> tag.kind in kindOfInterests
        .map(itemForTag)
        .filter (item) -> item.point?
        .sort(compareByPoint)
      items = _.uniq items, (item) -> item.filePath + item.text
      setCachedItems(items)
      items
