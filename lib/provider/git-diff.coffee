ProviderBase = require './provider-base'
{itemForGitDiff} = require '../utils'

# Borrowed from git-diff core pacakge.
repositoryForPath = (goalPath) ->
  for directory, i in atom.project.getDirectories()
    if goalPath is directory.getPath() or directory.contains(goalPath)
      return atom.project.getRepositories()[i]
  null

module.exports =
class GitDiff extends ProviderBase
  boundToSingleFile: true
  supportCacheItems: true

  getItems: ->
    filePath = @editor.getPath()
    diffs = repositoryForPath(filePath)?.getLineDiffs(filePath, @editor.getText()) ? []
    diffs.map (diff) =>
      itemForGitDiff(diff, {@editor, filePath})
