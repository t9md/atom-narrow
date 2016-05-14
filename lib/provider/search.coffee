{Point, BufferedProcess} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'

Base = require './base'
{decorateRange} = require '../utils'

module.exports =
class Search extends Base
  items: null
  searchersRunning: []

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
    header = '# ' + projectName
    ({data}) =>
      if header?
        items.push({header, projectName, projectHeader: true})
        header = null

      lines = data.split("\n")

      currentFilePath = null
      for line in lines when item = @parseLine(line)
        {relativePath} = item
        fullPath = path.join(project, relativePath)

        if currentFile isnt relativePath
          currentFile = relativePath
          header = "  # " + currentFile
          headerItem = {header, projectName, filePath: fullPath}
          items.push(headerItem)

        item.filePath = fullPath
        item.projectName = projectName
        items.push(item)

  getItems: ->
    return @items if @items?
    @items = []
    projects = atom.project.getPaths()

    finished = 0
    new Promise (resolve) =>
      onFinish = (code) =>
        finished++
        if finished is projects.length
          resolve(@items)
          console.log "#{finished} finished"
        else
          console.log "#{finished} yet finished"

      pattern = _.escapeRegExp(@options.word)
      for project, i in projects
        onData = @outputterForProject(project, @items)
        @searchersRunning.push(@search(pattern, {cwd: project, onData, onFinish}))

  runCommand: ({command, args, options, onData, onFinish}) ->
    stdout = (output) -> onData({data: output})
    stderr = (output) -> onData({data: output})
    exit = (code) -> onFinish(code)

    process = new BufferedProcess {command, args, options, stdout, stderr, exit}
    process.onWillThrowError ({error, handle}) ->
      if error.code is 'ENOENT' and error.syscall.indexOf('spawn') is 0
        console.log "ERROR"
      handle()
    process

  confirmed: (item, options={}) ->
    @marker?.destroy()
    return unless item.point?

    {project, filePath, point} = item
    point = Point.fromObject(point)

    @pane.activate()

    if options.preview?
      openOptions = {activatePane: false, pending: true}
      atom.workspace.open(filePath, openOptions).then (editor) =>
        editor.scrollToBufferPosition(point, center: true)
        @marker = @highlightRow(editor, point.row)
        @ui.pane.activate()
    else
      openOptions = {pending: true}
      atom.workspace.open(filePath, openOptions).then (editor) ->
        editor.setCursorBufferPosition(point)

  filterItems: (items, words) ->
    filterKey = @getFilterKey()
    filter = (items, pattern) ->
      _.filter items, (item) ->
        if filterKey of item
          item[filterKey].match(///#{pattern}///i)
        else
          # When item has no filterKey, it is special, always displayed.
          true

    for pattern in words.map(_.escapeRegExp)
      items = filter(items, pattern)

    nonHeaderItems = _.filter items, (item) -> not item.header?
    filePaths = _.uniq(_.pluck(nonHeaderItems, "filePath"))
    projectNames = _.uniq(_.pluck(nonHeaderItems, "projectName"))

    items = _.filter items, (item) ->
      if item.header?
        if item.projectHeader
          item.projectName in projectNames
        else
          item.filePath in filePaths
      else
        true

    items

  viewForItem: (item) ->
    unless item.text?
      item.header
    else
      {text, point} = item
      [row, column] = point
      row += 1
      "    #{row}:#{column}:#{text}"
