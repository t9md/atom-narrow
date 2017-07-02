/** @babel */

const _ = require("underscore-plus")
const ProviderBase = require("./provider-base")
const path = require("path")
const fs = require("fs-plus")
const {itemForGitDiff} = require("../utils")

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

async function getItemsForFilePath(repo, filePath) {
  const editor = await atom.workspace.open(filePath, {activateItem: false})
  // When file was completely new file, getLineDiffs return null, so need guard.
  let diffs = repo.getLineDiffs(filePath, editor.getText())
  if (diffs) {
    return diffs.map(diff => itemForGitDiff(diff, {editor, filePath}))
  } else {
    return []
  }
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
