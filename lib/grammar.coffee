{Emitter} = require 'atom'

path = require 'path'
_ = require 'underscore-plus'

ruleHeaderLevel1 =
  begin: '^#'
  end: '$'
  name: 'markup.heading.heading-1.narrow'

ruleHeaderLevel2 =
  begin: '^##',
  end: '$',
  name: 'markup.heading.heading-2.narrow'

ruleLineHeader =
  match: '^\\s*(\\d+(?:: *\\d+)?:)'
  name: 'location.narrow'
  captures:
    '1':
      name: 'constant.numeric.line-header.narrow'

module.exports =
class Grammar
  filePath: path.join(__dirname, 'grammar', 'narrow.cson')
  scopeName: 'source.narrow'

  constructor: (@editor, {@includeHeaderRules}={}) ->
    @emitter = new Emitter

  activate: (rule = @getRule()) ->
    atom.grammars.removeGrammarForScopeName(@scopeName)
    grammar = atom.grammars.createGrammar(@filePath, rule)
    atom.grammars.addGrammar(grammar)
    @editor.setGrammar(grammar)

  update: (regexps) ->
    rule = @getRule()
    for regexp in regexps ? []
      source = regexp.source
      if regexp.ignoreCase
        match = "(?i:#{source})"
      else
        match = "(#{source})"

      rule.patterns.push(
        match: match
        name: 'keyword.narrow'
      )
    @activate(rule)

  setSearchTerm: (regexp) ->
    source = regexp?.source ? ''
    if regexp?.ignoreCase
      @searchTerm = "(?i:#{regexp.source})"
    else
      @searchTerm = source

  getRule: ->
    rule =
      name: 'Narrow buffer'
      scopeName: @scopeName
      fileTypes: []
      patterns: []

    if @includeHeaderRules
      rule.patterns.push(ruleHeaderLevel2)
      rule.patterns.push(ruleHeaderLevel1)

    rule.patterns.push(ruleLineHeader)

    if @searchTerm
      rule.patterns.push(
        match: @searchTerm
        name: 'entity.name.function.narrow'
      )
    rule
