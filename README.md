# narrow

narrow something.  
similar to unite.vim, emacs-helm  

# Commands

### global

Start narrowing by invoking one of following command.

- `narrow:lines`: Lines of current buffer.
- `narrow:fold`: Fold start rows.
- `narrow:search`: [ag](https://github.com/ggreer/the_silver_searcher) search. need install by your self.
- `narrow:focus`: Focus narrow editor. use this directly focus from other pane item.

### in narrow editor

- `core:confirm`
- `narrow:ui:reveal-item`
- `narrow:ui:toggle-auto-reveal`

# Keymaps

No default keymap.

- Normal user

```coffeescript
# Need improve following example for normal user.
'atom-text-editor.narrow[data-grammar="source narrow"]':
  'enter': 'core:confirm'
  'ctrl-u': 'narrow:ui:reveal-item'
  'ctrl-r': 'narrow:ui:toggle-auto-reveal'
```

- Mine(vim-mode-plus user)
```coffeescript
'atom-text-editor.narrow.vim-mode-plus.normal-mode[data-grammar="source narrow"]':
  'enter': 'core:confirm'
  'q': 'core:close'
  'o': 'core:confirm'
  'u': 'narrow:ui:reveal-item'
  'r': 'narrow:ui:toggle-auto-reveal'

'atom-text-editor.narrow.vim-mode-plus.insert-mode[data-grammar="source narrow"]':
  'enter': 'core:confirm'

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

# TODOs

lots of todo.
- [ ] improve grammar modification, avoid flickering.
- [ ] Confirm then close narrow editor?
