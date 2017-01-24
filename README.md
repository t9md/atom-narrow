# narrow

narrow something.  
Code navigation tool inspired by unite.vim, emacs-helm.  

# Development status

alpha

# What's this

narrow provide narrowing UI like unite/denite.vim or emacs-helm.  
But unlike these predecessor, narrow's primal focus is on code navigation.  
So most of bundled providers are **bound to particular editor** and updated selected item indicator as you move cursor on editor.  
You can move around quickly between narrowed item as long as easy to see where am I in all items since cursor position change automatically reflected to narrow-editor.  

# Features

- Auto preview items under cursor(default `true` for all providers).
- Auto update items on narrow-editor when item changed(e.g. `narrow:lines` refresh items when text changed).
- Auto sync editor's cursor position to selected item on narrow-editor(narrowing UI).
- Navigate between narrowed items without focusing narrow-editor.
- Direct edit in narrow-editor which update realFile on disk by `narrow:update-real-file` commands.
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

Currently default-keymap is not yet settled, so sorry this will likely to change in future version.

### my keymap(vim-mode-plus user)

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
  'ctrl-g': 'narrow:close'
  'ctrl-cmd-f': 'narrow:focus'
  'ctrl-cmd-p': 'narrow:previous-item'
  'ctrl-cmd-n': 'narrow:next-item'
  'up': 'narrow:previous-item'
  'down': 'narrow:next-item'

# On narrow-editor
'atom-text-editor.narrow.narrow-editor.vim-mode-plus[data-grammar="source narrow"]':
  'ctrl-g': 'core:close'
  'tab': 'narrow-ui:move-to-prompt-or-selected-item'
  'ctrl-cmd-s': 'narrow-ui:update-real-file'

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
  # snip
  "vim-mode-plus":
    highlightSearchExcludeScopes: [
      "narrow"
    ]
```
