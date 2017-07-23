_ = require 'underscore-plus'
{Point} = require "atom"
ProviderBase = require './provider-base'
path = require 'path'
fs = require 'fs-plus'
{limitNumber} = require '../utils'

# Borrowed and modified from fuzzy-finder's git-diff-view.coffee
eachModifiedFilePaths = (fn) ->
  for repo in atom.project.getRepositories() when repo?
    workingDirectory = repo.getWorkingDirectory()
    for filePath of repo.statuses
      filePath = path.join(workingDirectory, filePath)
      if fs.isFileSync(filePath)
        fn(repo, filePath)

itemForGitDiff = (diff, {buffer, filePath}) ->
  row = limitNumber(diff.newStart - 1, min: 0)
  lineText = buffer.lineForRow(row)
  {
    point: new Point(row, lineText.match(/\s*/)[0].length)
    text: lineText
    filePath: filePath
  }

getItemsForFilePath = (repo, filePath) ->
  existingBuffer = atom.project.findBufferForPath(filePath)
  Promise.resolve(existingBuffer ? atom.project.buildBuffer(filePath)).then (buffer) ->
    diffs = repo.getLineDiffs(filePath, buffer.getText()) ? []
    # When file was completely new file, getLineDiffs return null, so need guard.
    items = diffs.map (diff) -> itemForGitDiff(diff, {buffer, filePath})
    buffer.destroy() unless existingBuffer?
    return items

module.exports =
class GitDiffAll extends ProviderBase
  refreshOnDidSave: true
  showProjectHeader: true
  showFileHeader: true

  getItems: ->
    promises = []
    eachModifiedFilePaths (repo, filePath) =>
      promise = getItemsForFilePath(repo, filePath).then (items) =>
        @updateItems(_.compact(items))
      promises.push(promise)

    Promise.all(promises).then =>
      @finishUpdateItems()
