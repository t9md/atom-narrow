path = require 'path'
_ = require 'underscore-plus'
{isCompatibleRegExp} = require './utils'

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
  useSearchTermRule: true

  constructor: (@editor, {@includeHeaderRules}={}) ->

  activate: (rule = @getRule()) ->
    atom.grammars.removeGrammarForScopeName(@scopeName)
    grammar = atom.grammars.createGrammar(@filePath, rule)
    atom.grammars.addGrammar(grammar)
    @editor.setGrammar(grammar)

  update: (regexps) ->
    rule = @getRule()
    for regexp in regexps ? []
      rule.patterns.push(
        match: @convertRegex(regexp)
        name: 'keyword.narrow'
      )
    @activate(rule)

  # Convert RegExp form from JavaScript to Oniguruma.
  convertRegex: (regex) ->
    if regex.ignoreCase
      "(?i:#{regex.source})"
    else
      "(#{regex.source})"

  canHighlightSearchRegex: ->
    @compatible

  setSearchRegex: (regex) ->
    if regex and @compatible = isCompatibleRegExp(regex)
      @searchRegex = @convertRegex(regex)
    else
      @searchRegex = ''

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

    if @searchRegex
      rule.patterns.push(
        match: @searchRegex
        name: 'entity.name.function.narrow'
      )
    rule
