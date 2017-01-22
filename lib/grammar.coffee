path = require 'path'
_ = require 'underscore-plus'

module.exports =
class NarrowGrammar
  filePath: path.join(__dirname, 'grammar', 'narrow.cson')
  scopeName: 'source.narrow'

  constructor: (@editor, options={}) ->
    {@initialKeyword, @includeHeaderRules} = options

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

  getRule: ->
    rule =
      {
        name: 'Narrow buffer'
        scopeName: @scopeName
        fileTypes: []
        patterns: [
          {
            match: '^\\s*(\\d+):(?:(\\d+):)*'
            name: 'location.narrow'
            captures:
              '1':
                name: 'constant.numeric.line.narrow'
              '2':
                name: 'constant.numeric.column.narrow'
          }
        ]
      }
    if @includeHeaderRules
      rule.patterns.push(
        {
          begin: '^  #'
          end: '$'
          name: 'markup.heading.heading-2.narrow'
        }
      )
      rule.patterns.push(
        {
          begin: '^#'
          end: '$'
          name: 'markup.heading.heading-1.narrow'
        }
      )
    if @initialKeyword
      rule.patterns.push(
        match: "(?i:#{_.escapeRegExp(@initialKeyword)})"
        name: 'entity.name.function.narrow'
      )
    rule
