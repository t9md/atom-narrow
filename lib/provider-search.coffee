{Point, BufferedProcess} = require 'atom'
path = require 'path'

Base = require './base'
{decorateRange} = require './utils'
_ = require 'underscore-plus'

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
        filePath: m[1]
        point: point
        text: m[4]
      }
    else
      null

  outputterForProject: (project, items) ->
    header = "# " + path.basename(project)
    ({data}) =>
      if header?
        # FIXME persit is special, which is not hiden when narrowed.
        # but this kind of magic property is bad practice.
        items.push({header})
        header = null

      lines = data.split("\n")

      currentFilePath = null
      for line in lines when item = @parseLine(line)
        if currentFile isnt item.filePath
          currentFile = item.filePath
          items.push({header: "## #{currentFile}"})
        # update filePath to fullPath
        item.filePath = path.join(project, item.filePath)
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
        @narrow.pane.activate()
    else
      openOptions = {pending: true}
      atom.workspace.open(filePath, openOptions).then (editor) ->
        editor.setCursorBufferPosition(point)

  viewForItem: (item) ->
    unless item.text?
      item.header
    else
      {text, point} = item
      [row, column] = point
      row += 1
      "  #{row}:#{column}:#{text}"
