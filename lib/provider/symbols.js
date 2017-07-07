"use babel"

const _ = require("underscore-plus")
const ProviderBase = require("./provider-base")
const {requireFrom, getFirstCharacterPositionForBufferRow} = require("../utils")
const TagGenerator = requireFrom("symbols-view", "tag-generator")

// Symbols provider depending on symbols-view core package's TagGenerator.
// Which read tag info from file on disk.
// So we cant update symbol unless it's saved on disk.
// This is very exceptional provider not supportCacheItems in spite of boundToSingleFile.

function isMarkdownEditor(editor) {
  const markdownScopeName = ["source.gfm", "text.md"]
  return markdownScopeName.includes(editor.getGrammar().scopeName)
}

const providerConfig = {
  boundToSingleFile: true,
  queryWordBoundaryOnByCurrentWordInvocation: true,
  refreshOnDidSave: true,
}

class Symbols extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  onBindEditor({newEditor}) {
    this.items = null
    this.subscribeEditor(newEditor.onDidSave(() => (this.items = null)))
  }

  itemForTag({position, name}) {
    const {row} = position
    return {
      point: getFirstCharacterPositionForBufferRow(this.editor, row),
      text: "  ".repeat(this.getLevelForRow(row)) + name,
    }
  }

  isMarkdownEditor(editor) {
    const markdownScopeName = ["source.gfm", "text.md"]
    return markdownScopeName.includes(editor.getGrammar().scopeName)
  }

  getLevelForRow(row) {
    // For gfm source, determine level by counting leading '#' chars( use header level ).
    if (this.isMarkdownEditor(this.editor)) {
      const match = this.editor.lineTextForBufferRow(row).match(/#+/)
      return match ? match[0].length - 1 : 0
    } else {
      return this.editor.indentationForBufferRow(row)
    }
  }

  async getItems() {
    if (this.items) {
      this.finishUpdateItems(this.items)
      return
    }

    // We show full line text of symbol's line, so just care for which line have symbol.
    const filePath = this.editor.getPath()
    const {scopeName} = this.editor.getGrammar()

    const tags = await new TagGenerator(filePath, scopeName).generate()
    const itemForTag = this.itemForTag.bind(this)
    this.items = _.uniq(tags, tag => tag.position.row).map(itemForTag)
    this.finishUpdateItems(this.items)
  }
}

module.exports = Symbols
