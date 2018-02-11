module.exports = class ScopedConfig {
  constructor (scope) {
    this.scope = scope
  }

  get (name) {
    const value = atom.config.get(`${this.scope}.${name}`)
    if (value === 'inherit') {
      return atom.config.get(`narrow.${name}`)
    } else {
      return value
    }
  }

  set (name, value) {
    atom.config.get(`${this.scope}.${name}`, value)
  }
}
