# 0.23.0: WIP
- New: #121, New provider `git-diff-all`.
  - Show git diff items across projects( Existing `git-diff` shows diff for current file only )

# 0.22.0:
- New: #118, Show provider specific information above prompt.
  - All provider shows item count.
  - For `scan`, `search`, `atom-scan` specific.
    - Loading indicator.
    - Button to toggle `ignoreCase`, `wholeWord` and show tooltips when mouseover.
  - Achieved by block-decoration(since I want keep `narrow-editor` really normal text-editor).
    - Recover block-decoration(destroy and re-decorate) when prompt on accidental prompt row removal.
  - For `narrow:scan`, search term can be changed multiple times.
    - Unless manually changed by button or shortcut, it respect `caseSensitivityForSearchTerm`
- Improve UX: Show buffer lines on empty query( = empty searchTerm ) for `narrow:scan`.
  - Also limit minimum column width to 2 to avoid side move items( since initial column is 1 ).
- Fix: No longer throw error when confirm with empty item list
- Fix: When `narrow:focus`. `ReferenceError: otherEditors is not defined`( oversight when renaming )
- Breaking, Improve: #116 `ctrl-l` in vim-mode-plus-search input start `narrow:scan`( was `narrow:lines` before ).
- Improve UX: #117 open `narrow-editor` on same pane of existing `narrow-editor` when narrow is started from `narrow-editor`.

# 0.21.0:
- New: Provider `scan` as better `narrow:lines`
  - Commands
    - `narrow:scan`: start `scan`.
    - `narrow:scan-by-current-word`: start `scan` by passing current-word as initial query input.
    - `narrow:scan:toggle-whole-word`: toggle whole word scan on narrow-editor.
  - Why better than `narrow:lines`?
    - It can highlight.
    - It can show multiple matches on same line as different items.
    - Move you precise position when navigating by `next-item`, `previous-item`.
  - Some exceptional characteristics important to understand.
    - Use `editor.scan` under the hood.
    - It use first narrow query as search term( first word separated by white-spaces on query text ).
    - Rest of include and exclude(`!` starting word) queries are treated as normal filter query.
    - To make this exceptional query handling obvious by eye, use different syntax grammar highlight for first query(= scan term).
    - It start with empty items, since no query means no scan-term provided.
- New: UI command to toggle search option on the fly.
  - `narrow-ui:toggle-search-whole-word`: `alt-cmd-w` )
  - `narrow-ui:toggle-search-ignore-case`: `alt-cmd-c` )
  - Currently you can not see current search option state('`searchIgnoreCase`, `searchWholeWord`').
    - Will come in future version!!
- New: Config `searchWholeWord`. Used to determine initial value of whole-word-search.
  - `Scan.searchWholeWord`
  - `AtomScan.searchWholeWord`
  - `Search.searchWholeWord`
- Improve: Faster highlight than v0.20.0 by letting item hold range and use it for decoration.
  - No longer heavier `editor.scan` to matching start of range against item.point.

# 0.20.1:
- Fix: #107 `Error: The workspace can only contain one instance of item [object Object](…)`
  - Critical and wanted to fix, I could finally found the cause and fixed!!
  - Was happened tying to open item for filePath-A when `narrow-editor`'s pane have editor for filePath-A as item.
  - This situation result in trying to one editor(pane-item) activate on multiple-pane, but no-longer!!
- Fix: `Point` is not imported on `utils.coffee`. rarely evaluated code pass, I can't describe what situation cause error by this bug.

# 0.20.0:
- New, Improve: Show multiple matches on same line for `search` and `atom-scan`
  - Show column for `search`, `atom-scan`
  - Add protection for `update-real-file` by detecting conflicting change to same line.
    - e.g
      - When you have text file which content is "test abc abc\n"
      - search `abc` now shows two items(since one line contain two `abc`).
      - So user can edit these two items **differently** and try to `update-real-file`.
      - But this is not allowed, detect conflict and show warning.
- Breaking, Experiment: Remove indentation of lineHeader for more space for line text.
- Improve: #106 highlight matches for provider `search` and `atom-scan`.
  - Update current match highlight on each sync-editor-to-ui.
- Improve: Adjust point to first-character-of-line( was column 0 ) for provider `fold` and `symbols`.
- Improve: #102 Change itemIndicator color for protected `narrow-editor`.
- Improve: Improve UX when `narrow:close`( `ctrl-g` ) is executed on protected `narrow-editor`.
  - No longer close un-protected `narrow-editor`.
  - Clear query then refocus to caller editor for not interfering regular preview-then-close-by-ctrl-g flow.
    - Thus though it don't close `narrow-editor`, it behave like closed by `ctrl-g`.
