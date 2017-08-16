const {Emitter} = require("atom")
const _ = require("underscore-plus")

class SearchOptions {
  constructor(provider, props = {}) {
    this.provider = provider
    this.emitter = new Emitter()

    Object.assign(this, props)

    _.defaults(this, {
      searchTerm: false,
      searchUseRegex: false,
      searchRegex: false,
      searchWholeWord: false,
      searchWholeWordChangedManually: false,
      searchIgnoreCase: false,
      searchIgnoreCaseChangedManually: false,
    })
  }

  set(params) {
    for (let param in params) {
      this[param] = params[param]
    }
  }

  toggle(param) {
    this[param] = !this[param]
    switch (param) {
      case "searchWholeWord":
        this.searchWholeWordChangedManually = true
        return
      case "searchIgnoreCase":
        this.searchIgnoreCaseChangedManually = true
        return
      case "searchUseRegex":
        this.searchUseRegexChangedManually = true
        return
    }
  }

  getIgnoreCaseValueForSearchTerm(term) {
    const sensitivity = this.provider.getConfig("caseSensitivityForSearchTerm")
    return sensitivity === "insensitive" || (sensitivity === "smartcase" && !/[A-Z]/.test(term))
  }

  buildRegExp() {
    let source
    if (!this.searchTerm) return null

    if (this.searchUseRegex) {
      source = this.searchTerm
      try {
        new RegExp(source)
      } catch (error) {
        return null
      }
    } else {
      source = _.escapeRegExp(this.searchTerm)
    }

    if (this.searchWholeWord) {
      const startBoundary = /^\w/.test(this.searchTerm)
      const endBoundary = /\w$/.test(this.searchTerm)
      if (!startBoundary && !endBoundary) {
        // Go strict
        source = `\\b${source}\\b`
      } else {
        // Relaxed if I can set end or start boundary
        const startBoundaryString = startBoundary ? "\\b" : ""
        const endBoundaryString = endBoundary ? "\\b" : ""
        source = startBoundaryString + source + endBoundaryString
      }
    }

    let flags = "g"
    if (this.searchIgnoreCase) flags += "i"
    return new RegExp(source, flags)
  }

  getState() {
    return {
      searchWholeWord: this.searchWholeWord,
      searchWholeWordChangedManually: this.searchWholeWordChangedManually,
      searchIgnoreCase: this.searchIgnoreCase,
      searchIgnoreCaseChangedManually: this.searchIgnoreCaseChangedManually,
      searchUseRegex: this.searchUseRegex,
      searchUseRegexChangedManually: this.searchUseRegexChangedManually,
      searchTerm: this.searchTerm,
    }
  }

  setSearchTerm(searchTerm) {
    this.searchTerm = searchTerm
    if (searchTerm) {
      // Auto disable @searchWholeWord unless it's manually changed..
      if (this.searchWholeWord && !this.searchWholeWordChangedManually) this.searchWholeWord = /\w/.test(searchTerm)

      if (!this.searchIgnoreCaseChangedManually) {
        this.searchIgnoreCase = this.getIgnoreCaseValueForSearchTerm(this.searchTerm)
      }
    }

    this.searchRegex = this.buildRegExp()
  }
}

module.exports = SearchOptions
