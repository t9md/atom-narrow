{BufferedProcess} = require 'atom'
path = require 'path'

Base = require './base'
{decorateRange, smartScrollToBufferPosition} = require './utils'
_ = require 'underscore-plus'

module.exports =
class Search extends Base
  searchersRunning: []
  getFilterKey: ->
    "text"

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
    header = "#" + path.basename(project)
    ({data}) =>
      if header?
        items.push({text: header})
        header = null

      lines = data.split("\n")

      currentFilePath = null
      for line in lines when item = @parseLine(line)
        if currentFile isnt item.filePath
          items.push(text: "##" + (currentFile = item.filePath))

        item.project = project
        items.push(item)

  getItems: ->
    items = []
    projects = atom.project.getPaths()

    finished = 0
    new Promise (resolve) =>
      onFinish = (code) ->
        finished++
        if finished is projects.length
          resolve(items)
          console.log "#{finished} finished"
        else
          console.log "#{finished} yet finished"

      pattern = _.escapeRegExp(@options.word)
      for project, i in projects
        onData = @outputterForProject(project, items)
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
    return unless item.point?

    {project, filePath, point} = item
    fullPath = path.join(project, filePath)

    @pane.activate()

    flash = (editor, point) ->
      range = editor.bufferRangeForBufferRow(point[0])
      decorateRange(editor, range, {class: 'narrow-flash', timeout: 200})

    if options.reveal?
      openOptions =
        activatePane: false
        pending: true
      atom.workspace.open(fullPath, openOptions).then (editor) =>
        smartScrollToBufferPosition(editor, point)
        flash(editor, point)
        @narrow.pane.activate()
    else
      openOptions =
        pending: true
      atom.workspace.open(fullPath, openOptions).then (editor) ->
        editor.setCursorBufferPosition(point)
        flash(editor, point)

  viewForItem: (item) ->
    unless item.point?
      item.text
    else
      {text, point} = item
      [row, column] = point
      row += 1
      "  #{row}:#{column}:#{text}"
