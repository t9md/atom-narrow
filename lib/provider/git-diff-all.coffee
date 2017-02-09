_ = require 'underscore-plus'
ProviderBase = require './provider-base'
path = require 'path'
fs = require 'fs-plus'
{itemForGitDiff} = require '../utils'

# Borrowed from fuzzy-finder's git-diff-view.coffee
getGitModifiedPaths = ->
  paths = []
  for repo in atom.project.getRepositories() when repo?
    workingDirectory = repo.getWorkingDirectory()
    for filePath of repo.statuses
      filePath = path.join(workingDirectory, filePath)
      paths.push(filePath) if fs.isFileSync(filePath)
  paths

eachModifiedFilePaths = (fn) ->
  for repo in atom.project.getRepositories() when repo?
    workingDirectory = repo.getWorkingDirectory()
    for filePath of repo.statuses
      filePath = path.join(workingDirectory, filePath)
      if fs.isFileSync(filePath)
        fn(repo, filePath)

getItemsForFilePath = (repo, filePath) ->
  atom.workspace.open(filePath, activateItem: false).then (editor) ->
    # When file was completely new file, getLineDiffs return null, so need guard.
    diffs = repo.getLineDiffs(filePath, editor.getText()) ? []
    diffs.map (diff) ->
      itemForGitDiff(diff, {editor, filePath})

projectNameForFilePath = (filePath) ->
  path.basename(atom.project.relativizePath(filePath)[0])

injectProjectName = (items) ->
  for item in items
    item.projectName = projectNameForFilePath(item.filePath)
  items

getItemsWihHeaders = (_items) ->
  items = []
  for projectName, itemsInProject of _.groupBy(_items, (item) -> item?.projectName)
    header = "# #{projectName}"
    items.push({header, projectName, projectHeader: true, skip: true})

    for filePath, itemsInFile of _.groupBy(itemsInProject, (item) -> item.filePath)
      header = "## #{atom.project.relativize(filePath)}"
      items.push({header, projectName, filePath, skip: true})
      items.push(itemsInFile...)
  items

module.exports =
class GitDiffAll extends ProviderBase
  supportCacheItems: false
  includeHeaderGrammar: true
  showLineHeader: true

  getItems: ->
    promises = []
    eachModifiedFilePaths (repo, filePath) ->
      promises.push(getItemsForFilePath(repo, filePath))

    Promise.all(promises).then (items) ->
      items = _.compact(_.flatten(items))
      items = injectProjectName(items)
      getItemsWihHeaders(items)
