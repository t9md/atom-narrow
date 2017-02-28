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
  if wildcard ? true
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

  words = _.compact(query.split(/\s+/))
  {negateByEndingExclamation} = options
  delete options.negateByEndingExclamation
  for word in words
    if word.length is 1
      options.wildcard = false
      include.push(getRegExpForWord(word, options))
    else if word.startsWith('!')
      exclude.push(getRegExpForWord(word[1...], options))
    else if negateByEndingExclamation and word.endsWith('!')
      exclude.push(getRegExpForWord(word[...-1], options))
    else
      include.push(getRegExpForWord(word, options))

  {include, exclude}
