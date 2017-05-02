# narrow

[![Build Status](https://travis-ci.org/t9md/atom-narrow.svg?branch=master)](https://travis-ci.org/t9md/atom-narrow)
<!-- [![Join the chat at https://gitter.im/t9md/atom-narrow](https://badges.gitter.im/t9md/atom-narrow.svg)](https://gitter.im/t9md/atom-narrow?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) -->

narrow something.  
Code navigation tool inspired by unite.vim, emacs-helm.  
More information on [wiki](https://github.com/t9md/atom-narrow/wiki)

![narrow](https://raw.githubusercontent.com/t9md/t9md/4df5df86884a25bf8b62dc3b605df050a06c8232/img/atom-narrow/narrow.gif)

# What's this?

- Provide narrowing UI like emacs-helm and unite/denite.vim.
- But **not** aiming to become "can open anything from narrow-able UI" package.
- Primal focus is on **code-navigation**.
- Provider provide items( e.g. by `search` files in project ), you can filter items by query to narrow down further.
- As you move cursor on active-editor, **current** item on narrow-ui is automatically synced.
- You no longer lost like "Where am I?" when you are working on multiple files.
- Let narrow navigate to next/previous item to aid your concentration.
- Edit with confidence for no-overlook by direct-edit( edit on `ag search result` on narrow-editor then apply changes to real-file ).
- In mind
  - keyboard navigation.
  - [vim-mode-plus](https://atom.io/packages/vim-mode-plus) integration( I'm also maintainer of vim-mode-plus ).
- Also see [UseCase on wiki](https://github.com/t9md/atom-narrow/wiki/UseCase) and [Q&A on this doc](#qa)

# Roles in play.

- `narrow-editor` or `narrow-ui`: filter items by query and render items.
- `narrow-provider`: Provide items to narrow.

### overview

![overview](https://raw.githubusercontent.com/t9md/t9md/1654820b1f064aa11e087c7b3c1d6ce14ab03449/img/atom-narrow/overview.png)

### control bar

![control-bar](https://raw.githubusercontent.com/t9md/t9md/37f70896cb383f455f7a18a04d559e8adb05502c/img/atom-narrow/control-bar.png)

# Bundled providers

You can check GIFs for all bundled provider [here](https://github.com/t9md/atom-narrow/wiki/Provider).  
I use `scan`, `search`, `git-diff-all`, `symbols` in daily-basis, for other providers I don't use much.  

- `scan`: Scan current editor.
- `search`: Search by `ag`( you need to install `ag` by yourself).
- `atom-scan`: Similar to `search` but use Atom's `atom.workspace.scan`.
- `fold`: Provide fold-starting rows as item.
- `git-diff`: Show git-diff for current active-editor. Info source is from core `git-diff` package.
- `git-diff-all`: Show all modified state file across project.
- `bookmarks`: For core `bookmarks` package
- `symbols`: Provide symbols for current file.
- `project-symbols`: Provide project-wide symbols information by reading `tags` file.
- `linter`: Use message provided by [linter](https://atom.io/packages/linter) package.

# Quick tour

To follow this quick-tour, you don't need custom keymap.

### Step1. basic by using `narrow:scan`

1. Open some text-editor, then via command-palette, invoke `Narrow Scan`.
2. `narrow-editor` opened, Initial items are each lines on editor. As you type, you can narrow items.
3. When you type `apple` as query. all `apple` matching items are listed.
4. You can move normal `up`, `down`(or `j`, `k` in read-only mode) key to quick-preview items.
5. `enter` to confirm. When confirmed, `narrow-editor` closed.

The read-only mode is enabled by default.

### Step2. navigate from outside of `narrow-editor`.

1. Open some text-editor, then via command-palette, invoke `Narrow Scan`.
2. `narrow-editor` opened. As you type, you can narrow items.
3. Click invoking editor. And see your clicked position is automatically reflected `narrow-editor`.
4. `ctrl-cmd-n` to move to `next-item`, `ctrl-cmd-p` to move to `previous-item`.
  - If you are vim-mode-plus user, You can use `tab` and `shift-tab`.
5. You can close `narrow-editor` by `ctrl-g`( no need to focus `narrow-editor` ).
6. If you want to change narrow-query, you have to focus to `narrow-editor`
  - Use `ctrl-cmd-f`( `narrow:focus` ) to focus `narrow-editor`.
  - Use `ctrl-cmd-i`( `narrow:focus-prompt` ) to directly focus narrow-editor's query prompt row.
  - Both commands are available from outside/inside of narrow-editor.
7. These navigation keymaps are available for all provider(e.g. `search`, `fold` etc).

### Step3. direct-edit

Direct-edit is "edit on `narrow-editor` then save to real-file" feature.  
Available for following providers.

- `scan`
- `search`
- `atom-scan`

⚠️ This operation is dangerous, since you can update multiple files at once.
⚠️ You have to be careful enough to use this feature, don't use this without understanding what you are doing.
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

### Step4. [Experimental] search keyword by mouse

1. Set `Search.startByDoubleClick` to `true` from settings-view.
2. Double click keyword in editor.
3. Each time you double click keyword, new narrow-editor open and old one is replaced.
4. You can continue double click which ever narrow-editor or normal-editor.

# Commands

### Available in all text-editor

##### Other

- `narrow:focus`: ( `ctrl-cmd-f` ) Focus to `narrow-editor`, if executed in `narrow-editor`, it re-focus to original editor.
- `narrow:focus-prompt`: ( `ctrl-cmd-i` ) Focus to `narrow-editor`'s query input prompt, if executed in `narrow-editor`, it re-focus to original editor.
- `narrow:refresh`: Manually refresh items in `narrow-editor`.
- `narrow:close`: ( `ctrl-g` ) Close currently opened `narrow-editor` one at a time.
- `narrow:next-item`: ( `ctrl-cmd-n` ) Move cursor to position of next-item.
- `narrow:previous-item`: ( `ctrl-cmd-p` ) Move cursor to position of previous-item.
- `narrow:reopen`: ( no default keymap ) Reopen closed narrow editor up to 10 recent closed.

##### Invoke narrow provide

No keymaps are provided

- `narrow:scan`
- `narrow:scan-by-current-word`
- `narrow:fold`
- `narrow:fold-by-current-word`
- `narrow:search`: [ag](https://github.com/ggreer/the_silver_searcher) search. need install by your self.
- `narrow:search-by-current-word`
- `narrow:search-current-project`
- `narrow:search-current-project-by-current-word`
- `narrow:atom-scan`
- `narrow:atom-scan-by-current-word`
- `narrow:symbols`
- `narrow:symbols-by-current-word`
- `narrow:project-symbols`:
- `narrow:project-symbols-by-current-word`:
- `narrow:linter`
- `narrow:bookmarks`
- `narrow:git-diff`
- `narrow:git-diff-all`

### Available in narrow-editor(narrow-ui)

- `core:confirm`: ( `enter` ) Close `narrow-editor`
- `narrow-ui:confirm-keep-open`: keep open `narrow-editor`
- `narrow-ui:preview-item`: Preview currently selected item manually( you don't need in most case ).
- `narrow-ui:preview-next-item`: ( `tab` ) Preview next-item without moving cursor from `narrow-editor`'s query prompt.
- `narrow-ui:preview-previous-item`: ( `shift-tab` ) Preview next-item without moving cursor from `narrow-editor`'s query prompt.
- `narrow-ui:toggle-auto-preview`: ( `ctrl-r` for non-vim-mode-plus user) Disable/enable auto-preview for this `narrow-editor`.
- `narrow-ui:move-to-prompt`: `ctrl-cmd-i`
- `narrow-ui:start-insert`: `I`, `a`
- `narrow-ui:stop-insert`: `escape`
- `narrow-ui:update-real-file`: Apply changes made in `narrow-editor` to real-file.( edit in `narrow-editor` then save it to real file. )
- `narrow-ui:protect`: No keymap by default, Protect narrow-editor from being destroyed by `narrow:close`( `ctrl-g` ).
- `narrow-ui:exclude-file`: `backspace`, Exclude items which matches filePath of currently selected item's.
- `narrow-ui:clear-excluded-files`: `ctrl-backspace`, Clear excluded files list.
- `narrow-ui:select-files`: `cmd-backspace`, interactively select which filePath's items to appear on `narrow-editor`.
- `narrow-ui:move-to-next-file-item`: `n`
- `narrow-ui:move-to-previous-file-item`: `p`
- `narrow-ui:toggle-search-whole-word`: `alt-cmd-w`
- `narrow-ui:toggle-search-ignore-case`: `alt-cmd-c`

# Keymaps

No keymap to invoke narrow provider(e.g `narrow:scan`).  
Start it from command-palette or set keymap in `keymap.cson`.

⚠️ [default keymap](https://github.com/t9md/atom-narrow/blob/master/keymaps/narrow.cson) is not yet settled, this will likely to change in future version.   

### My keymap(vim-mode-plus user) and config


###### `config.cson`

For `git-diff-all`, and `search`, I want to close manually by `ctrl-g`.
So disable `closeOnConfirm`.

```
  narrow:
    GitDiffAll:
      closeOnConfirm: false
    Search:
      closeOnConfirm: false
      rememberIgnoreCaseForByCurrentWordSearch: true
    SelectFiles:
      rememberQuery: true
    confirmOnUpdateRealFile: false
```

###### `keymap.cson`

Explanation of my keymap.

- `cmd-f`: To focus to narrow-editor AND focus-back to original-editor
- `cmd-i`: To focus to narrow-editor's prompt AND focus-back to original-editor
- `enter`: start `narrow:search-by-current-word` from `vim-mode-plus`'s `normal-mode`
  - Just `enter` start search cursor-word.
- `ctrl-g`: Close `narrow-editor` from wherever.
- `tab`, `shift-tab`: to move to next/previous item.
- `;`: confirm current-item without closing `narrow-editor`, I can close `narrow-editor` by `ctrl-g`.

```coffeescript
# From outside of narrow-editor
# -------------------------
'atom-text-editor.vim-mode-plus.normal-mode':
  # For frequent uses, assign shorter keymap(non-2-step keymap).
  'ctrl-z': 'narrow:reopen'

  'cmd-o': 'narrow:symbols-by-current-word' # quick preview function
  'cmd-l': 'narrow:scan-by-current-word'
  'enter': 'narrow:search-by-current-word'
  'shift-cmd-g': 'narrow:search-by-current-word'

  'shift-cmd-o': 'narrow:project-symbols-by-current-word'
  'shift-cmd-r': 'narrow:project-symbols'

  # assign consistently
  'space f': 'narrow:fold'
  'space o': 'narrow:symbols'
  'space l': 'narrow:scan'
  'space L': 'narrow:scan-by-current-word'
  'space c': 'narrow:linter'
  'space s': 'narrow:search'
  'space S': 'narrow:search-by-current-word'
  'space a': 'narrow:atom-scan'
  'space A': 'narrow:atom-scan-by-current-word'
  'space G': 'narrow:git-diff-all'
  'space B': 'narrow:bookmarks'

# When workspace has narrow-editor
'atom-workspace.has-narrow atom-text-editor.vim-mode-plus.normal-mode':
  'cmd-f': 'narrow:focus' # focus to narrow-editor
  'cmd-i': 'narrow:focus-prompt' # focus to prompt of narrow-editor
  'ctrl-cmd-l': 'narrow:refresh' # manually refresh items

# narrow-editor regardless of mode of vim
'atom-text-editor.narrow.narrow-editor[data-grammar="source narrow"]':
  'cmd-f': 'narrow:focus'
  'cmd-i': 'narrow:focus-prompt' # cmd-i to return to calling editor.
  # Danger: apply change on narrow-editor to real file by `cmd-s`.
  'cmd-s': 'narrow-ui:update-real-file'

'atom-text-editor.narrow.narrow-editor.vim-mode-plus.normal-mode[data-grammar="source narrow"]':
  # Danger: I use direct-edit very frequently, so intentionally recover `i` of vim-mode-plus.
  'i': 'vim-mode-plus:activate-insert-mode'
  '-': 'narrow-ui:exclude-file'
  '=': 'narrow-ui:clear-excluded-files'
  's': 'narrow-ui:select-files'
  "enter": 'core:confirm' # recover original enter for narrow-editor
```

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

# Notes for vim-mode-plus user

## ⚠️ Limitation: for compatibility with vim-mode-plus.

- If you use atom v1.16.0 or older,
  - Don't enable `vim-mode-plus.automaticallyEscapeInsertModeOnActivePaneItemChange`
  - If you enabled, each query input on narrow-editor of `search` provider cause mode-change from `insert-mode` to `normal-mode`.
- If you use atom v1.17.0 or older( currently in beta ).
  - This limitation is no longer exists.

## Keymap

Learn [keymap](https://github.com/t9md/atom-narrow/blob/master/keymaps/narrow.cson) available as default.  
e.g. You can move to next or previous item by `tab`, `shift-tab`(for this to work, you need vim-mode-plus v0.81.0 or later).  

## Start narrow from vim-mode-plus's search-input-form

If you are [vim-mode-plus](https://atom.io/packages/vim-mode-plus) user.
Following command are available from vim-mode-plus's search(`/` or `?`) mini-editor.

- `vim-mode-plus-user:narrow:scan`
- `vim-mode-plus-user:narrow:search`
- `vim-mode-plus-user:narrow:search-current-project`
- `vim-mode-plus-user:narrow:atom-scan`

## How to edit item-area for direct-edit.

- In narrow-editor, `i`, `a` in `normal-mode` move cursor to prompt line.
- So when you want to edit items itself for `direct-edit` and `update-real-file` use other key to enter `insert-mode`.
- `I` is intentionally mapped to `vim-mode-plus:activate-insert-mode` which is normally mapped to `i`.
  - Which might not be intuitive, but I want make item mutatation bit difficult. So user have to type `I`.
- Other than `I`, you can start `insert-mode` by `A`, `c` etc..

# Q&A

### What providers are you seriously using?

In daily editing, I use.

`scan`, `search`, `git-diff-all`, `symbols`.

Why I'm not using others? reason is here.

- `fold`: Since it similar to `symbols`.
- `git-diff`: since `git-diff-all` is better.
- `bookmarks`: since I don' use `bookmarks` feature
- `linter`: rarely use it( this is just-tried-idea state, not polished ).
- `atom-scan`: it is provided for windows user who can't use `search`(need `ag`).

### How can I exclude particular file from `narrow:search`

##### Use `backspace` on item

- Use `backspace` to exclude particular file from result.
- `ctrl-backspace` clear excluded file list and refresh
- These keymaps are available in `narrow-editor` and you are in `read-only-mode`

##### Use `select-files` provider

- You can launch `select-files` by `cmd-backspace` or clicking `folder-icon` on **control-bar**.

1. search `editor` by `narrow:search`, you see lots of `editor` mached items
2. But you want exclude items in markdown file?
  - launch `select-files`, all file paths are listed as item.
  - Then type `md` on query, you see markdown filepath that macheed `md`.
  - Then add `!`, now your query is `md!`, this is treated as all files **not** matching `md`.
  - `enter` to confirm.
3. You see items with items in markdown files are excluded.
4. You can re-fine files to exclude by re-launching `select-files`.
  - e.g. To exclude `spec` folder, you can add `spec/!` as query.
  - e.g. To include `.js` file only, you can set query to `.js`.

### Want to skip to `next-file`, `previous-file`

- Use `n`, `p` in `read-only` mode.

### I want `narrow:symbols` always shows up at right-most pane and don't want to close.

1. Open `narrow:symbols`( or maybe you want to use `narrow:fold` )
2. Move this `narrow-editor` by drag and drop to the place where you want.
3. From command-palette, execute `Narrow Ui: Protect`. Now `narrow-editor` protected.
4. Protected `narrow-editor` is not closed by `ctrl-g`( `narrow:close` ), and not closed by confirm by `enter`.
5. To close, use normal `cmd-w` or close button on tab.
