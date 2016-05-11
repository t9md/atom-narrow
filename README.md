# narrow

narrow something.  
similar to unite.vim, emacs-helm  

# Keymaps

```coffeescript
'atom-text-editor.vim-mode-plus.normal-mode':
  'space n l': 'narrow:lines'
  'space n f': 'narrow:fold'
  'space o': 'narrow:fold'
  'space n s': 'narrow:search'
  'f9': 'narrow:focus'
```

and see [default keymap](https://github.com/t9md/atom-narrow/blob/master/keymaps/main.cson)


# Advanced

init.coffee

```coffeescript
consumeService = (packageName, providerName, fn) ->
  disposable = atom.packages.onDidActivatePackage (pack) ->
    return unless pack.name is packageName
    service = pack.mainModule[providerName]()
    fn(service)
    disposable.dispose()

narrowSearch = null
consumeService 'narrow', 'provideNarrow', ({search}) ->
  narrowSearch = search

narrowSearchFromVimModePlusSearch = ->
  vimState = getEditorState(atom.workspace.getActiveTextEditor())
  text = vimState.searchInput.editor.getText()
  vimState.searchInput.confirm()
  console.log 'searching', text
  narrowSearch(text)

atom.commands.add 'atom-workspace',
  'user:narrow-search': -> narrowSearchFromVimModePlusSearch()
```

keymap.cson

```coffeescript
'atom-text-editor.vim-mode-plus-search':
  'ctrl-o': 'user:narrow-search'
```
