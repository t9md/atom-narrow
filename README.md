# narrow

narrow something.  
similar to unite.vim, emacs-helm  

# Development status

alpha

# Gifs

`narrow:lines`

![line](https://raw.githubusercontent.com/t9md/t9md/43b393e7e87bc36ee9dc309e9525050b95ec07ed/img/atom-narrow/lines.gif)


`narrow:fold`

![fold](https://raw.githubusercontent.com/t9md/t9md/43b393e7e87bc36ee9dc309e9525050b95ec07ed/img/atom-narrow/fold.gif)

`narrow:search` (require `ag`)

![search](https://raw.githubusercontent.com/t9md/t9md/43b393e7e87bc36ee9dc309e9525050b95ec07ed/img/atom-narrow/search.gif)

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

# vim-mode-plus integration.

If you are [vim-mode-plus](https://atom.io/packages/vim-mode-plus) user, following commands are provided.  
Both are directly invoke `lines` ore `search` form `vim-mode-plus:search` UI.

- `vim-mode-plus-user:narrow-lines-from-search`
- `vim-mode-plus-user:narrow-search-from-search`

Currently following keymap are defined(might be removed in future).

```coffeescript
'atom-text-editor.vim-mode-plus-search':
  'ctrl-o': 'vim-mode-plus-user:narrow-lines-from-search'
  'ctrl-cmd-o': 'vim-mode-plus-user:narrow-search-from-search'
```

So you can search `/` then type `abc` then `ctrl-o`, open `narrow:lines` with initial narrowing keyword `abc`.  
`ctrl-cmd-o` is `narrow:search` version of this.  

# Other config

If you want to start `insert-mode` for narrow-ui, refer following configuration.


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
- [ ] Use block decoration to show header
- [ ] Use block decoration to read narrow input?
- [ ] improve grammar modification, avoid flickering.
- [ ] More granular control by each narrow-provider such as auto-preview, where to open ui.
- [x] Confirm then close narrow editor?
- [ ] Add default providers for `recent-files,` `projects` etc.
