const _ = require("underscore-plus")
const ProviderBase = require("./provider-base")
const {Point} = require("atom")
const {getList, getFirstCharacterPositionForBufferRow} = require("../utils")
const semver = require("semver")

function getCodeFoldRowRanges(editor) {
  if (semver.satisfies(atom.appVersion, ">=1.22.0-beta0")) {
    return editor.tokenizedBuffer
      .getFoldableRanges()
      .filter(range => !editor.tokenizedBuffer.isRowCommented(range.start.row))
      .map(range => [range.start.row, range.end.row])
  } else {
    const seen = {}
    return getList(0, editor.getLastBufferRow())
      .map(row => editor.languageMode.rowRangeForCodeFoldAtBufferRow(row))
      .filter(rowRange => rowRange && rowRange[0] != null && rowRange[1] != null)
      .filter(rowRange => (seen[rowRange] ? false : (seen[rowRange] = true)))
  }
}

function getCodeFoldStartRows(editor, indentLevel) {
  return getCodeFoldRowRanges(editor)
    .map(([startRow, endRow]) => startRow)
    .filter(startRow => editor.indentationForBufferRow(startRow) < indentLevel)
}

const providerConfig = {
  boundToSingleFile: true,
  foldLevel: 2,
  supportCacheItems: true,
  refreshOnDidStopChanging: true,
}

class Fold extends ProviderBase {
  constructor(...args) {
    super(...args)
    Object.assign(this, providerConfig)
  }

  initialize() {
    const commands = {
      "narrow-ui:fold:increase-fold-level": () => this.updateFoldLevel(+1),
      "narrow-ui:fold:decrease-fold-level": () => this.updateFoldLevel(-1),
    }
    atom.commands.add(this.ui.editorElement, commands)
  }

  updateFoldLevel(relativeLevel) {
    this.foldLevel = Math.max(0, this.foldLevel + relativeLevel)
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
