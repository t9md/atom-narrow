{Point, BufferedProcess} = require 'atom'
path = require 'path'
_ = require 'underscore-plus'

ProviderBase = require './provider-base'
settings = require '../settings'
{padStringLeft, getCurrentWordAndBoundary} = require '../utils'

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

  checkReady: ->
    if @options.currentProject
      for dir in atom.project.getDirectories() when dir.contains(@editor.getPath())
        @options.projects = [dir.getPath()]
        break

      unless @options.projects?
        message = "#{@editor.getPath()} not belonging to any project"
        atom.notifications.addInfo(message, dismissable: true)
        return Promise.resolve(false)

    if @options.currentWord
      {word, boundary} = getCurrentWordAndBoundary(@editor)
      @options.wordOnly = boundary
      @options.search = word

    if @options.search
      Promise.resolve(true)
    else
      @readInput().then (input) =>
        @options.search = input
        true

  initialize: ->
    source = _.escapeRegExp(@options.search)
    if @options.wordOnly
      source = "\\b#{source}\\b"
    searchTerm = "(?i:#{source})"
    @ui.grammar.setSearchTerm(searchTerm)

  getItems: ->
    if @items?
      @items
    else
      @options.projects ?= atom.project.getPaths()
      search = @search.bind(this, _.escapeRegExp(@options.search))
      Promise.all(@options.projects.map(search)).then (values) =>
        items = _.flatten(values)
        @injectMaxLineTextWidth(items)
        @items = items

  injectMaxLineTextWidth: (items) ->
    # Inject maxLineTextWidth field to each item just for make row header aligned.
    items = items.filter((item) -> not item.skip) # normal item only
    maxRow = Math.max((items.map (item) -> item.point.row)...)
    maxLineTextWidth = String(maxRow + 1).length
    for item in items
      item.maxLineTextWidth = maxLineTextWidth

  search: (pattern, project) ->
    items = []
    stdout = stderr = getOutputterForProject(project, items)
    args = settings.get('SearchAgCommandArgs').split(/\s+/)

    if @options.wordOnly and ('-w' not in args) and ('--word-regexp' not in args)
      args.push('--word-regexp')

    args.push(pattern)
    new Promise (resolve) ->
      runCommand(
        command: 'ag'
        args: args
        stdout: stdout
        stderr: stderr
        exit: -> resolve(items)
        options:
          stdio: ['ignore', 'pipe', 'pipe']
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
    "    " + padStringLeft(String(item.point.row + 1), item.maxLineTextWidth) + ":"

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
      if settings.get('SearchSaveAfterDirectEdit')
        editor.save()

  getChangeSet: (states) ->
    changes = []
    for {newText, item} in states
      {text, filePath, point} = item
      newText = newText[@getRowHeaderForItem(item).length...]
      if newText isnt text
        changes.push({row: point.row, text: newText, filePath})
    changes
