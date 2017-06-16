const _ = require("underscore-plus")

// Config definitions
// -------------------------
function inheritGlobalEnum(name) {
  return {
    default: "inherit",
    enum: ["inherit", ...globalSettings[name].enum],
  }
}

const globalSettings = {
  autoShiftReadOnlyOnMoveToItemArea: {
    default: true,
    description: "When cursor moved to item area automatically change to read-only mode",
  },
  directionToOpen: {
    default: "right",
    enum: [
      "right",
      "right:never-use-previous-adjacent-pane",
      "right:always-new-pane",
      "down",
      "down:never-use-previous-adjacent-pane",
      "down:always-new-pane",
    ],
    description: "Where to open narrow-editor when open by split pane.",
  },
  caseSensitivityForNarrowQuery: {
    default: "smartcase",
    enum: ["smartcase", "sensitive", "insensitive"],
    description: "Case sensitivity of your query in narrow-editor",
  },
  confirmOnUpdateRealFile: true,
  queryCurrentWordByDoubleClick: true,
}

const ProviderConfigTemplate = {
  directionToOpen: inheritGlobalEnum("directionToOpen"),
  caseSensitivityForNarrowQuery: inheritGlobalEnum("caseSensitivityForNarrowQuery"),
  revealOnStartCondition: {
    default: "always",
    enum: ["always", "never", "on-input"],
  },
  focusOnStartCondition: {
    default: "always",
    description: "Condition when focus to narrow-editor on start",
    enum: ["always", "never", "no-input"],
  },
  negateNarrowQueryByEndingExclamation: false,
  autoPreview: true,
  autoPreviewOnQueryChange: true,
  closeOnConfirm: true,
}

const SearchFaimilyConfigTemplate = {
  caseSensitivityForSearchTerm: {
    default: "smartcase",
    enum: ["smartcase", "sensitive", "insensitive"],
  },
  revealOnStartCondition: "on-input",
  searchWholeWord: false,
  searchUseRegex: false,
  refreshDelayOnSearchTermChange: 700,
}

const searchFamilyConfigs = {
  Scan: {
    refreshDelayOnSearchTermChange: 10,
  },
  Search: {
    searcher: {
      default: "ag",
      enum: ["ag", "rg"],
      description: "Choose `ag`( The silver searcher) or `rg`( ripgrep )",
    },
    startByDoubleClick: {
      default: false,
      description: [
        "[Experimental]: start by dounble click.",
        "You can toggle this value by command `narrow:toggle-search-start-by-double-click`",
      ].join("\n"),
    },
  },
  AtomScan: {},
}

const otherProviderConfigs = {
  Symbols: {
    revealOnStartCondition: "on-input",
  },
  GitDiffAll: {},
  Fold: {
    revealOnStartCondition: "on-input",
  },
  ProjectSymbols: {
    revealOnStartCondition: "on-input",
  },
  SelectFiles: {
    autoPreview: false,
    autoPreviewOnQueryChange: false,
    negateNarrowQueryByEndingExclamation: true,
    closeOnConfirm: true,
    revealOnStartCondition: "never",
    rememberQuery: {
      default: false,
      description: "Remember query per provider basis and apply it at startup",
    },
  },
}

// Utils
// -------------------------
function inferType(value) {
  if (Number.isInteger(value)) return "integer"
  if (typeof value === "boolean") return "boolean"
  if (typeof value === "string") return "string"
  if (Array.isArray(value)) return "array"
}

function complimentField(config, injectTitle = false) {
  // Automatically infer and inject `type` of each config parameter.
  // skip if value which aleady have `type` field.
  // Also translate bare `boolean` value to {default: `boolean`} object
  for (let key of Object.keys(config)) {
    const value = config[key]
    const inferedType = inferType(value)
    if (inferedType) {
      config[key] = {default: value}
      config[key].type = inferedType
    }

    if (!value.type) value.type = inferType(value.default)

    // To remove provider prefix
    // e.g. "Scan.AutoPreview" config to appear as "Auto Preview"
    if (injectTitle && !value.title) value.title = _.uncamelcase(key)
  }

  // Inject order props to display orderd in setting-view
  let order = 0
  for (const name of Object.keys(config)) {
    config[name].order = order++
  }

  return config
}

// Main
// -------------------------
class Settings {
  constructor(scope, config) {
    this.scope = scope
    this.config = config
    this.providerConfigOrder = 101
    complimentField(this.config)
  }

  get(param) {
    return atom.config.get(`${this.scope}.${param}`)
  }

  set(param, value) {
    return atom.config.set(`${this.scope}.${param}`, value)
  }

  toggle(param) {
    return this.set(param, !this.get(param))
  }

  has(param) {
    return param in atom.config.get(this.scope)
  }

  delete(param) {
    return this.set(param, undefined)
  }

  observe(param, fn) {
    return atom.config.observe(`${this.scope}.${param}`, fn)
  }

  registerProviderConfig(object, otherTemplate) {
    for (const key of Object.keys(object)) {
      this.config[key] = {
        type: "object",
        collapsed: true,
        properties: this.createProviderConfig(otherTemplate, object[key]),
        order: this.providerConfigOrder++,
      }
    }
  }

  createProviderConfig(...configs) {
    const config = Object.assign({}, ProviderConfigTemplate, ...configs)
    return complimentField(config, true)
  }

  removeDeprecated() {
    const paramsToDelete = []
    const loaded = atom.config.get(this.scope)
    for (let param of Object.keys(loaded)) {
      if (!(param in this.config)) {
        paramsToDelete.push(param)
      } else if (this.config[param].type === "object") {
        // Provider config
        const providerName = param
        const loadedForProvider = loaded[providerName]
        const definedForProvider = this.config[providerName].properties
        for (const _param of Object.keys(loadedForProvider)) {
          if (!(_param in definedForProvider)) {
            paramsToDelete.push(providerName + "." + _param)
          }
        }
      }
    }
    if (paramsToDelete.length) {
      this.notifyAndDelete(...paramsToDelete)
    }
  }

  notifyAndDelete(...params) {
    const content = [
      `${this.scope}: Config options deprecated.  `,
      "Automatically removed from your `config.cson`  ",
    ]
    for (let param of params) {
      this.delete(param)
      content.push(`- \`${param}\``)
    }
    atom.notifications.addWarning(content.join("\n"), {dismissable: true})
  }
}

const settings = new Settings("narrow", globalSettings)
settings.registerProviderConfig(searchFamilyConfigs, SearchFaimilyConfigTemplate)
settings.registerProviderConfig(otherProviderConfigs)

module.exports = settings
