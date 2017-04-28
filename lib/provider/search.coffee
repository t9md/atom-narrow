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

parseLine = (line) ->
  m = line.match(/^(.*?):(\d+):(\d+):(.*)$/)
  if m?
    {
      filePath: m[1]
      row: parseInt(m[2]) - 1
      column: parseInt(m[3]) - 1
      text: m[4]
    }
  else
    null

getOutputterForProject = (project, items) ->
  (data) ->
    for line in data.split(LineEndingRegExp) when parsed = parseLine(line)
      items.push(new Item(parsed, project))

# Not used but keep it since I'm planning to introduce per file refresh on modification
getOutputterForFile = (items) ->
  (data) ->
    for line in data.split(LineEndingRegExp) when parsed = parseLine(line)
      items.push(new Item(parsed))

class Item
  # this.range is populated on-need.
  Object.defineProperty @prototype, 'range',
    get: ->
      if @isRegExpSearch
        null
      else
        @_range ?= Range.fromPointWithDelta(@point, 0, @searchTermLength)

  constructor: (parsed, project) ->
    {row, column, @filePath, @text} = parsed
    @point = new Point(row, column)
    @filePath = path.join(project, @filePath) if project

  setRangeHint: ({@isRegExpSearch, @searchTermLength}) ->

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
  propertiesToRestoreOnReopen: ['projects']

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

    # See #176
    # rg doesn't show filePath on each line when search file was passed explicitly.
    # Following option make result-output consistent with `ag`.
    if command is 'rg'
      args.push(['-H', '--no-heading']...)
      args.push('--regexp')
      args.push(unescapeRegExpForRg(@searchRegExp.source))
    else
      args.push(@searchRegExp.source)
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
    searchTermLength = @searchTerm.length
    for item in items
      item.setRangeHint({@isRegExpSearch, searchTermLength})
    return items

  getItems: (filePath) ->
    if filePath?
      return @items unless atom.project.contains(filePath)

      @searchFilePath(filePath).then (items) =>
        @items = @replaceOrAppendItemsForFilePath(@items, filePath, items)
    else
      @searchProjects(@projects).then (items) =>
        @items = items