- Experiment: Use octicon icon for itemIndicator in `narrow-editor`.
- Internal: Add Ui event when working on #106
  - Introduce `Ui::onDidStopRefreshing` which is fired 100ms delayed after `onDidRefresh`.
  - Introduce `Ui::onDidPreview`
  - Introduce `Ui::onDidChangeSelectedItem`

# 0.19.0:
- New: Exclude particular file item from result for non-boundToEditor provider.
  - This is nothing to do with provider's behavior, just filter out result in narrow-editor(ui).
    - `narrow-ui:exclude-file`: `backspace`, Exclude currently selected file from result.(no effect in boundToEditor provider)
    - `narrow-ui:clear-excluded-files`: `ctrl-backspace`, Clear exclude-file list. and refresh
- New: Move to next/previous file's item(no effect in boundToEditor provider)
  - `narrow-ui:move-to-next-file-item`: `n`, Move to first-item of next-file.
  - `narrow-ui:move-to-previous-file-item`: `p` Move to last-item of previous-file.

- Use case
  - Start `narrow:search`, then enter `read-only` mode
  - `backspace` to exclude currently selected file's item from result.
  - `ctrl-backspace` to clear and refresh excluded file list.
  - `n` to move to first-item of next file
  - `p` to move to last-item of previous file

- Improve: No longer close `narrow-editor` on confirm if protected by `narrow-ui:protect`.
- Doc: FAQ Section in README
- Fix: [Critical]. No longer modify cursor position after confirmed
  - It's interfere precise closest position when auto-sync.
  - Also because of this bug, item's point was just ignored in all providers.

# 0.18.0:
- New: #97 `narrow-ui:protect`( no keymap by default ) to protect `narrow-editor` from being closed by `narrow:close`( `ctrl-g` ).
  - E.g. If you want keep opened `narrow:symbols` for long use, then you don't want close this `narrow-editor` by `ctrl-g`.
  - In this case, invoke `narrow-ui:protect` on that `narrow-editor`, after that `ctrl-g` don't close this `narrow-editor`.
- Improve: #98 Prevent side scroll of `narrow-editor` while auto-syncing to active-editor.
  - Particularly useful when `narrow:symbols` or `narrow:fold` is used as long-use with keep opened(by `narrow-ui:protect`ed ).

# 0.17.0: read-only mode for non-vim-mode-plus user, performant auto-preview
- New, Breaking: #88, #62 read-only item area as like vim for non-vim-mode-plus user
  - If you don't like, you can change `autoShiftReadOnlyOnMoveToItemArea`.
  - In `read-only` mode
    - `j`, `k` to move-up/down in item-area.
    - `i` or `a` to start insert on query-prompt etc.
- New `autoShiftReadOnlyOnMoveToItemArea` setting( default `true` )
  - If this set to `true`, When cursor move to item area in `narrow-editor`, automatically set editor to `read-only` mode.
  - This setting affects both vim-mode-plus and non-vim-mode-plus user.
- Breaking: Key map tweaking, update README to reflect new keymap.
  - `tab` is no longer mapped to `narrow-ui:move-to-prompt-or-selected-item`( maybe I will deprecate it in future ).
- Breaking: `narrow-ui:refresh-force` command since its duplicating globally available `narrow:refresh`.
- Improve: New `narrow:focus` never fail to focus to ui in workspace #84.
  - So you can close all `narrow-editor` one by one by repeating `ctrl-g`.
- Improve: #91 Now auto preview don't change focused item and cursor position unnecessarily.
  - As a result, auto-preview get light faster.
- Improve: Auto preview at initial invocation when initial query input was provided( `-by-current-word` situation).
  - Tweak `tab`( `preview-next-item` ) behavior in query-prompt.
    - Don't skip first item on first time `tab` if it's not yet auto-previewed.
- Improve: Cleanup, avoid unnecessary auto refresh when auto-syncing editor.

# 0.16.0:
- Improve: Usability of direc-edit( `update-real-file` ). #87
  - If you keymap `cmd-s`( if you are macOS user ), then you can apply changes in `narrow-editor` by `cmd-s`.
  - Overwrite, TextBuffer's `isModified` function to update modified icon on tab(provided by core `tabs` package).
  - confirm user before `update-real-file` actually start updating.
    - New config option `confirmOnUpdateRealFile`( default `true` ).
    - If this set to `false`, no longer ask before `update-real-file`, danger!
