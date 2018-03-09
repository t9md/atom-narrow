const {createRunner} = require('atom-mocha-test-runner')
const path = require('path')
const fs = require('fs-extra')
global.assert = require('chai').assert

module.exports = createRunner({globalAtom: false, htmlRemoveAtomStyle: false}, mocha => {
  global.atom = global.buildAtomEnvironment({enablePersistence: false})

  let packageName = require('../package.json').name
  const packageDir = path.join(atom.configDirPath, 'packages')
  fs.ensureSymlinkSync(path.dirname(__dirname), path.join(packageDir, packageName))
})
