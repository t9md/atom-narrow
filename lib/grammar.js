const path = require("path")
const _ = require("underscore-plus")

const ruleHeaderLevel1 = {
  begin: "^#",
  end: "$",
  name: "markup.heading.heading-1.narrow",
}

const ruleHeaderLevel2 = {
  begin: "^##",
  end: "$",
  name: "markup.heading.heading-2.narrow",
}

const ruleLineHeader = {
  match: "^\\s*(\\d+(?:: *\\d+)?:)",
  name: "location.narrow",
  captures: {
    "1": {
      name: "constant.numeric.line-header.narrow",
    },
  },
}

const fakeGrammarFilePath = path.join(__dirname, "grammar", "narrow.cson")
const grammarScopeName = "source.narrow"
module.exports = class Grammar {
  constructor(editor, {includeHeaderRules} = {}) {
    this.editor = editor
    this.includeHeaderRules = includeHeaderRules
  }

  activate(rule = this.getRule()) {
    atom.grammars.removeGrammarForScopeName(grammarScopeName)
    const grammar = atom.grammars.createGrammar(fakeGrammarFilePath, rule)
    atom.grammars.addGrammar(grammar)
    this.editor.setGrammar(grammar)
  }

  update(regexps = []) {
    const rule = this.getRule()
    for (const regexp of regexps) {
      rule.patterns.push({
        match: this.convertRegex(regexp),
        name: "keyword.narrow",
      })
    }
    this.activate(rule)
  }

  // Convert RegExp form from JavaScript to Oniguruma.
  convertRegex(regex) {
    if (regex.ignoreCase) {
      return `(?i:${regex.source})`
    } else {
      return `(${regex.source})`
    }
  }

  setSearchRegex(regex) {
    this.searchRegex = regex ? this.convertRegex(regex) : null
  }

  getRule() {
    const rule = {
      name: "Narrow buffer",
      scopeName: grammarScopeName,
      fileTypes: [],
      patterns: [],
    }

    if (this.includeHeaderRules) {
      rule.patterns.push(ruleHeaderLevel2)
      rule.patterns.push(ruleHeaderLevel1)
    }

    rule.patterns.push(ruleLineHeader)

    if (this.searchRegex) {
      rule.patterns.push({
        name: "entity.name.function.narrow",
        match: this.searchRegex,
      })
    }
    return rule
  }
}