- Fix: When `update-real-file` on `search` result and filePath include unsaved modification, result in unwanted update. #85
  - Since `search` use `ag` which search match from saved file on disk
  - In this situation, now cancel update by warning user.
- Doc: Update my keymaps on README.

# 0.15.0: BIG: auto-sync/refresh for all providers, auto-refresh item on each focus change.
- New: Now all providers sync to current active editor. #81
  - In previous release only boundToEditor provider(e.g. `lines`, `fold` etc) support sync.
  - Now all provider support sync(e.g. `search`, `atom-scan`)
  - What is sync?
    - update current item indicator by cursor move on active-text editor
    - So keep you inform where you are among items.
    - Also auto refresh items when bounded editor content is updated, in following timing.
      - `onDidStopChanging` for `boundToEditor` provider(e.g. `line`).
      - `onDidSave` for non `boundToEditor` provider(e.g. `search`).
- New: Auto rebind to editor for boundToEditor provider #82
  - e.g. `narrow:fold` auto refresh fold items on each focus change
    - Each time you change focus to different text-editor, fold items are refreshed
    - So you can use this fold list as table-of-content of currently focused file
- Internal: Further decoupled/eliminate state depending code from boundToEditor/syncToEditor logic #82, #81
  - To support re-bind editor/sync for `search`, `atom-scan`
