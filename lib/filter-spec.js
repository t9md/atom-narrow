const _ = require('underscore-plus')

const wildCardTable = {
  '*': '.*',
  '\\*': '\\*'
}

function expandWildCard (word) {
  // Replace double '**' to escaped *
  word = word.replace(/\*\*/g, '\\*')
  const segments = []
  for (let segment of word.split(/(\\?\*)/)) {
    if (segment !== '') {
      segments.push(wildCardTable[segment] || _.escapeRegExp(segment))
    }
  }
  return segments.join('')
}

function getRegExpForWord (word, sensitivity) {
  const isIncludeUpperCase = /[A-Z]/.test(word)
  const words = !word.startsWith('|') && !word.endsWith('|') ? word.split('|') : [word]

  const patterns = []
  for (word of words) {
    let pattern =
      word.length > 1 // don't expand wildcard for sole `*`.
        ? expandWildCard(word)
        : _.escapeRegExp(word)

    // Translate
    // - ">word<" to "\bword\b"
    // - ">word" to "\bword"
    // - "word<" to "word\b"
    if (/^>./.test(pattern)) {
      pattern = pattern.slice(1)
      if (/^\w/.test(pattern)) pattern = '\\b' + pattern
    }
    if (/.<$/.test(pattern)) {
      pattern = pattern.slice(0, -1)
      if (/\w$/.test(pattern)) pattern = pattern + '\\b'
    }
    patterns.push(pattern)
  }

  const isInsenstive = sensitivity === 'insensitive' || (sensitivity === 'smartcase' && !isIncludeUpperCase)
  const options = isInsenstive ? 'i' : ''

  return new RegExp(patterns.join('|'), options)
}

module.exports = class FilterSpec {
  constructor (filterQuery, options = {}) {
    this.include = []
    this.exclude = []

    const {negateByEndingExclamation, sensitivity} = options
    const words = _.compact(filterQuery.split(/\s+/))
    for (let word of words) {
      // prettier-ignore
      if (word.startsWith('!') && word !== '!') {
        this.exclude.push(getRegExpForWord(word.slice(1), sensitivity))
      } else if (negateByEndingExclamation && word.endsWith('!') && word !== '!') {
        this.exclude.push(getRegExpForWord(word.slice(0, -1), sensitivity))
      } else {
        this.include.push(getRegExpForWord(word, sensitivity))
      }
    }
  }

  filterItems (items, key) {
    for (let regexp of this.exclude) {
      items = items.filter(item => item.skip || !regexp.test(item[key]))
    }

    for (let regexp of this.include) {
      items = items.filter(item => item.skip || regexp.test(item[key]))
    }

    return items
  }
}
