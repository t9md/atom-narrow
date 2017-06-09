const _ = require("underscore-plus")
const ProviderBase = require("./provider-base")
const { requireFrom } = require("../utils")

const TagGenerator = requireFrom("symbols-view", "tag-generator")

// Symbols provider depending on ctag via TagGenerator.
// Which read tag info from file on disk.
// So we cant update symbol unless it's saved on disk.
// This is very exceptional provider not supportCacheItems in spite of boundToSingleFile.

const providerConfig = {
  boundToSingleFile: true,
  showLineHeader: false,
  queryWordBoundaryOnByCurrentWordInvocation: true,
  refreshOnDidSave: true,
}

class Symbols extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  onBindEditor({ newEditor }) {
    this.items = null
    return this.subscribeEditor(newEditor.onDidSave(() => (this.items = null)))
  }

  itemForTag({ position, name }) {
    const { row } = position
    return {
      point: this.getFirstCharacterPointOfRow(row),
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
      const lineText = this.editor.lineTextForBufferRow(row)
      const match = lineText.match(/#+/)
      return match != null && match[0] != null ? match[0].length - 1 : 0
    } else {
      return this.editor.indentationForBufferRow(row)
    }
  }

  getItems() {
    if (this.items) {
      this.finishUpdateItems(this.items)
      return
    }

    // We show full line text of symbol's line, so just care for which line have symbol.
    const filePath = this.editor.getPath()
    const { scopeName } = this.editor.getGrammar()
    return new TagGenerator(filePath, scopeName).generate().then(tags => {
      tags = _.uniq(tags, tag => tag.position.row)
      this.items = tags.map(this.itemForTag.bind(this))
      return this.finishUpdateItems(this.items)
    })
  }
}

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null
    ? transform(value)
    : undefined
}

module.exports = Symbols
