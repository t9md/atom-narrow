const _ = require("underscore-plus")
const ProviderBase = require("./provider-base")
const {limitNumber, getFirstCharacterPositionForBufferRow} = require("../utils")

function getCodeFoldStartRows(editor, indentLevel) {
  const {tokenizedBuffer} = editor
  const foldRanges = tokenizedBuffer
    .getFoldableRanges()
    .filter(range => !tokenizedBuffer.isRowCommented(range.start.row))
  return foldRanges.map(range => range.start.row).filter(row => editor.indentationForBufferRow(row) < indentLevel)
}

class Fold extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, {
      boundToSingleFile: true,
      foldLevel: this.getConfig("foldLevel"),
      supportCacheItems: true,
      refreshOnDidStopChanging: true,
    })
  }

  initialize() {
    const commands = {
      "narrow-ui:fold:increase-fold-level": () => this.updateFoldLevel(+1),
      "narrow-ui:fold:decrease-fold-level": () => this.updateFoldLevel(-1),
    }
    atom.commands.add(this.ui.editorElement, commands)
  }

  updateFoldLevel(relativeLevel) {
    this.foldLevel = limitNumber(this.foldLevel + relativeLevel, {min: 1})
    this.setConfig("foldLevel", this.foldLevel)
    return this.ui.refresh({force: true})
  }

  getItems() {
    const items = getCodeFoldStartRows(this.editor, this.foldLevel).map(row => {
      return {
        point: getFirstCharacterPositionForBufferRow(this.editor, row),
        text: this.editor.lineTextForBufferRow(row),
      }
    })
    this.finishUpdateItems(items)
  }
}

module.exports = Fold
