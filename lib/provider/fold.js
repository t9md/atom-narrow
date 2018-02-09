const ProviderBase = require('./provider-base')
const {limitNumber, getFirstCharacterPositionForBufferRow} = require('../utils')

function getCodeFoldStartRows (editor, indentLevel) {
  const {tokenizedBuffer} = editor
  return tokenizedBuffer
    .getFoldableRanges(1)
    .filter(range => !tokenizedBuffer.isRowCommented(range.start.row))
    .map(range => range.start.row)
    .filter(row => editor.indentationForBufferRow(row) < indentLevel)
}

module.exports = class Fold extends ProviderBase {
  constructor (...args) {
    super(...args)
    Object.assign(this, {
      boundToSingleFile: true,
      foldLevel: this.getConfig('foldLevel'),
      supportCacheItems: true,
      refreshOnDidStopChanging: true
    })
  }

  initialize () {
    atom.commands.add(this.ui.editorElement, {
      'narrow-ui:fold-increase-level': () => this.updateFoldLevel(+1),
      'narrow-ui:fold-decrease-level': () => this.updateFoldLevel(-1)
    })
  }

  updateFoldLevel (relativeLevel) {
    this.foldLevel = limitNumber(this.foldLevel + relativeLevel, {min: 1})
    this.setConfig('foldLevel', this.foldLevel)
    return this.ui.refresh({force: true})
  }

  getItems () {
    const foldStartRows = getCodeFoldStartRows(this.editor, this.foldLevel)
    this.finishUpdateItems(
      foldStartRows.map(row => ({
        point: getFirstCharacterPositionForBufferRow(this.editor, row),
        text: this.editor.lineTextForBufferRow(row)
      }))
    )
  }
}
