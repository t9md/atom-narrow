{Point, BufferedProcess} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'

ProviderBase = require './provider-base'

module.exports =
class Search extends ProviderBase
  items: null
  search: (text, {cwd, onData, onFinish}) ->
    command = 'ag'
    args = ['--nocolor', '--column', text]
    options = {cwd: cwd, env: process.env}
    @runCommand {command, args, options, onData, onFinish}

  parseLine: (line) ->
    m = line.match(/^(.*?):(\d+):(\d+):(.*)$/)
    if m?
      point = [parseInt(m[2]) - 1, parseInt(m[3])]
      {
        relativePath: m[1]
        point: point
        text: m[4]
      }
    else
      null

  outputterForProject: (project, items) ->
    projectName = path.basename(project)
    projectHeaderAdded = false
    currentFile = null
    ({data}) =>
      unless projectHeaderAdded
        items.push({header: '# ' + projectName, projectName, projectHeader: true, skip: true})
        projectHeaderAdded = true

      lines = data.split("\n")

      for line in lines when item = @parseLine(line)
        {relativePath} = item
        fullPath = path.join(project, relativePath)

        if currentFile isnt relativePath
          currentFile = relativePath
          headerItem = {header: "  # " + currentFile, projectName, filePath: fullPath, skip: true}
          items.push(headerItem)

        item.filePath = fullPath
        item.projectName = projectName
        items.push(item)

  getItems: ->
    return @items if @items?
    projects = @options.projects
    @items = []

    finished = 0
    new Promise (resolve) =>
      onFinish = (code) =>
        finished++
        resolve(@items) if finished is projects.length

      pattern = _.escapeRegExp(@options.word)
      for project in projects
        onData = @outputterForProject(project, @items)
        @search(pattern, {cwd: project, onData, onFinish})

  runCommand: ({command, args, options, onData, onFinish}) ->
    stdout = stderr = (output) -> onData(data: output)
    exit = (code) -> onFinish(code)

    process = new BufferedProcess {command, args, options, stdout, stderr, exit}
    process.onWillThrowError ({error, handle}) ->
      if error.code is 'ENOENT' and error.syscall.indexOf('spawn') is 0
        console.log "ERROR"
      handle()
    process

  confirmed: (item, {preview}={}) ->
    return unless item.point?

    {filePath, point} = item
    point = Point.fromObject(point)

    @pane.activate()
    openOptions = {activatePane: not preview, pending: true}
    atom.workspace.open(filePath, openOptions).then (editor) ->
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      editor

  filterItems: (items, words) ->
    filterKey = @getFilterKey()
    filter = (items, pattern) ->
      _.filter items, (item) ->
        item.skip or item[filterKey].match(///#{pattern}///i)

    for pattern in words.map(_.escapeRegExp)
      items = filter(items, pattern)

    normalItems = _.filter(items, (item) -> not item.header?)
    allFilePaths = _.uniq(_.pluck(normalItems, "filePath"))
    allProjectNames = _.uniq(_.pluck(normalItems, "projectName"))

    items = _.filter items, (item) ->
      if item.header?
        if item.projectHeader
          item.projectName in allProjectNames
        else
          item.filePath in allFilePaths
      else
        true
    items

  viewForItem: (item) ->
    if item.header?
      item.header
    else
      {text, point} = item
      [row, column] = point
      row += 1
      "    #{row}:#{column}:#{text}"
