# narrow

narrow something.  
similar to unite.vim, emacs-helm  

# Development status

alpha

# Features

- Search across project via `ag`.
- autoPreview items under cursor.
- [vim-mode-plus](https://atom.io/packages/vim-mode-plus) integration.

# Architecture(not settled yet)

- `narrow:ui`: handles user input and update view.
- `narrow-provider`: Provide items to narrow and action to jump to item selected.

# Bundled providers

- lines: narrow current editors lines
- fold: provide fold-starting rows as item.
- search: provide matched text as items via `ag` search.
- git-diff: for core git-diff package
- bookmarks: for core bookmarks package
- symbols: provide symbols as item, equivalent to core symbols-views package's `toggle-file-symbols` command.

# Gifs

`narrow:lines`

![line](https://raw.githubusercontent.com/t9md/t9md/43b393e7e87bc36ee9dc309e9525050b95ec07ed/img/atom-narrow/lines.gif)


`narrow:fold`

![fold](https://raw.githubusercontent.com/t9md/t9md/43b393e7e87bc36ee9dc309e9525050b95ec07ed/img/atom-narrow/fold.gif)

`narrow:search` (require `ag`)

![search](https://raw.githubusercontent.com/t9md/t9md/43b393e7e87bc36ee9dc309e9525050b95ec07ed/img/atom-narrow/search.gif)

# Commands

### global Commands

- `narrow:lines`
- `narrow:lines-by-current-word`
- `narrow:fold`
- `narrow:fold-by-current-word`
- `narrow:search`: [ag](https://github.com/ggreer/the_silver_searcher) search. need install by your self.
- `narrow:search-by-current-word`
- `narrow:search-current-project`
- `narrow:search-current-project-by-current-word`
- `narrow:focus`
- `narrow:symbols`
- `narrow:bookmarks`
- `narrow:git-diff`

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
  'space o': 'narrow:fold'
  'space l': 'narrow:lines'
  'space s': 'narrow:search-current-project'
  'space S': 'narrow:symbols'
  'space G': 'narrow:git-diff'
  'space B': 'narrow:bookmarks'

# available only when some narrow was opened.
'atom-workspace.has-narrow atom-text-editor.vim-mode-plus:not(.narrow)':
  'ctrl-cmd-f': 'narrow:focus'
  'ctrl-cmd-p': 'narrow:previous-item'
  'ctrl-cmd-n': 'narrow:next-item'
  'up': 'narrow:previous-item'
  'down': 'narrow:next-item'
```

# vim-mode-plus integration.

If you are [vim-mode-plus](https://atom.io/packages/vim-mode-plus) user, following commands are provided.  
Both are directly invoke `lines` ore `search` form `vim-mode-plus:search` UI.

- `vim-mode-plus-user:narrow-search-current-project`
- `vim-mode-plus-user:narrow-search-projects`

Currently following keymap are defined(might be removed in future).

```coffeescript
'atom-text-editor.vim-mode-plus-search':
  'ctrl-o': 'vim-mode-plus-user:narrow-lines-from-search'
  'ctrl-cmd-o': 'vim-mode-plus-user:narrow-search-from-search'
```

So you can search `/` then type `abc` then `ctrl-o`, open `narrow:lines` with initial narrowing keyword `abc`.  
`ctrl-cmd-o` is `narrow:search` version of this.  

### vmpStartInInsertModeForUI settings.

default: `true`.

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
```
