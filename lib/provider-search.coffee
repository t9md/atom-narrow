{BufferedProcess} = require 'atom'
_ = require 'underscore-plus'

module.exports =
class Search
  searchersRunning: []
  constructor: (@narrow, @word) ->

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
      {
        filePath: m[1]
        point: [m[2], m[3]]
        text: m[4]
      }
    else
      console.log 'nmatch!', line
      {}

  outputterForProject: (project, items) ->
    ({data}) =>
      lines = data.split("\n")
      for line in lines when line.length
        entry = @parseLine(line)
        entry.project = project
        items.push(entry)

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

      pattern = _.escapeRegExp(@word)
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

  viewForItem: (item) ->
    {text, point} = item
    [row, column] = point
    row += 1
    "#{row}:#{column}:#{text}"
