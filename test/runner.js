const {createRunner} = require('atom-mocha-test-runner')
const path = require('path')
const fs = require('fs-extra')
global.assert = require('chai').assert

module.exports = createRunner(
  {
    globalAtom: false,
    htmlTitle: `Narrow Package Tests - pid ${process.pid}`
    // onCreated: () => {
    //   // console.log('CREATED!!!')
    //   // workspaceElement = atom.views.getView(atom.workspace)
    //   // document.body.appendChild(workspaceElement)
    //   // document.body.focus()
    // }
  },
  mocha => {
    global.atom = global.buildAtomEnvironment({
      enablePersistence: false
    })
    // mocha.ui('tdd')
    // atom.applicationDelegate.setRepresentedFilename = () => {}
    // atom.applicationDelegate.setWindowDocumentEdited = () => {}

    let packageName = require('../package.json').name
    const packageDir = path.join(atom.configDirPath, 'packages')
    fs.ensureSymlinkSync(path.dirname(__dirname), path.join(packageDir, packageName))
  }
)
