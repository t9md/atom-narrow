_ = require 'underscore-plus'

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

getRegExpForWord = (word, sensitivity) ->
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

module.exports =
class FilterSpec
  constructor: (filterQuery, options={}) ->
    @include = []
    @exclude = []

    {negateByEndingExclamation, sensitivity} = options
    words = _.compact(filterQuery.split(/\s+/))
    for word in words
      if word isnt '!' and word.startsWith('!')
        @exclude.push(getRegExpForWord(word[1...], sensitivity))
      else if word isnt '!' and negateByEndingExclamation and word.endsWith('!')
        @exclude.push(getRegExpForWord(word[...-1], sensitivity))
      else
        @include.push(getRegExpForWord(word, sensitivity))

  filterItems: (items, key) ->
    for regexp in @exclude
      items = items.filter (item) -> item.skip or not regexp.test(item[key])

    for regexp in @include
      items = items.filter (item) -> item.skip or regexp.test(item[key])

    items
