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

const providerConfig = {
  refreshOnDidSave: true,
  showProjectHeader: true,
  showFileHeader: true,
}

class GitDiffAll extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  getItems() {
    const promises = []
    const repositories = atom.project
      .getRepositories()
      .filter(repo => repo != null)

    const updateItems = items => this.updateItems(_.compact(items))
    for (const repo of repositories) {
      for (const filePath of getModifiedFilePathsForRepository(repo)) {
        const promise = getItemsForFilePath(repo, filePath).then(updateItems)
        promises.push(promise)
      }
    }
    Promise.all(promises).then(() => this.finishUpdateItems())
  }
}
module.exports = GitDiffAll
