/** @babel */
import _ from "underscore-plus"
import ProviderBase from "./provider-base"

import { Point } from "atom"
import { arrayForRange } from "../utils"

function getCodeFoldStartRows(editor, indentLevel) {
  return arrayForRange(0, editor.getLastBufferRow())
    .map(row => editor.languageMode.rowRangeForCodeFoldAtBufferRow(row))
    .filter(rowRange => rowRange && rowRange[0] != null && rowRange[1] != null)
    .map(([startRow, endRow]) => startRow)
    .filter(startRow => editor.indentationForBufferRow(startRow) < indentLevel)
}

export default class Fold extends ProviderBase {
  boundToSingleFile = true
  showLineHeader = false
  foldLevel = 2
  supportCacheItems = true
  refreshOnDidStopChanging = true

  initialize() {
    const commands = {
      "narrow-ui:fold:increase-fold-level": () => this.updateFoldLevel(+1),
      "narrow-ui:fold:decrease-fold-level": () => this.updateFoldLevel(-1),
    }
    atom.commands.add(this.ui.editorElement, commands)
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
    this.finishUpdateItems(items)
  }
}
