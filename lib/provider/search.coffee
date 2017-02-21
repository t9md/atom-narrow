path = require 'path'
_ = require 'underscore-plus'
{Point, Range, BufferedProcess} = require 'atom'
SearchBase = require './search-base'

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
    for line in data.split("\n") when parsed = parseLine(line)
      items.push({
        point: new Point(parsed.row, parsed.column)
        filePath: path.join(project, parsed.relativePath)
        text: parsed.text
      })

# Not used but keep it since I'm planning to introduce per file refresh on modification
getOutputterForFile = (items) ->
  (data) ->
    for line in data.split("\n") when parsed = parseLine(line)
      items.push({
        point: new Point(parsed.row, parsed.column)
        filePath: parsed.relativePath
        text: parsed.text
      })

search = (regexp, {project, args, filePath}) ->
  items = []

  if regexp.ignoreCase
    args.push('--ignore-case')
  else
    args.push('--case-sensitive')

  options =
    stdio: ['ignore', 'pipe', 'pipe']
    env: process.env

  args.push(regexp.source)

  if filePath?
    stdout = stderr = getOutputterForFile(items)
    args.push(filePath)
  else
    stdout = stderr = getOutputterForProject(project, items)
    options.cwd = project

  new Promise (resolve) ->
    runCommand(
      command: 'ag'
      args: args
      stdout: stdout
      stderr: stderr
      exit: -> resolve(items)
      options: options
    )

module.exports =
class Search extends SearchBase
  checkReady: ->
    if @options.currentProject
      filePath = @editor.getPath()
      if filePath?
        for dir in atom.project.getDirectories() when dir.contains(filePath)
          @options.projects = [dir.getPath()]
          break

      unless @options.projects?
        message = "This file is not belonging to any project"
        atom.notifications.addInfo(message, dismissable: true)
        return Promise.resolve(false)

    super

  getArgs: ->
    @getConfig('agCommandArgs').split(/\s+/)

  searchFilePath: (filePath) ->
    search(@searchRegExp, {args: @getArgs(), filePath}).then (items) =>
      @injectRangeForItems(_.flatten(items))

  searchProjects: (projects) ->
    searchProject = (project) => search(@searchRegExp, {project, args: @getArgs()})
    Promise.all(projects.map(searchProject)).then (items) =>
      @injectRangeForItems(_.flatten(items))

  injectRangeForItems: (items) ->
    searchTermLength = @searchTerm.length
    for item in items
      item.range = Range.fromPointWithDelta(item.point, 0, searchTermLength)
    items

  getItems: (filePath) ->
    if filePath?
      return @items unless atom.project.contains(filePath)

      @searchFilePath(filePath).then (newItems) =>
        @items = @replaceOrAppendItemsForFilePath(@items, filePath, newItems)
    else
      @searchProjects(@options.projects ? atom.project.getPaths()).then (items) =>
        @items = items
