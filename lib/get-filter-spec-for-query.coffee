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
  isIncludeUpperCase = /[A-Z]/.test(word)

  if not word.startsWith('|') and not word.endsWith('|')
    words = word.split('|')
  else
    words = [word]

  patterns = []
  for word in words
    if word.length > 1 # don't expand wildcard for sole `*`.
      pattern = expandWildCard(word)
    else
      pattern = _.escapeRegExp(word)

    # Translate
    # - ">word<" to "\bword\b"
    # - ">word" to "\bword"
    # - "word<" to "word\b"
    if /^>./.test(pattern)
      pattern = pattern[1...]
      pattern = "\\b" + pattern if /^\w/.test(pattern)
    if /.<$/.test(pattern)
      pattern = pattern[...-1]
      pattern = pattern + "\\b" if /\w$/.test(pattern)
    patterns.push(pattern)

  options = ''
  if (sensitivity is 'sensitive') or (sensitivity is 'smartcase' and not isIncludeUpperCase)
    options += 'i'

  new RegExp(patterns.join('|'), options)

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
