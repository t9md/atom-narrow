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

getRegExpForWord = (word, {wildcard, sensitivity}={}) ->
  if word.length > 1 # don't expand wildcard for sole `*`.
    pattern = expandWildCard(word)
  else
    pattern = _.escapeRegExp(word)

  if (sensitivity is 'sensitive') or (sensitivity is 'smartcase' and /[A-Z]/.test(word))
    new RegExp(pattern)
  else
    new RegExp(pattern, 'i')

module.exports = (query, options={}) ->
  include = []
  exclude = []
  {negateByEndingExclamation} = options
  delete options.negateByEndingExclamation
  words = _.compact(query.split(/\s+/))
  for word in words
    if word isnt '!' and word.startsWith('!')
      exclude.push(getRegExpForWord(word[1...], options))
    else if word isnt '!' and negateByEndingExclamation and word.endsWith('!')
      exclude.push(getRegExpForWord(word[...-1], options))
    else
      include.push(getRegExpForWord(word, options))

  {include, exclude}
