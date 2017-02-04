path = require 'path'
_ = require 'underscore-plus'
{Point, BufferedProcess} = require 'atom'
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
        header = "## #{relativePath}"
        items.push({header, projectName, filePath, skip: true})

      items.push({point, text, filePath, projectName})

module.exports =
class Search extends SearchBase
  supportCacheItems: true

  checkReady: ->
    if @options.currentProject
      for dir in atom.project.getDirectories() when dir.contains(@editor.getPath())
        @options.projects = [dir.getPath()]
        break

      unless @options.projects?
        message = "#{@editor.getPath()} not belonging to any project"
        atom.notifications.addInfo(message, dismissable: true)
        return Promise.resolve(false)

    super

  getItems: ->
    @options.projects ?= atom.project.getPaths()
    search = @search.bind(this, @getRegExpForSearchTerm())
    Promise.all(@options.projects.map(search)).then (values) ->
      _.flatten(values)

  search: (regexp, project) ->
    items = []
    stdout = stderr = getOutputterForProject(project, items)
    args = @getConfig('agCommandArgs').split(/\s+/)

    if regexp.ignoreCase
      args.push('--ignore-case')
    else
      args.push('--case-sensitive')

    args.push(regexp.source)
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

  filterItems: (items, filterSpec) ->
    items = super
    normalItems = _.reject(items, (item) -> item.skip)
    filePaths = _.uniq(_.pluck(normalItems, "filePath"))
    projectNames = _.uniq(_.pluck(normalItems, "projectName"))

    items.filter (item) ->
      if item.header?
        if item.projectHeader?
          item.projectName in projectNames
        else
          item.filePath in filePaths
      else
        true
