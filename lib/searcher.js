const Path = require('path')
const _ = require('underscore-plus')
const {Point, Range, BufferedProcess} = require('atom')
const {limitNumber} = require('./utils')

const LineEndingRegExp = /\n|\r\n/
const RegExpForOutPutLine = /^(.*?):(\d+):(\d+):(.*)$/

function unescapeRegExpForRg (string) {
  // Why I am unescaping for `rg` specifically?
  // History:
  //  - Ripgrep's regex engine doesn't allow unnecessary escape.
  //    See: https://github.com/BurntSushi/ripgrep/issues/102#issuecomment-249620557
  //  - To search `a/b/c`, I need to search `a/b/c`, can't search with `a\/b\/c`.
  //  - Bug fix in t9md/atom-narrow#171 introduced another critical bug.
  //  - So re-fixed in different way in t9md/atom-narrow#185, 190
  //
  // This what-char-should-be-escaped diff between js, ag and rg is soruce of bug and headache.
  // Important rule I set is treat `@searchRegex` as truth.
  // - DO: Build search term for rg, ag from @searchRegex.
  // - DONT: build rg version of escapeRegExp and derive search term from @searchTerm.
  return string ? string.replace(/\\\//g, '/') : ''
}

class Item {
  constructor (match, project, rangeHint) {
    this.filePath = Path.join(project, match[1])
    const row = limitNumber(parseInt(match[2]) - 1, {min: 0})
    const column = limitNumber(parseInt(match[3]) - 1, {min: 0})
    this.text = match[4]
    this.point = new Point(row, column)
    this.rangeHint = rangeHint
  }

  // this.range is populated on-need
  get range () {
    if (!this._range) this._range = this.getRange()
    return this._range
  }

  getRange () {
    let matchedText
    if (this.rangeHint.searchUseRegex) {
      // FIXME: Maybe because of BUG of `ag`?
      // when I search \) in regexp, it find next line of line which ends with `)`.
      const textRight = this.text.slice(this.point.column)
      const match = textRight.match(this.rangeHint.searchRegex)
      matchedText = match ? match[0] : ''
    } else {
      matchedText = this.rangeHint.searchTerm
    }
    return Range.fromPointWithDelta(this.point, 0, matchedText.length)
  }
}

function runCommand (options) {
  const bufferedProcess = new BufferedProcess(options)
  bufferedProcess.onWillThrowError(({error, handle}) => {
    if (error.code === 'ENOENT' && error.syscall.indexOf('spawn') === 0) {
      console.log('ERROR')
    }
    handle()
  })
  return bufferedProcess
}

module.exports = class Searcher {
  constructor (searchOptions) {
    this.searchOptions = searchOptions
    this.runningProcesses = []
  }

  runCommandPromisified (command) {
    let exit
    const exitPromise = new Promise(resolve => {
      exit = resolve
    })
    runCommand({command: 'which', args: [command], exit})
    return exitPromise
  }

  setCommand (command) {
    this.command = command
  }

  search (command, args, project, onItems, onFinish) {
    let bufferedProcess = null

    const options = {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: process.env,
      cwd: project
    }

    const stdout = data => onItems(this.itemizeProject(project, data), project)
    const stderrHeader = `[narrow:search stderr of ${command}]:`
    const stderr = data => console.warn(stderrHeader, data)
    const exit = () => {
      _.remove(this.runningProcesses, bufferedProcess)
      onFinish(project)
    }

    bufferedProcess = runCommand({command, args, stdout, stderr, exit, options})
    this.runningProcesses.push(bufferedProcess)
  }

  cancel () {
    let bufferedProcess
    while ((bufferedProcess = this.runningProcesses.shift())) {
      bufferedProcess.kill()
    }
  }

  getArgs () {
    const args = ['--vimgrep']

    const {searchRegex} = this.searchOptions
    if (searchRegex.ignoreCase) {
      args.push('--ignore-case')
    } else {
      args.push('--case-sensitive')
    }

    if (this.command === 'ag') {
      args.push(searchRegex.source)
    } else if (this.command === 'rg') {
      // See #176
      // rg doesn't show filePath on each line when search file was passed explicitly.
      // Following option make result-output consistent with `ag`.
      args.push('-H', '--no-heading', '--regexp')
      args.push(unescapeRegExpForRg(searchRegex.source))
    }
    return args
  }

  searchProject (project, onItems, onFinish) {
    this.search(this.command, this.getArgs(), project, onItems, onFinish)
  }

  itemizeProject (project, data) {
    const items = []
    const rangeHint = {
      searchUseRegex: this.searchOptions.searchUseRegex,
      searchTerm: this.searchOptions.searchTerm,
      searchRegex: this.searchOptions.searchRegex
    }
    const lines = data.split(LineEndingRegExp)
    for (let line of lines) {
      const match = line.match(RegExpForOutPutLine)
      if (!match) continue
      items.push(new Item(match, project, rangeHint))
    }
    return items
  }
}
