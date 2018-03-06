const {createRunner} = require('atom-mocha-test-runner')
global.assert = require('chai').assert

module.exports = createRunner(
  {
    globalAtom: false,
    reporter: process.env.MOCHA_REPORTER || 'spec'
    // htmlTitle: `Narrow Package Tests - pid ${process.pid}`
  },
  mocha => {
    global.atom = buildAtomEnvironment({
      configDirPath: process.env.ATOM_HOME,
      enablePersistence: false
    })
  }
)
