const {Point} = require('atom')
const Provider = require('./provider')
const Path = require('path')
const fs = require('fs-plus')
const {limitNumber} = require('../utils')
const settings = require('../settings')

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

const Config = {
  showProjectHeader: true,
  showFileHeader: true,
  supportCacheItems: true,
  supportFilePathOnlyItemsUpdate: true,
  refreshOnDidStopChanging: true
}

module.exports = class GitDiffAll {
  constructor (state) {
    this.enabledInlineGitDiff = new Set()

    this.provider = Provider.create({
      name: this.constructor.name,
      state: state,
      config: Config,
      willOpenUi: () => {
        atom.commands.add(this.provider.ui.editor.element, {
          'narrow-ui:git-diff-all-toggle-inline-diff': () => this.toggleInlineGitDiff()
        })
      },
      didOpenItem: editor => {
        if (settings.get('GitDiffAll.inlineGitDiffIntegration')) {
          if (this.lastOpenedEditor !== editor) {
            this.lastOpenedEditor = editor
            this.enableInlineGitDiffForEditor(editor)
          }
        }
      },
      didDestroy: this.destroyInlineGitDiff.bind(this),
      getItems: this.getItems.bind(this)
    })
  }

  start (options) {
    return this.provider.start(options)
  }

  enableInlineGitDiffForEditor (editor) {
    if (Provider.service.inlineGitDiff) {
      const inlineGitDiff = Provider.service.inlineGitDiff.getInlineGitDiff(editor)
      // enable() return `false` if it's already enabled
      if (inlineGitDiff.enable()) {
        // if we enabled it, remember to disable on `narrow:close`
        this.enabledInlineGitDiff.add(inlineGitDiff)
      }
    }
  }

  destroyInlineGitDiff () {
    this.enabledInlineGitDiff.forEach(diff => diff.destroy())
    this.enabledInlineGitDiff.clear()
  }

  toggleInlineGitDiff () {
    if (!atom.packages.getLoadedPackage('inline-git-diff')) {
      require('atom-package-deps').install('narrow')
    }

    const enabled = !settings.get('GitDiffAll.inlineGitDiffIntegration')
    settings.set('GitDiffAll.inlineGitDiffIntegration', enabled)
    if (enabled) {
      this.enableInlineGitDiffForEditor(this.lastOpenedEditor || this.provider.editor)
    } else {
      this.destroyInlineGitDiff()
    }
    this.updateControlBar(enabled)
  }

  updateControlBar (value = settings.get('GitDiffAll.inlineGitDiffIntegration')) {
    this.provider.ui.controlBar.updateElements({inlineGitDiff: value})
  }

  async getItems ({filePath}) {
    this.updateControlBar()

    if (filePath) {
      const repo = repositoryForPath(filePath)
      const items = repo ? await getItemsForFilePath(repo, filePath) : []
      return items
    } else {
      const promises = []

      const repositories = atom.project.getRepositories().filter(v => v)
      for (const repo of repositories) {
        for (const filePath of getModifiedFilePathsForRepository(repo)) {
          const promise = getItemsForFilePath(repo, filePath).then(items => {
            this.provider.updateItems(items.filter(v => v))
          })
          promises.push(promise)
        }
      }
      await Promise.all(promises)
      return []
    }
  }
}
