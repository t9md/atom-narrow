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

  setRangeHint: (@getRange) ->
  # this.range is populated on-need via @setRange which is externally set by provider.
  Object.defineProperty @prototype, 'range',
    get: ->
      @_range ?= @getRange(@point, @filePath)

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

  collectRanges: (filePath) ->
    editors = atom.workspace.getTextEditors()
    ranges = []

    # Approach One: Line by line match to avoid across line match by editor.scan
    if editor = _.find(editors, (editor) -> editor.getPath() is filePath)
      regExp = new RegExp(@searchRegExp.source, @searchRegExp.flags) # clone to reset lastIndex
      for lineText, i in editor.buffer.getLines()
        regExp.lastIndex = 0
        while result = regExp.exec(lineText)
          start = [i, result.index]
          end = [i, result[0].length]
          ranges.push(new Range(start, end))

    # Approach TWO: use editor.scan and exclude unwanted match
    # if editor = _.find(editors, (editor) -> editor.getPath() is filePath)
    #   spaces = "(?:^[\\t ]*\\r?\\n)|(?:\\r?\\n)"
    #   newSource = ["(#{spaces})", "(#{@searchRegExp.source})"].join('|')
    #   regExp = new RegExp(newSource, @searchRegExp.flags)
    #   editor.scan regExp, ({range, match}) ->
    #     return if match[1]
    #     ranges.push(range)

    if ranges.length
      # FIXME: why this guard is necessary is timing issue.
      # Because highlighter kick collectRange is caled very just afterr workspace.open?
      # At that time, scan result is empty, although I know it's actually matching item in editor.
      console.log "collected ", filePath, ranges.length
      console.log ranges
      ranges
    else
      console.log "collected but empty", filePath,
      null

  getRange: (point, filePath) =>
    # console.log 'getRange', point, filePath
    if @isRegExpSearch
      @rangesByFilePath ?= {}
      if ranges = (@rangesByFilePath[filePath] ?= @collectRanges(filePath))
        found = _.find(ranges, (range) -> range.start.isEqual(point))
        # unless found?
        #   console.log '=== not found', point, filePath
          # console.log ranges.map (r) -> r.toString()
        found
    else
      Range.fromPointWithDelta(point, 0, @searchTerm.length)

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
    for item in items
      item.setRangeHint(@getRange)
    return items

  getItems: (filePath) ->
    if filePath?
      return @items unless atom.project.contains(filePath)

      @searchFilePath(filePath).then (items) =>
        @items = @replaceOrAppendItemsForFilePath(@items, filePath, items)
    else
      @searchProjects(@projects).then (items) =>
        @items = items
