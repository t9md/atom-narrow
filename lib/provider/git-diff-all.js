"use babel"

const {Point} = require("atom")
const _ = require("underscore-plus")
const ProviderBase = require("./provider-base")
const path = require("path")
const fs = require("fs-plus")
const {limitNumber, getFirstCharacterPositionForBufferRow} = require("../utils")

function getModifiedFilePathsForRepository(repository) {
  const filePaths = []

  const workingDirectory = repository.getWorkingDirectory()
  for (let filePath in repository.statuses) {
    filePath = path.join(workingDirectory, filePath)
    if (fs.isFileSync(filePath)) {
      filePaths.push(filePath)
    }
  }

  return filePaths
}

function itemForGitDiff(diff, {buffer, filePath}) {
  const row = limitNumber(diff.newStart - 1, {min: 0})
  const lineText = buffer.lineForRow(row)
  return {
    point: new Point(row, lineText.match(/\s*/)[0].length),
    text: lineText,
    filePath: filePath,
  }
}

async function getItemsForFilePath(repo, filePath) {
  const existingBuffer = atom.project.findBufferForPath(filePath)
  const buffer = existingBuffer || (await atom.project.buildBuffer(filePath))
  const diffs = repo.getLineDiffs(filePath, buffer.getText())
  // When file was completely new file, getLineDiffs return null, so need guard.
  const result = diffs ? diffs.map(diff => itemForGitDiff(diff, {buffer, filePath})) : []
  if (!existingBuffer) buffer.destroy()

  return result
}

// Borrowed from git-diff core pacakge.
function repositoryForPath(filePath) {
  const directories = atom.project.getDirectories()
  for (let i = 0; i < directories.length; i++) {
    const directory = directories[i]
    if (filePath === directory.getPath() || directory.contains(filePath)) {
      return atom.project.getRepositories()[i]
    }
  }
}

const providerConfig = {
  showProjectHeader: true,
  showFileHeader: true,
  supportCacheItems: true,
  supportFilePathOnlyItemsUpdate: true,
  refreshOnDidStopChanging: true,
}

class GitDiffAll extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  getItems({filePath}) {
    if (filePath) {
      const repo = repositoryForPath(filePath)
      if (repo) {
        getItemsForFilePath(repo, filePath).then(this.finishUpdateItems)
      } else {
        this.finishUpdateItems([])
      }
    } else {
      const promises = []
      const updateItems = items => this.updateItems(_.compact(items))

      const repositories = atom.project.getRepositories().filter(repo => repo != null)
      for (const repo of repositories) {
        for (const filePath of getModifiedFilePathsForRepository(repo)) {
          const promise = getItemsForFilePath(repo, filePath).then(updateItems)
          promises.push(promise)
        }
      }
      Promise.all(promises).then(() => this.finishUpdateItems())
    }
  }
}
module.exports = GitDiffAll
