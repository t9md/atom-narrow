path = require 'path'
_ = require 'underscore-plus'
{Point, Range, BufferedProcess} = require 'atom'
SearchBase = require './search-base'

LineEndingRegExp = /\n|\r\n/

unescapeRegExpForRg = (string) ->
  # Why I am unescaping for `rg` specifically?
  # History:
  #  - Ripgrep's regex engine doesn't allow unnecessary escape.
  #    See: https://github.com/BurntSushi/ripgrep/issues/102#issuecomment-249620557
  #  - To search `a/b/c`, I need to search `a/b/c`, can't search with `a\/b\/c`.
  #  - Bug fix in t9md/atom-narrow#171 introduced another critical bug.
  #  - So re-fixed in different way in t9md/atom-narrow#185, 190
  #
  # This what-char-should-be-escaped diff between js, ag and rg is soruce of bug and headache.
  # Important rule I set is treat `@searchRegExp` as truth.
  # - DO: Build search term for rg, ag from @searchRegExp.
  # - DONT: build rg version of escapeRegExp and derive search term from @searchTerm.
  if string
    string.replace(/\\\//g, '/')
  else
    ''

runCommand = (options) ->
  new BufferedProcess(options).onWillThrowError ({error, handle}) ->
    if error.code is 'ENOENT' and error.syscall.indexOf('spawn') is 0
      console.log "ERROR"
    handle()

RegExpForOutPutLine = /^(.*?):(\d+):(\d+):(.*)$/
getOutputterForProject = (project, items) ->
  (data) ->
    for line in data.split(LineEndingRegExp) when match = line.match(RegExpForOutPutLine)
      items.push(new Item(match, project))

# Not used but keep it since I'm planning to introduce per file refresh on modification
getOutputterForFile = (items) ->
  (data) ->
    for line in data.split(LineEndingRegExp) when match = line.match(RegExpForOutPutLine)
      items.push(new Item(match))

class Item
  constructor: (match, project) ->
    @filePath = match[1]
    row = Math.max(0, parseInt(match[2]) - 1)
    column = Math.max(0, parseInt(match[3]) - 1)
    @text = match[4]

    @point = new Point(row, column)
    @filePath = path.join(project, @filePath) if project

  setRangeHint: (@getRangeForItem) ->
  # this.range is populated on-need via @setRange which is externally set by provider.
  Object.defineProperty @prototype, 'range',
    get: ->
      @_range ?= @getRangeForItem(this)

search = ({command, args, project, filePath}) ->
  options =
    stdio: ['ignore', 'pipe', 'pipe']
    env: process.env

  items = []
  if filePath?
    stdout = getOutputterForFile(items)
    args.push(filePath)
  else
    stdout = getOutputterForProject(project, items)
    options.cwd = project

  stderrHeader = "[narrow:search stderr of #{command}]:"
  stderr = (data) -> console.warn(stderrHeader, data)

  new Promise (resolve) ->
    exit = -> resolve(items)
    runCommand({command, args, stdout, stderr, exit, options})

getProjectDirectoryForFilePath = (filePath) ->
  return null unless filePath?
  for dir in atom.project.getDirectories() when dir.contains(filePath)
    return dir
  null

module.exports =
class Search extends SearchBase
  getState: ->
    @mergeState(super, {@projects})

  getRangeForItem: (item) =>
    if @useRegex
      # FIXME: Maybe because of BUG of ag?
      # when I search \) in regexp, it find next line of line which ends with `)`.
      matchedText = item.text[item.point.column...].match(@searchRegExp)?[0] ? ''
      Range.fromPointWithDelta(item.point, 0, matchedText.length)
    else
      matchedText = @searchTerm
      Range.fromPointWithDelta(item.point, 0, matchedText.length)

  checkReady: ->
    if @options.currentProject
      if dir = getProjectDirectoryForFilePath(@editor.getPath())
        @projects = [dir.getPath()]
      else
        message = "This file is not belonging to any project"
        atom.notifications.addInfo(message, dismissable: true)
        return Promise.resolve(false)

    @projects ?= atom.project.getPaths()
    super

  getSearchArgs: (command) ->
    args = ['--vimgrep']
    if @searchRegExp.ignoreCase
      args.push('--ignore-case')
    else
      args.push('--case-sensitive')

    switch command
      when 'ag'
        args.push('--nomultiline')
        args.push(@searchRegExp.source)
      when 'rg'
        # See #176
        # rg doesn't show filePath on each line when search file was passed explicitly.
        # Following option make result-output consistent with `ag`.
        args.push(['-H', '--no-heading', '--regexp']...)
        args.push(unescapeRegExpForRg(@searchRegExp.source))
    args

  searchFilePath: (filePath) ->
    command = @getConfig('searcher')
    args = @getSearchArgs(command)
    search({command, args, filePath}).then(@flattenSortAndSetRangeHint)

  searchProjects: (projects) ->
    command = @getConfig('searcher')
    args = @getSearchArgs(command)
    searchProject = (project) -> search({command, args, project})
    Promise.all(projects.map(searchProject)).then(@flattenSortAndSetRangeHint)

  flattenSortAndSetRangeHint: (items) =>
    items = _.flatten(items)
    items = _.sortBy items, (item) -> item.filePath
    for item in items
      item.setRangeHint(@getRangeForItem)
    return items

  getItems: (filePath) ->
    if filePath?
      return @items unless atom.project.contains(filePath)

      @searchFilePath(filePath).then (items) =>
        @items = @replaceOrAppendItemsForFilePath(@items, filePath, items)
    else
      @searchProjects(@projects).then (items) =>
        @items = items
