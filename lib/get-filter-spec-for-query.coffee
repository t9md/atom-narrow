_ = require 'underscore-plus'
settings = require './settings'

wildCardTable = {
  '*': '.*'
  '\\*': '\\*'
}

expandWildCard = (word) ->
  # Replace double '**' to escaped *
  word = word.replace(/\*\*/g, '\\*')
  segments = []
  for segment in word.split(/(\\?\*)/) when segment isnt ''
    segments.push(wildCardTable[segment] ? _.escapeRegExp(segment))
  segments.join('')

getRegExpForWord = (word, {wildcard}={}) ->
  if wildcard ? true
    pattern = expandWildCard(word)
  else
    pattern = _.escapeRegExp(word)

  sensitivity = settings.get('caseSensitivityForNarrowQuery')
  if (sensitivity is 'sensitive') or (sensitivity is 'smartcase' and /[A-Z]/.test(word))
    new RegExp(pattern)
  else
    new RegExp(pattern, 'i')

module.exports = (query) ->
  include = []
  exclude = []

  words = _.compact(query.split(/\s+/))
  for word in words
    if word.length is 1
      include.push(getRegExpForWord(word, wildcard: false))
    else if word.startsWith('!')
      exclude.push(getRegExpForWord(word[1...]))
    else
      include.push(getRegExpForWord(word))

  {include, exclude}