- Improve: Show gutter for provider which indent is not empty. #83.
- Doc: Put link to [Use case and flow of keystrokes](https://github.com/t9md/atom-narrow/issues/75) in README.

# 0.14.1:
- Improve: Delay `autoPreviewOnQueryChange` timing to `onDidStopChanging` for non boundToEditor provider
  - E.g. `search`, `atom-scan`
  - Was so heavy that it interfere query keystroke.
# 0.14.0: Improved UX especially for vim-mode-plus(Need vim-mode-plus v0.82.0 or later).
- New: #79 Preview without moving cursor from query-prompt. no keymap for non-vim-mode-plus user.
  - `narrow-ui:preview-next-item`
  - `narrow-ui:preview-previous-item`
- New: wrap items on next/previous select(from top-to-bottom, bottom-to-top). #72
  - From outside of narrow-editor, `next-item`, `previous-item` now wrap.
  - In narrow-editor, moving up/down now wrap for both vim-mode-plus and normal user.
    - For vim-mode-plus user, it's depend on latest(v0.82.0) vim-mode-plus command.
- New: Auto previewing as you type #76
  - Automatically preview first item in item-list as you type query.
  - New: `autoPreviewOnQueryChange` per provider config. default `true` in all provider.
- Improve: #74 closing narrow-editor after preview now restore cursor/scroll-top/fold.
- Improve: Keymap in narrow-editor for vim-mode-plus user.
  - `k`: `vim-mode-plus:move-up-wrap`(require vmp v0.82.0 or later).
  - `j`: `vim-mode-plus:move-down-wrap`(require vmp v0.82.0 or later).
  - `tab`: `preview-next-item`: Preview without moving cursor from query-prompt.
  - `shift-tab`: `preview-previous-item`: Preview without moving cursor from query-prompt.
- Breaking: Per provider config is scoped to each provider, sorry for no auto-migration!!.
  - For easier maintenance(to avoid mess) and for collapsible UI in setting-view.
  - Here are example of how config name was changed.
    - `LinesAutoPreview` -> `Lines.autoPreview`
    - `LinesCloseOnConfirm` -> `Lines.closeOnConfirm`
    - `SearchAutoPreview` -> `Search.autoPreview`
    - `SearchAgCommandArgs` -> `Search.agCommandArgs`
- Fix: `next-item`, `previous-item` now always confirm item even if single item.

# 0.13.0:
- New keymap: For vim-mode-plus user(need vim-mode-plus v0.81.0 or later).
  - `tab`, `shift-tab` to move to next/previous item from outside of narrow-editor
  - These keymaps are only activated at least one narrow-editor exists on workspace.
- New command:
  - `narrow:focus-prompt`: focus prompt of narrow-editor from outside/inside of narrow-editor.
    - If cursor is already at prompt of narrow-editor, it focus back to original editor.
  - `narrow:refresh`: Manually refresh items from inside/outside of narrow-editor.
    - Intended to be used for non-editor-bounded provider such as `search`, `atom-scan`.

- Improve, Breaking: Simplify vim-mode-plus integration.
  - Following two configurations are removed. Why? Get default behavior right, so no longer need these option.
  - `vmpAutoChangeModeInUI`
  - `vmpStartInInsertModeForUI`
- Fix: No longer throw error when non-boundToEditor provider(e.g. search) destroy original editor and click item.
- Internal: Lots of conceptual cleanup and reflect it to code, logic, fix lot of potential bug(I believe so).

# 0.12.1:
- Released for README.update after 3 min of 0.12.0 release. no behavioral change.

# 0.12.0:
- New: `*`(wildcard) and `!` negate expression support for query. See #64 for detail.
- New: setting to control `close-on-confirm` behavior. Params and default values are below.
  - `AtomScanCloseOnConfirm`: true
  - `BookmarksCloseOnConfirm`: true
  - `FoldCloseOnConfirm`: true
  - `GitDiffCloseOnConfirm`: true
  - `LinesCloseOnConfirm`: true
  - `LinterCloseOnConfirm`: true
  - `SearchCloseOnConfirm`: true
  - `SymbolsCloseOnConfirm`: true
- New: new provider `narrow:linter` which use linter packages message as information source.
  - Support `direct-edit`
- Improve: improve usability for `vim-mode-plus` user.
  - `vmpAutoChangeModeInUI` set to default `false`(was `true` in v0.11.0)
  - Revival `vmpStartInInsertModeForUI` settings (was removed in v0.11.0)
  - `i`, `a` in narrow-editor mapped to new `vim-mode-plus-user:narrow-ui:move-to-prompt`.
  - Which move to prompt and start insert-mode if not.
- Improve: No longer syncToProviderEditor for editor-bound-provider while cursor move caused by preview.

# 0.11.0: Really BIG release.

- New: direct-edit support #45, #43.
  - After you edit narrow-editor items then invoked `narrow-ui:update-real-file`.
  - Which apply changes to real file and auto-save.
  - Read instruction on README.md.
  - `direct-edit` supported providers are `lines`, `search`, `atom-scan`.
- New: `atom-scan` provider, similar to `search`.
  - `atom-scan` use `atom.workspace.scan` so no external command is required.
- New: narrow-editor have `narrow-editor` CSS class
- Improve: Add quick-tour on README.md.
- Improve: Set many default-keymap.
- Breaking: Rename commands name
  - Rename: `narrow-ui:refresh-force` to `narrow-ui:refresh-force` and add new `ctrl-l` keymap
  - Rename: `narrow-ui:move-to-query-or-current-item` to `narrow-ui:move-to-prompt-or-selected-item`
  - Rename: `vim-mode-plus-user:narrow-lines-from-search` to `vim-mode-plus-user:narrow:lines`
  - Rename: `vim-mode-plus-user:narrow-search` to `vim-mode-plus-user:narrow:search`
  - Rename: `vim-mode-plus-user:narrow-search-current-project` to `vim-mode-plus-user:narrow:search-current-project`
  - New: `vim-mode-plus-user:narrow:atom-scan`
- Breaking: No longer `ctr-r` mapped in `vim-mode-plus.normal-mode` to avoid conflict to `vim-mode-plus:redo`.
- Breaking: Configuration parameters
  - Simplify auto preview config name remove `Default` part from name.
    - `LinesDefaultAutoPreview` to `LinesAutoPreview`
    - `FoldDefaultAutoPreview` to `FoldAutoPreview`
    - `SearchDefaultAutoPreview` to `SearchAutoPreview`
    - `SymbolsDefaultAutoPreview` to `SymbolAutoPreview`
    - `GitDiffDefaultAutoPreview` to `GitDiffAutoPreview`
    - `BookmarksDefaultAutoPreview` to `BookmarksAutoPreview`
  - For `directionOpen` pram, `here` is no longer supported.
    - Old allowed value: [`right`, `down`, `here`]
    - New allowed value: [`right`, `down`]
  - `vmpStartInInsertModeForUI` is removed
  - `vmpAutoChangeModeInUI` is added
- Change: `search` no longer show column on each items. #47
- Improve: Respect word boundary(`\b`) for both grammar and search args for `search`, `atom-scan`.
- Improve: `lines` now place cursor on query matching position by best effort.
- Improve: Prevent green row marker remains by updating atomically.
- Improve: Add spaces for line-header, All line-header showing provider now show aligned line-header.
- Improve: Item cache is handled by ui and controlled by `supportCacheItems` prop on provider.
- Improve: Item area refresh is not skipped on `undo` and `redo`, so only queries are undo managed.

# 0.10.1:
- Eval: tryout to fix `ag` search not work on windows #9.

# 0.10.0: Still experimenting!!
- New: `narrow:close` command.(no keymap by default)
- New: `narrow-ui:move-to-query-or-current-item` command, available in `narrow-editor`(=`ui`).
  - `tab` is mapped. Use `tab` key to move between prompt line and current selected item quickly.
  - This mitigate frustration of autoSync to cursor position for boundToEditor providers.
- New: Custom command args for `ag` for `narrow:search` provider. #42.
- Fix: `narrow:search` placed cursor one column right in previous release, but no longer.
- Improve: skip auto-updating-cursor-position of narrowEditor when cursor is at prompt row.
- New: `caseSensitivityForNarrowQuery` config options #44.
  - `smartcase` is default
  - Providers global/not per-provider basis.
  - `smartcase`-tivity is handled query per-word(separated by white-space).
  - Eg. For query "hello World": hello=case-insensitive, World=case-sensitive.
- Fix: Provider.Fold `increase-fold-level`, `decrease-fold-level` didn't worked(I believe) by regression in v0.9.0.

# 0.9.0: Still experimenting!!
- New: Auto sync selected items on narrowUI with bounded editor's cursor position.
  - Enabled on following providers
    - `Fold`, `GitDiff`, `Lines`, `Symbols`
- New: `narrow:next-item`, `narrow:preview-item` to move to next item without focusing narrowEditor(UI).
- Improve: GitDiff provider auto-refresh items on bound-editor's change.
- Improve: Currectly track last focused UI for `narrow:focus`.
- Improve: Clear row-marker when focus lost from narrowEditor.
- Breaking: Command rename `narrow-ui:open-without-close` to `narrow-ui:confirm-keep-open`.
- Breaking: Default keymap on vim-mode-plus's search-form was change.
- Breaking: `Symbols` provider no longer display line number.

# 0.8.0: Still experimenting!!
- New: `narrow:fold` buffer's keymaps `cmd-[`, `cmd-]` to change foldLevel to filter items.
- Update style
- New: `narrow:symbols`
- New: `narrow:git-diff`
- New: `narrow:bookmarks`

# 0.7.1:
- Fix: prep for `::shadow` boundary removal
- Fix: When `directionToOpen` was `here` autoPreview throw error, to fix this when `here`, disable autoPreview #12.
- New: `by-current-word` suffixed version of commands for each provider #15, #6.
- Improve: Change style for narrow's line-highlight to underline to avoid covering existing highlight #14.

# 0.7.0:
- New: Config option to control default `autoPreview` of each provider. And the default is `true` for all provider #18.
- Breaking: Remove fuzzy search feature. Since it was confusing.
- Fix: When `narrow:line`, window closed by `q` it throw error.

# 0.5.2:
- Fix: correctly set selected position on center of screen on `core:confirm`.

# 0.5.1:
- Fix: No longer throw error when original Pane is destroyed before narrow-ui is closed. #1.

# 0.5.0:
- Fix: Several bugs.
- New: `narrow:search-current-project` and default `cmd-shift-o` for vim-mode-plus user.
- New: Better vim-mode-plus integration when enter `insert-mode` in narrow-ui, it move cursor to row 0.

# 0.4.0:
- Fix: Search duplicates file headers.
- Improve: Skip header item when cursor move up and down.
- Improve: Better integration with vim-mode-plus `vmpStartInInsertModeForUI` control initial vim's mode.
- New: Support fuzzy search for Lines and Fold.

# 0.3.1:
- Improve: cursor position centering

# 0.3.0:
- Fix: `narrow:focus`, just because forgotten to rename from old to new name.
- Improve: grammar highlight
- Improve: `narrow:search` header is indented so that foldable.
- Improve: `narrow:search` hide header for filtered outed item.
- Improve: ui select first valid item at startup.

# 0.2.5: [not released]
- experimented blockDecoration to display file, project header in `narrow:search`.
  but decided not to use because of ux.

# 0.2.0:
- UI inproved.
- `narrow:line` and `narrow:fold` have `autoPreview` enabled on start.
- Special integration with `vim-mode-plus`.

# 0.1.1:
- cleanup

# 0.1.0:
- Initial release
