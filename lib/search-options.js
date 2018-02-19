const {Emitter} = require('atom')
const _ = require('underscore-plus')

const defaultOptions = {
  searchUseRegex: false,
  searchUseRegexChangedManually: false,
  searchRegex: false,
  searchWholeWord: false,
  searchWholeWordChangedManually: false,
  searchIgnoreCase: false,
  searchIgnoreCaseChangedManually: false
}

module.exports = class SearchOptions {
  constructor (provider, props = {}) {
    this.searchRegex = null
    this.provider = provider
    this.emitter = new Emitter()
    Object.assign(this, {}, defaultOptions, props)
  }

  toggle (param) {
    this[param] = !this[param]
    if (param === 'searchWholeWord') this.searchWholeWordChangedManually = true
    else if (param === 'searchIgnoreCase') this.searchIgnoreCaseChangedManually = true
    else if (param === 'searchUseRegex') this.searchUseRegexChangedManually = true
  }

  shouldIgnoreCaseForSearchTerm (term) {
    const sensitivity = this.provider.getConfig('caseSensitivityForSearchTerm')
    return sensitivity === 'insensitive' || (sensitivity === 'smartcase' && !/[A-Z]/.test(term))
  }

  getState () {
    return {
      searchWholeWord: this.searchWholeWord,
      searchWholeWordChangedManually: this.searchWholeWordChangedManually,
      searchIgnoreCase: this.searchIgnoreCase,
      searchIgnoreCaseChangedManually: this.searchIgnoreCaseChangedManually,
      searchUseRegex: this.searchUseRegex,
      searchUseRegexChangedManually: this.searchUseRegexChangedManually,
      searchTerm: this.searchTerm
    }
  }

  setSearchTerm (searchTerm) {
    this.searchTerm = searchTerm
    if (searchTerm) {
      // Auto relax `searchWholeWord` unless it's manually changed..
      // Sicne when /\w/ doesn't match `\bterm\b` never matchs.
      if (this.searchWholeWord) {
        if (!this.searchWholeWordChangedManually && !/\w/.test(searchTerm)) {
          this.searchWholeWord = false
        }
      }

      if (!this.searchIgnoreCaseChangedManually) {
        this.searchIgnoreCase = this.shouldIgnoreCaseForSearchTerm(searchTerm)
      }
    }

    this.searchRegex = buildRegExp({
      searchTerm: this.searchTerm,
      searchWholeWord: this.searchWholeWord,
      searchIgnoreCase: this.searchIgnoreCase,
      searchUseRegex: this.searchUseRegex
    })
  }
}

function buildRegExp ({searchTerm, searchWholeWord, searchIgnoreCase, searchUseRegex}) {
  if (!searchTerm) return null

  let source
  if (searchUseRegex) {
    source = searchTerm
    try {
      new RegExp(source) // eslint-disable-line no-new
    } catch (error) {
      return null
    }
  } else {
    source = _.escapeRegExp(searchTerm)
  }

  if (searchWholeWord) {
    let startBoundary = /^\w/.test(searchTerm) ? '\\b' : ''
    let endBoundary = /\w$/.test(searchTerm) ? '\\b' : ''
    if (!startBoundary && !endBoundary) {
      // Go strict
      startBoundary = '\\b'
      endBoundary = '\\b'
    }
    source = startBoundary + source + endBoundary
  }

  let flags = 'g'
  if (searchIgnoreCase) flags += 'i'
  return new RegExp(source, flags)
}
