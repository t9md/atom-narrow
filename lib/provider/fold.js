const _ = require("underscore-plus")
const ProviderBase = require("./provider-base")
const { Point } = require("atom")
const { arrayForRange } = require("../utils")

function getCodeFoldStartRows(editor, indentLevel) {
  return arrayForRange(0, editor.getLastBufferRow())
    .map(row => editor.languageMode.rowRangeForCodeFoldAtBufferRow(row))
    .filter(rowRange => rowRange && rowRange[0] != null && rowRange[1] != null)
    .map(([startRow, endRow]) => startRow)
    .filter(startRow => editor.indentationForBufferRow(startRow) < indentLevel)
}

const providerConfig = {
  boundToSingleFile: true,
  showLineHeader: false,
  foldLevel: 2,
  supportCacheItems: true,
  refreshOnDidStopChanging: true,
}

module.exports = class Fold extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  initialize() {
    atom.commands.add(this.ui.editorElement, {
      "narrow-ui:fold:increase-fold-level": () => this.updateFoldLevel(+1),
      "narrow-ui:fold:decrease-fold-level": () => this.updateFoldLevel(-1),
    })
  }

  updateFoldLevel(relativeLevel) {
    this.foldLevel = Math.max(0, this.foldLevel + relativeLevel)
    return this.ui.refresh({ force: true })
  }

  getItems() {
    const items = getCodeFoldStartRows(this.editor, this.foldLevel).map(row => {
      return {
        point: this.getFirstCharacterPointOfRow(row),
        text: this.editor.lineTextForBufferRow(row),
      }
    })

    return this.finishUpdateItems(items)
  }
}
