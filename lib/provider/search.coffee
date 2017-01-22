{Point, BufferedProcess} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'

ProviderBase = require './provider-base'
settings = require '../settings'

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
      point: new Point(parseInt(m[2]) - 1, parseInt(m[3]) - 1)
      text: m[4]
    }
  else
    null

getOutputterForProject = (project, items) ->
  projectName = path.basename(project)
  projectHeaderAdded = false
  currentFilePath = null
  (data) ->
    unless projectHeaderAdded
      header = "# #{projectName}"
      items.push({header, projectName, projectHeader: true, skip: true})
      projectHeaderAdded = true

    for line in data.split("\n") when parsed = parseLine(line)
      {relativePath, point, text} = parsed
      filePath = path.join(project, relativePath)

      if currentFilePath isnt filePath
        currentFilePath = filePath
        header = "  # #{relativePath}"
        items.push({header, projectName, filePath, skip: true})

      items.push({point, text, filePath, projectName})

module.exports =
class Search extends ProviderBase
  items: null
  includeHeaderGrammarRules: true
  supportDirectEdit: true

  getItems: ->
    if @items?
      @items
    else
      search = @search.bind(null, _.escapeRegExp(@options.word))
      Promise.all(@options.projects.map(search)).then (values) =>
        @items = _.flatten(values)

  search: (pattern, project) ->
    items = []
    stdout = stderr = getOutputterForProject(project, items)
    args = settings.get('SearchAgCommandArgs').split(/\s+/)
    args.push(pattern)
    new Promise (resolve) ->
      runCommand(
        command: 'ag'
        args: args
        stdout: stdout
        stderr: stderr
        exit: -> resolve(items)
        options:
          cwd: project
          env: process.env
      )

  confirmed: ({filePath, point}) ->
    return unless point?
    @pane.activate()
    atom.workspace.open(filePath, pending: true).then (editor) ->
      editor.setCursorBufferPosition(point, autoscroll: false)
      editor.scrollToBufferPosition(point, center: true)
      return {editor, point}

  filterItems: (items, regexps) ->
    filterKey = @getFilterKey()
    for regexp in regexps
      items = items.filter (item) ->
        item.skip or regexp.test(item[filterKey])

    normalItems = _.filter(items, (item) -> not item.header?)
    filePaths = _.uniq(_.pluck(normalItems, "filePath"))
    projectNames = _.uniq(_.pluck(normalItems, "projectName"))

    _.filter items, (item) ->
      if item.header?
        if item.projectHeader?
          item.projectName in projectNames
        else
          item.filePath in filePaths
      else
        true

  getRowHeaderForItem: (item) ->
    "    #{item.point.row + 1}:#{item.point.column + 1}:"

  viewForItem: (item) ->
    if item.header?
      item.header
    else
      @getRowHeaderForItem(item) + item.text

  updateRealFile: (states) ->
    changes = @getChangeSet(states)
    return unless changes.length
    @pane.activate()
    for filePath, changes of _.groupBy(changes, 'filePath')
      @updateFile(filePath, changes)

  updateFile: (filePath, changes) ->
    atom.workspace.open(filePath).then (editor) ->
      editor.transact ->
        for {row, text} in changes
          range = editor.bufferRangeForBufferRow(row)
          editor.setTextInBufferRange(range, text)

  getChangeSet: (states) ->
    changes = []
    for {newText, item} in states
      {text, filePath, point} = item
      newText = newText[@getRowHeaderForItem(item).length...]
      if newText isnt text
        changes.push({row: point.row, text: newText, filePath})
    changes
