const settings = require('./settings')
const {getPrefixedTextLengthInfo} = require('./utils')
const _ = require('underscore-plus')

function warn (message) {
  atom.notifications.addWarning('Cancelled `update-real-file`.<br>' + message, {dismissable: true})
}

// Ensure prefixed text(lineHeader + truncationIndicator) are NOT mutated.
function ensurePrefixedTextAreNotMutated (ui) {
  const prefixedTextFor = item => (item._lineHeader || '') + (item._truncationIndicator || '')
  const uiTextFor = item => ui.editor.lineTextForBufferRow(item._row)
  const success = ui.items.getNormalItems().every(item => uiTextFor(item).startsWith(prefixedTextFor(item)))
  if (!success) warn('Line header or truncation indicator was mutated.')
  return success
}

function ensureNoTruncatedItemInChanges (changes) {
  const success = changes.every(change => !change.item._truncationIndicator)
  if (!success) warn('You cannot directly update **truncated** text.')
  return success
}

// detect conflicting change
function ensureNoConflictForChanges (changes) {
  const message = []
  const conflictChanges = detectConflictForChanges(changes)
  const success = _.isEmpty(conflictChanges)
  if (!success) {
    message.push('Detected **conflicting change to same line**.')
    for (const filePath in conflictChanges) {
      const changesInFile = conflictChanges[filePath]
      message.push(`- ${filePath}`)
      for (let {newText, item} of changesInFile) {
        message.push(`  - ${item.point.translate([1, 1]).toString()}, ${newText}`)
      }
    }
    warn(message.join('\n'))
  }
  return success
}

function detectConflictForChanges (changes) {
  const conflictChanges = {}
  const changesByFilePath = _.groupBy(changes, ({item}) => item.filePath)
  for (let filePath in changesByFilePath) {
    const changesInFile = changesByFilePath[filePath]
    const changesByRow = _.groupBy(changesInFile, ({item}) => item.point.row)
    for (let row in changesByRow) {
      const changesInRow = changesByRow[row]
      const newTexts = _.pluck(changesInRow, 'newText')
      if (_.uniq(newTexts).length > 1) {
        if (conflictChanges[filePath] == null) {
          conflictChanges[filePath] = []
        }
        conflictChanges[filePath].push(...(changesInRow || []))
      }
    }
  }
  return conflictChanges
}

module.exports = async function updateRealFile (ui) {
  if (!ui.supportDirectEdit) return
  if (!ui.editor.buffer.isModified()) return

  if (settings.get('confirmOnUpdateRealFile')) {
    const options = {message: 'Update real file?', buttons: ['Update', 'Cancel']}
    if (atom.confirm(options) !== 0) return
  }

  if (ui.narrowEditor.itemRowIsDeleted()) return

  if (!ensurePrefixedTextAreNotMutated(ui)) return

  const changes = []
  const lines = ui.editor.buffer.getLines()

  for (let row = 0; row < lines.length; row++) {
    const item = ui.items.itemForRow(row)
    if (item.skip) continue
    const line = lines[row].slice(getPrefixedTextLengthInfo(item).totalLength)
    const textToCompare = item._textDisplayed || item.text
    if (line !== textToCompare) {
      changes.push({newText: line, item})
    }
  }

  if (!changes.length) return

  if (!ensureNoTruncatedItemInChanges(changes)) return
  if (!ensureNoConflictForChanges(changes)) return
  await ui.provider.updateRealFile(changes)
  ui.narrowEditor.setModifiedState(false)
}
