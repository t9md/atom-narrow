const settings = require('../settings')
const Provider = require('./provider')
const {limitNumber, getFirstCharacterPositionForBufferRow} = require('../utils')

function getCodeFoldStartRows (editor, indentLevel) {
  const {tokenizedBuffer} = editor
  return tokenizedBuffer
    .getFoldableRanges(1)
    .filter(range => !tokenizedBuffer.isRowCommented(range.start.row))
    .map(range => range.start.row)
    .filter(row => editor.indentationForBufferRow(row) < indentLevel)
}

module.exports = class Fold {
  constructor () {
    this.provider = Provider.create({
      name: this.constructor.name,
      config: {
        boundToSingleFile: true,
        foldLevel: settings.get('Fold.foldLevel'),
        supportCacheItems: true,
        refreshOnDidStopChanging: true
      },
      onUiCreated: ui => {
        atom.commands.add(ui.editor.element, {
          'narrow-ui:fold-increase-level': () => this.updateFoldLevel(+1),
          'narrow-ui:fold-decrease-level': () => this.updateFoldLevel(-1)
        })
      },
      getItems: () => this.getItems()
    })
  }

  updateFoldLevel (relativeLevel) {
    const oldValue = settings.get('Fold.foldLevel')
    const newValue = limitNumber(value + relativeLevel, {min: 1})
    if (newValue !== oldValue) {
      settings.set('Fold.foldLevel', newValue)
      this.provider.ui.refresh({force: true})
    }
  }

  getItems () {
    const editor = this.provider.editor
    const foldStartRows = getCodeFoldStartRows(editor, settings.get('Fold.foldLevel'))
    this.provider.finishUpdateItems(
      foldStartRows.map(row => ({
        point: getFirstCharacterPositionForBufferRow(editor, row),
        text: editor.lineTextForBufferRow(row)
      }))
    )
  }
}
