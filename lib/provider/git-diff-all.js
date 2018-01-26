'use babel'

const {Point, Disposable} = require('atom')
const ProviderBase = require('./provider-base')
const Path = require('path')
const fs = require('fs-plus')
const {limitNumber} = require('../utils')

function getModifiedFilePathsForRepository (repository) {
  const dir = repository.getWorkingDirectory()
  return Object.keys(repository.statuses)
    .map(filePath => Path.join(dir, filePath))
    .filter(fs.isFileSync)
}

function itemForGitDiff (diff, {buffer, filePath}) {
  const row = limitNumber(diff.newStart - 1, {min: 0})
  const lineText = buffer.lineForRow(row)
  return {
    point: new Point(row, lineText.match(/\s*/)[0].length),
    text: lineText,
    filePath: filePath
  }
}

async function getItemsForFilePath (repo, filePath) {
  const existingBuffer = atom.project.findBufferForPath(filePath)
  const buffer = existingBuffer || (await atom.project.buildBuffer(filePath))
  const diffs = repo.getLineDiffs(filePath, buffer.getText())
  // When file was completely new file, getLineDiffs return null, so need guard.
  const result = diffs ? diffs.map(diff => itemForGitDiff(diff, {buffer, filePath})) : []
  if (!existingBuffer) buffer.destroy()

  return result
}

// Borrowed from git-diff core pacakge.
function repositoryForPath (filePath) {
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
  refreshOnDidStopChanging: true
}

module.exports = class GitDiffAll extends ProviderBase {
  constructor (...args) {
    super(...args)
    Object.assign(this, providerConfig)
    this.enabledInlineGitDiff = new Set()
    this.subscriptions.add(new Disposable(() => this.destroyEnabledInlineGitDiff()))
    this.toggleInlineGitDiff = this.toggleInlineGitDiff.bind(this)
  }

  onItemOpened (editor) {
    if (this.getConfig('inlineGitDiffIntegration')) {
      if (this.lastOpenedEditor !== editor) {
        this.lastOpenedEditor = editor
        this.enabledInlineGitDiffForEditor(editor)
      }
    }
  }

  enabledInlineGitDiffForEditor (editor) {
    if (this.service.inlineGitDiff) {
      const inlineGitDiff = this.service.inlineGitDiff.getInlineGitDiff(editor)
      // If inlineGitDiff was NOT already enabled we dispose it on narrow:close
      if (inlineGitDiff.enable()) {
        this.enabledInlineGitDiff.add(inlineGitDiff)
      }
    }
  }

  destroyEnabledInlineGitDiff () {
    this.enabledInlineGitDiff.forEach(diff => diff.destroy())
    this.enabledInlineGitDiff.clear()
  }

  toggleInlineGitDiff () {
    if (!atom.packages.getLoadedPackage('inline-git-diff')) {
      require('atom-package-deps').install('narrow')
    }

    const enabled = !this.getConfig('inlineGitDiffIntegration')
    this.setConfig('inlineGitDiffIntegration', enabled)
    if (enabled) {
      this.enabledInlineGitDiffForEditor(this.lastOpenedEditor || this.editor)
    } else {
      this.destroyEnabledInlineGitDiff()
    }
    this.updateControlBar(enabled)
  }

  updateControlBar (value = this.getConfig('inlineGitDiffIntegration')) {
    this.ui.controlBar.updateElements({inlineGitDiff: value})
  }

  getItems ({filePath}) {
    this.updateControlBar()

    if (filePath) {
      const repo = repositoryForPath(filePath)
      if (repo) {
        getItemsForFilePath(repo, filePath).then(this.finishUpdateItems)
      } else {
        this.finishUpdateItems([])
      }
    } else {
      const promises = []
      const updateItems = items => this.updateItems(items.filter(v => v))

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
