const _ = require('underscore-plus')
const {limitNumber} = require('./utils')

class History {
  constructor (entries = []) {
    this.entries = entries
    this.maxSize = 20
    this.index = -1
  }

  get (direction) {
    const delta = direction === 'previous' ? +1 : -1
    this.index = limitNumber(this.index + delta, {min: -1, max: this.entries.length - 1})
    return this.entries[this.index]
  }

  save (text) {
    if (!text) return
    this.entries.unshift(text)
    this.entries = _.uniq(this.entries, entry => entry.toString())
    if (this.entries.length > this.maxSize) this.entries.splice(this.maxSize)
  }

  reset () {
    this.index = -1
  }

  destroy () {
    this.entries = null
  }
}

class QueryHistory {
  constructor () {
    this.historyByProviderName = {}
  }

  deserialize (state) {
    if (!state) return
    for (const name in state) {
      const entries = state[name]
      this.historyByProviderName[name] = new History(entries)
    }
  }

  serialize () {
    const state = {}
    for (const name in this.historyByProviderName) {
      const {entries} = this.historyByProviderName[name]
      state[name] = entries
    }
    return state
  }

  save (name, value) {
    if (!this.historyByProviderName[name]) {
      this.historyByProviderName[name] = new History()
    }
    this.historyByProviderName[name].save(value)
  }

  get (name, direction) {
    const history = this.historyByProviderName[name]
    return history ? history.get(direction) : ''
  }

  reset (name) {
    const history = this.historyByProviderName[name]
    if (history) history.reset()
  }

  clear (name) {
    delete this.historyByProviderName[name]
  }
}

module.exports = new QueryHistory()
