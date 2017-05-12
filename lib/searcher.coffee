path = require 'path'
_ = require 'underscore-plus'
{Point, Range, BufferedProcess, Emitter} = require 'atom'

LineEndingRegExp = /\n|\r\n/
RegExpForOutPutLine = /^(.*?):(\d+):(\d+):(.*)$/

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
  # Important rule I set is treat `@searchRegex` as truth.
  # - DO: Build search term for rg, ag from @searchRegex.
  # - DONT: build rg version of escapeRegExp and derive search term from @searchTerm.
  if string
    string.replace(/\\\//g, '/')
  else
    ''

class Item
  constructor: (match, project, rangeHint) ->
    @filePath = path.join(project, match[1])
    row = Math.max(0, parseInt(match[2]) - 1)
    column = Math.max(0, parseInt(match[3]) - 1)
    @text = match[4]
    @point = new Point(row, column)

    {@searchUseRegex, @searchTerm, @searchRegex} = rangeHint

  # this.range is populated on-need via @setRange which is externally set by provider.
  Object.defineProperty @prototype, 'range',
    get: ->
      @_range ?= @getRange()

  getRange: ->
    if @searchUseRegex
      # FIXME: Maybe because of BUG of ag?
      # when I search \) in regexp, it find next line of line which ends with `)`.
      matchedText = @text[@point.column...].match(@searchRegex)?[0] ? ''
    else
      matchedText = @searchTerm
    Range.fromPointWithDelta(@point, 0, matchedText.length)

runCommand = (options) ->
  bufferedProcess = new BufferedProcess(options)
  bufferedProcess.onWillThrowError ({error, handle}) ->
    if error.code is 'ENOENT' and error.syscall.indexOf('spawn') is 0
      console.log "ERROR"
    handle()
  bufferedProcess

module.exports =
class Searcher
  constructor: (options) ->
    @emitter = new Emitter
    @runningProcesses = []

  setOptions: (options) ->
    {@command, @searchUseRegex, @searchRegex, @searchTerm} = options

  search: (command, args, project, onItems, onFinish) ->
    options =
      stdio: ['ignore', 'pipe', 'pipe']
      env: process.env
      cwd: project

    stdout = (data) => onItems(@itemizeProject(project, data), project)
    stderrHeader = "[narrow:search stderr of #{command}]:"
    stderr = (data) -> console.warn(stderrHeader, data)

    bufferedProcess = null
    exit = =>
      bufferedProcess
      _.remove(@runningProcesses, bufferedProcess)
      onFinish()

    bufferedProcess = runCommand({command, args, stdout, stderr, exit, options})
    @runningProcesses.push(bufferedProcess)

  cancel: ->
    while bufferedProcess = @runningProcesses.shift()
      console.log "CANCEL", bufferedProcess.args
      bufferedProcess?.kill()

  getArgs: ->
    args = ['--vimgrep']
    if @searchRegex.ignoreCase
      args.push('--ignore-case')
    else
      args.push('--case-sensitive')

    switch @command
      when 'ag'
        args.push(@searchRegex.source)
      when 'rg'
        # See #176
        # rg doesn't show filePath on each line when search file was passed explicitly.
        # Following option make result-output consistent with `ag`.
        args.push(['-H', '--no-heading', '--regexp']...)
        args.push(unescapeRegExpForRg(@searchRegex.source))
    args

  searchFilePath: (filePath) ->
    [project, filePath] = atom.project.relativizePath(filePath)

    args = @getArgs()
    args.push(filePath)

    itemizeProject = @itemizeProject.bind(this, project)
    @search(@command, args, project).then(itemizeProject)

  searchProject: (project, onItems, onFinish) ->
    @search(@command, @getArgs(), project, onItems, onFinish)

  itemizeProject: (project, data) ->
    items = []
    rangeHint = {@searchUseRegex, @searchTerm, @searchRegex}
    for line in data.split(LineEndingRegExp) when match = line.match(RegExpForOutPutLine)
      items.push(new Item(match, project, rangeHint))
    items
