# narrow

narrow something.  
similar to unite.vim, emacs-helm  

# Development status

alpha

# Features

- autoPreview items under cursor.
- Auto sync narrow-bounded-editor's cursor position to selected intem on narrow UI.
- [vim-mode-plus](https://atom.io/packages/vim-mode-plus) integration.

# Architecture(not settled yet)

- `narrow:ui`: handles user input and update view.
- `narrow-provider`: Provide items to narrow and action to jump to item selected.

# Bundled providers

- search: provide matched text as items via `ag` search.
- lines: narrow current editors lines
- fold: provide fold-starting rows as item.
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

No keymap to invoke global command(e.g `narrow:lines`).  
narrow-ui have limited default keymap, see [default keymap](https://github.com/t9md/atom-narrow/blob/master/keymaps/narrow.cson).

- Mine(vim-mode-plus user) for global command.
```coffeescript
'atom-text-editor.vim-mode-plus.normal-mode':
  'space o': 'narrow:fold'
  'space O': 'narrow:symbols'
  'space l': 'narrow:lines'
  'space L': 'narrow:lines-by-current-word'
  'space s': 'narrow:search-current-project'
  'space S': 'narrow:search-by-current-word'
  # 'space S': 'narrow:symbols'
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

If you are [vim-mode-plus](https://atom.io/packages/vim-mode-plus) user,
you can invoke `lines`, `search` directly from vim-mode-plus's search form.

Check [keymap definition](https://github.com/t9md/atom-narrow/blob/make-it-stable/keymaps/narrow.cson)

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
