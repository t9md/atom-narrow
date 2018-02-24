const _ = require('underscore-plus')
const Provider = require('./provider')
const {requireFrom, getFirstCharacterPositionForBufferRow} = require('../utils')
const TagGenerator = requireFrom('symbols-view', 'tag-generator')

// Symbols provider depending on symbols-view core package's TagGenerator.
// Which read tag info from file on disk.
// So we cant update symbol unless it's saved on disk.
// This is very exceptional provider not supportCacheItems in spite of boundToSingleFile.
const MARKDOWN_SCOPE_NAME = ['source.gfm', 'text.md']

function itemForTag (editor, {position, name}) {
  const {scopeName} = editor.getGrammar()

  let indentLevel
  if (MARKDOWN_SCOPE_NAME.includes(scopeName)) {
    // For gfm source, determine level by counting leading '#' chars( header level ).
    const match = editor.lineTextForBufferRow(position.row).match(/#+/)
    indentLevel = match ? match[0].length - 1 : 0
  } else {
    indentLevel = editor.indentationForBufferRow(position.row)
  }

  return {
    point: getFirstCharacterPositionForBufferRow(editor, position.row),
    text: '  '.repeat(indentLevel) + name
  }
}

const Config = {
  boundToSingleFile: true,
  queryWordBoundaryOnByCurrentWordInvocation: true,
  refreshOnDidSave: true
}

module.exports = class Symbols {
  constructor (state) {
    this.provider = Provider.create({
      name: this.constructor.name,
      state: state,
      config: Config,
      didBindEditor: this.didBindEditor.bind(this),
      getItems: this.getItems.bind(this)
    })
  }

  start (options) {
    return this.provider.start(options)
  }

  didBindEditor ({newEditor}) {
    this.provider.subscribeEditor(
      newEditor.onDidSave(() => {
        this.items = null // invalidate cache
      })
    )
  }

  async getItems () {
    if (!this.items) {
      // We show full line text of symbol's line, so just care for which line have symbol.
      const editor = this.provider.editor
      const tags = await new TagGenerator(editor.getPath(), editor.getGrammar().scopeName).generate()
      this.items = _.uniq(tags, tag => tag.position.row).map(tag => itemForTag(editor, tag))
    }
    return this.items
  }
}
