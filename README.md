# narrow

narrow something.  
similar to unite.vim, emacs-helm  

# Development status

alpha

# Gifs

`narrow:lines`

![line](https://raw.githubusercontent.com/t9md/t9md/e294456412d24208b48d623508cd5e8d39ab83fe/img/atom-narrow/line.gif)

`narrow:fold`

![fold](https://raw.githubusercontent.com/t9md/t9md/e294456412d24208b48d623508cd5e8d39ab83fe/img/atom-narrow/fold.gif)

`narrow:search` (require `ag`)

![search](https://raw.githubusercontent.com/t9md/t9md/e294456412d24208b48d623508cd5e8d39ab83fe/img/atom-narrow/search.gif)

# Commands

### global

Start narrowing by invoking one of following command.

- `narrow:lines`: Lines of current buffer.
- `narrow:fold`: Fold start rows.
- `narrow:search`: [ag](https://github.com/ggreer/the_silver_searcher) search. need install by your self.
- `narrow:focus`: Focus narrow editor. use this directly focus from other pane item.

### narrow-ui

- `core:confirm`
- `narrow-ui:preview-item`
- `narrow-ui:toggle-auto-preview`

# Keymaps

No keyamp to invoke global command(e.g `narrow:lines`).
narrow-ui have limited default keymap, see [default keymap](https://github.com/t9md/atom-narrow/blob/master/keymaps/main.cson).

- Mine(vim-mode-plus user) for global command.
```coffeescript
'atom-text-editor.vim-mode-plus.normal-mode':
  'space n l': 'narrow:lines'
  'space n f': 'narrow:fold'
  'space o': 'narrow:fold'
  'space n s': 'narrow:search'
  'f9': 'narrow:focus'
```

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

# Other config

config.cson

```coffeescript
"*":
  "autocomplete-plus":
    suppressActivationForEditorClasses: [
      # snip
      "narrow"
    ]
  "vim-mode-plus":
    highlightSearchExcludeScopes: [
      "narrow"
    ]
    startInInsertModeScopes: [
      "narrow"
    ]
```

# TODOs

lots of todo.
- [ ] improve grammar modification, avoid flickering.
- [ ] Confirm then close narrow editor?
