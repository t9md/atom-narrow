path = require 'path'
_ = require 'underscore-plus'
{Point, Range, BufferedProcess} = require 'atom'
SearchBase = require './search-base'

LineEndingRegExp = /\n|\r\n/

runCommand = (options) ->
  new BufferedProcess(options).onWillThrowError ({error, handle}) ->
    if error.code is 'ENOENT' and error.syscall.indexOf('spawn') is 0
      console.log "ERROR"
    handle()

parseLine = (line) ->
  m = line.match(/^(.*?):(\d+):(\d+):(.*)$/)
  if m?
    {
      relativePath: m[1]
      row: parseInt(m[2]) - 1
      column: parseInt(m[3]) - 1
      text: m[4]
    }
  else
    null

getOutputterForProject = (project, items) ->
  (data) ->
    for line in data.split(LineEndingRegExp) when parsed = parseLine(line)
      items.push({
        point: new Point(parsed.row, parsed.column)
        filePath: path.join(project, parsed.relativePath)
        text: parsed.text
      })

# Not used but keep it since I'm planning to introduce per file refresh on modification
getOutputterForFile = (items) ->
  (data) ->
    for line in data.split(LineEndingRegExp) when parsed = parseLine(line)
      items.push({
        point: new Point(parsed.row, parsed.column)
        filePath: parsed.relativePath
        text: parsed.text
      })

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
    runCommand(
      command: command
      args: args
      stdout: stdout
      stderr: stderr
      exit: -> resolve(items)
      options: options
    )

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
    args = ['--vimgrep', '--fixed-strings']
    if @searchIgnoreCase
      args.push('--ignore-case')
    else
      args.push('--case-sensitive')
    args.push('--word-regexp') if @searchWholeWord

    # See #176
    # rg doesn't show filePath on each line when search file was passed explicitly.
    # Following option make result-output consistent with `ag`.
    if command is 'rg'
      args.push(['-H', '--no-heading']...)

    args.push(@searchTerm)
    args

  searchFilePath: (filePath) ->
    command = @getConfig('searcher')
    args = @getSearchArgs(command)
    search({command, args, filePath})

  searchProjects: (projects) ->
    command = @getConfig('searcher')
    args = @getSearchArgs(command)
    searchProject = (project) -> search({command, args, project})
    Promise.all(projects.map(searchProject))

  flattenAndInjectRange: (items) ->
    items = _.flatten(items)
    items = _.sortBy items, (item) -> item.filePath
    searchTermLength = @searchTerm.length
    for item in items
      item.range = Range.fromPointWithDelta(item.point, 0, searchTermLength)
    items

  getItems: (filePath) ->
    if filePath?
      return @items unless atom.project.contains(filePath)

      @searchFilePath(filePath).then (items) =>
        items = @flattenAndInjectRange(items)
        @items = @replaceOrAppendItemsForFilePath(@items, filePath, items)
    else
      @searchProjects(@projects).then (items) =>
        @items = @flattenAndInjectRange(items)
