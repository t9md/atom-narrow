_ = require 'underscore-plus'
settings = require './settings'

getRegExpForWord = (word) ->
  pattern = _.escapeRegExp(word)
  sensitivity = settings.get('caseSensitivityForNarrowQuery')
  if (sensitivity is 'sensitive') or (sensitivity is 'smartcase' and /[A-Z]/.test(word))
    new RegExp(pattern)
  else
    new RegExp(pattern, 'i')

module.exports = translateQueryToRegexps = (query) ->
  _.compact(query.split(/\s+/)).map(getRegExpForWord)
