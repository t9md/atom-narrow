# narrow

narrow something.  
Code navigation tool inspired by unite.vim, emacs-helm.  

# Development status

alpha

# What's this

- Provide narrowing UI like unite/denite.vim or emacs-helm.
- But **not** aiming to become "can open anything from narrow-able UI" package.
- Primal focus is on **code-navigation**.
- Most of bundled providers are **bound to specific editor**.
- And sync current-item on narrow-UI as you move cursor on bounded editor.
- This **auto sync current-item with bounded editor** gives valuable context to programmer.

# Features

- Auto preview items under cursor(default `true` for all providers).
- Auto update items on narrow-editor when item changed(e.g. `narrow:lines` refresh items when text changed).
- Auto sync editor's cursor position to selected item on narrow-editor(narrowing UI).
- Navigate between narrowed items without focusing narrow-editor.
- Direct edit in narrow-editor which update realFile on disk by `narrow:update-real-file` commands.
- [vim-mode-plus](https://atom.io/packages/vim-mode-plus) integration( I'm also maintainer of vim-mode-plus ).

# Roles in play.

- `narrow-editor` or `narrow-ui`: handles user input and update narrowed item list.
- `narrow-provider`: Provide items to narrow and action to jump to item selected.

# Bundled providers

- `search`: Search by `ag`( you need to install `ag` by yourself).
- `atom-scan`: Similar to `search` but use Atom's `atom.workspace.scan`.
- `lines`: Narrow current editors lines.
- `fold`: Provide fold-starting rows as item.
- `git-diff`: Info source is from core `git-diff` package.
- `bookmarks`: For core `bookmarks` package
- `symbols`: Symbols are provided by core `symbols-views` package's.

# Quick tour

To follow this quick-tour, you don't need custom keymap.

### Step1. basic by using `narrow:lines`

Items are each lines on editor.

1. Open some text-editor, then via command-palette, invoke `Narrow Line`.
2. narrow-editor opened, as you type, you can narrow items.
3. When you type `apple lemmon` as query. lines which mached both `apple` and `lemmon` are listed.
4. You can move normal `up`, `down` key to quick-preview items.
5. `enter` to confirm. When confirmed, narrow-editor closed.

### Step2. navigate from outside of `narrow-editor`.

1. Open some text-editor, then via command-palette, invoke `Narrow Line`.
2. narrow-editor opened, as you type, you can narrow items.
3. Click invoking editor. And see your clicked position is auto reflected narrow-editor.
4. `ctrl-cmd-n` to move to `next-item`, `ctrl-cmd-p` to move to `previous-item`.
5. If you want to close narrow-editor you can close by `ctrl-g`(no need to focus narrow-editor).
6. If you want to change narrow-query, you have to focus to narrow-editor
  - Use `ctrl-cmd-f`(`narrow:focus`)
  - When re-focused to narrow-editor, cursor on narrow-editor is at selected-item.
  - You can move to prompt line by `tab`(`move-to-prompt-or-selected-item`), and back to selected-item by `tab` again.
7. These navigation keymaps are available for all provider(e.g. `search`, `fold` etc).

### Step3. [DANGER] direct-edit

Direct-edit is "edit on narrow-editor then save to real-file" feature.  
Available for these three providers `lines`, `search` and `atom-scan`.  

⚠️ This feature is really new and still experimental state.  
⚠️ Don't try code-base which is not managed by SCM.  
⚠️ I can say sorry, but I can not recover file for you.  

1. Open file from project, place cursor for variable name `hello`
2. Then invoke `Narrow Search By Current Word`.
3. All `hello` matching items are shows up on narrow-editor.
4. If you want, you can further narrow by query.
5. Then edit narrow-editor's text **directly**.
  - Place cursor on `hello`. Then `ctrl-cmd-g`(`find-and-replace:select-all`), then type `world`.
6. Invoke `Narrow Ui: Update Real File` from command-palette.
7. DONE, changes you made on narrow-editor items are applied to real-file(and saved).
8. You can undo changes by re-edit items on narrow-editor and reapply changes by `Narrow Ui: Update Real File`.

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
Start it from command-palette or set keymap by `keymap.cson`.

For other keymap, see [default keymap](https://github.com/t9md/atom-narrow/blob/master/keymaps/narrow.cson).

⚠️ Currently default-keymap is not yet settled, so sorry this will likely to change in future version.   

### My keymap(vim-mode-plus user)

```coffeescript
# From outside of narrow-editor
# -------------------------
'atom-text-editor.vim-mode-plus.normal-mode':
  'space o': 'narrow:fold'
  'space O': 'narrow:symbols'
  'space l': 'narrow:lines'
  'space L': 'narrow:lines-by-current-word'
  'space s': 'narrow:search'
  'space S': 'narrow:search-by-current-word'
  'space a': 'narrow:atom-scan'
  'space A': 'narrow:atom-scan-by-current-word'
  'space G': 'narrow:git-diff'
  'space B': 'narrow:bookmarks'

# To move to next/previous item from outside(also inside) of narrow
'atom-workspace.has-narrow atom-text-editor.vim-mode-plus.normal-mode':
  'up': 'narrow:previous-item'
  'down': 'narrow:next-item'

# Only on narrow-editor
# -------------------------
# narrow-editor regardless of mode of vim
'atom-text-editor.narrow.narrow-editor[data-grammar="source narrow"]':
  # Danger, apply change on narrow-editor to real file by `ctrl-cmd-s`.
  'ctrl-cmd-s': 'narrow-ui:update-real-file'

# narrow-editor.normal-mode
'atom-text-editor.narrow.narrow-editor.vim-mode-plus.normal-mode[data-grammar="source narrow"]':
  # confirm without closing narrow-editor by `;`.
  ';': 'narrow-ui:confirm-keep-open'
```

# vim-mode-plus integration.

If you are [vim-mode-plus](https://atom.io/packages/vim-mode-plus) user.
Following command are available from vim-mode-plus's search(`/` or `?`) mini-editor.
See [keymap definition](https://github.com/t9md/atom-narrow/blob/make-it-stable/keymaps/narrow.cson)

- `vim-mode-plus-user:narrow:lines`
- `vim-mode-plus-user:narrow:search`
- `vim-mode-plus-user:narrow:atom-scan`
- `vim-mode-plus-user:narrow:search-current-project`

# Recommended configuration for other packages.

- Suppress autocomplete-plus's popup on narrow-editor
- Disable vim-mode-plus's highlight-search on narrow-editor

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
