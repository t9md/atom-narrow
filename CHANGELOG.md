# 0.41.1:
- Fix: #204 mouse `click` on useRegex button now work properly.
- Improve: Clicking `mini-editor` container for search input no longer close `min-editor`.

# 0.41.0:
- New: #194 Support regular expression search for provider `search` and `atom-scan`.
  - New config
    - `useRegex`: ( default `false` ), initial regexp search state.
    - `rememberUseRegex`: ( default `false` ), if enabled last regexp search state is remembered.
  - Internal: `--nomultiline` flag for `ag` to make it line based search
  - Special note for syntax highlight on `narrow-editor`.
    - Automatically fallback to fixed string search if searchTerm didn't include regexp special char.
      - For better performance and syntax highlight on `narrow-editor`.
    - Currently atom doesn't allowing text color( foreground color ) by decoration.
    - So when regexp search was done, it use normal background decoration to highlight searchTerm on `narrow-editor`.
    - Because translating Js's regexp to grammar's regex( Oniguruma ) is tough for me.
    - This limitation will be fixed once atom support text color change via decoration.
- Fix: `narrow:close` on protected `narrow-editor` now properly re-render control-bar.
- Improve: #189, #202 When `narrow-editor` open, place cursor on original search word.
  - e.g.
    - 1. Your cursor is at `|` in `wor|d`.
    - 2. Invoke `narrow:search-by-current-word`
    - 3.
      - Now: Cursor on `narrow-editor` is at `wor|d` at selected-item.
      - Before: Cursor was at first column of selected-item.
- Improve: Delay refresh on query-change event so that frequent refresh not disturb next query-input.
- Improve: #200 `narrow:scan` get faster by using manual regexmatch instead of using `editor.scan`.
- Improve: Tweak highlight not cover text such as base16-tomorrow-dark-theme syntax
- Improve: Keep column( `goalColumn` ) when header row was skipped for both core and vmp commands.
  - `core:move-up`, `core:move-down`,
  - `vim-mode-plus:move-up-wrap`, `vim-mode-plus:move-down-wrap`
- Improve: #193 For atom v1.17.0 and later, no longer activate preview target pane on preview.
  - Add note on README.md.
  - For atom v1.16.0 and former user who use narrow with vim-mode-plus.
    - You need to disable `vim-mode-plus.automaticallyEscapeInsertModeOnActivePaneItemChange`.

# 0.40.1:
- Fix, Critical: #185 In `PHP`, `ShellScript` file, `search-by-current-word` on `$var` fail to find `$var`.
  - More specific explanation: For the language where `selection.selectWord()` select non word char.
  - When `search-by-current-word` was executed with empty selection
    - Pick current-word then search by `ag` or `rg`
      - Before: With `--word-regexp` option and it never matched `$` char.
      - After: Without `--word-regexp`, always searched with regex build by narrow.

# 0.40.0:
- Improve: Now pkg is activated on-demand, via `activationCommands` to reduce statup time.

# 0.39.1:
- Fix: In Atom-beta( v1.17.0-beta-0 ), auto-preview lose focus from `narrow-editor`.

# 0.39.0:
- Cosmetic, Config: Provider specific configs are default collapsed in `settings-view`.
- Improve: `search` and `atom-scan` provider config no longer show `on-input` choice for `revealOnStartCondition`.
  - Since it's have no effect( `search` and `atom-scan` have always no-input, never met condition of `on-input` )
- New, Experimental: #177 New config param `focusOnStartCondition` to control whether initially focus to `narrow-editor` or not.
  - Possible values are
    - `always`( default ): always focus to `narrow-editor` on start.
    - `never`: never focus to `narrow-editor` on start.
    - `no-input`: focus when initial query was empty( this choice is not available for `search`, `atom-scan` )

# 0.38.2:
- Fix: `narrow:search` with searcher `rg`, `smartcase` didn't work correctly.
  - Because of ignorance of default behavior diff between `ag` and `rg`.
- Fix: `narrow:search` with searcher `rg` now correctly refresh item list when files are modified.
  - On manual-refresh and on auto-refresh on save buffer, it cleared all items belonging to that modified file.
  - This bug is also because of ignorance of default behavior diff between `ag` and `rg`, now fixed.

# 0.38.1:
- Fix: `smartcase` handling for query is inverted in v0.38.0, now works properly again.

# 0.38.0:
- New: #174 New query expression. `|` is treated as `OR`.
  - `aaa|bbb` matches item which include `aaa` OR `bbb`.
  - See wiki for detail https://github.com/t9md/atom-narrow/wiki/Query.
- Fix: Now `narrow:search` can correctly search `/` including pattern like `/a/b/c` when searcher is set to `rg`.
  - This is `rg` only issue. `rg` not allowing `/` to be escaped like `\/`.
  - To fix this, now `search` use `--fixed-strings` option for both `ag` and `rg`(was searched as regex with escape regex-meta-char in previous release).

# 0.37.1:
- Fix: Long standing bug, where editor content get blanked on pane-split immediately after `narrow:close`.
  - See detailed https://github.com/t9md/atom-narrow/issues/95
# 0.37.0:
- New: #170 New query expression `>` and `<` for word-boundary matching.
  - Query `>word<` is translated to `\bword\b`.
  - Handled by each query.
  - See wiki for detail https://github.com/t9md/atom-narrow/wiki/Query.
- Improve: `narrow:symbols-by-current-word` and `narrow:project-symbols-by-current-word` auto qualify initial query with word-boundary.
  - To make quick-previewing function by these command more useful.
  - When you invoked these command from on `word`, initial query become `>word<`.
  - This prevent unwanted matching where there are other symbols including `word` as part of symbols string.
    - Previous release: `refresh` matched also symbols `refreshManually` or `autoRefresh` symbols.
    - This release: `>refresh<` not match symbols `refreshManually` or `autoRefresh`, ideal when `by-current-word` invocation.
- Fix: #168 Prevent temporal active pane change on auto-previewing on query-change.
  - In previous release, keystroke get passed to temporally activated editor which result in unwanted mutation.
  - This was especially likely to happen on `!` negation blank out narrow-editor items and open preview item on next query char.

# 0.36.0:
- New: new config option for remember ignoreCase options for `search` and `atom-scan`.
  - Following two config options are introduced to control `by-current-word` or not respectively.
    - `rememberIgnoreCaseForByHandSearch`: default `false`
    - `rememberIgnoreCaseForByCurrentWordSearch`: default `false`
  - When set to `true`, restore `ignoreCase` option for last execution.
    - So `caseSensitivityForSearchTerm` is no longer respected except very first execution.
- Fix: Redraw control-bar if on-prompt-selection-destroyed.
- Improve: Auto disable wholeWord search for `scan-by-current-word` for non single length non-word-char.

# 0.35.0:
- Fix: No longer throw error when empty search term was confirmed in `search` or `atmo-scan`.
  - Internally no longer `reject` promise in `ProviderBase::start`.
- Fix: No longer throw `Maximum call stack size exceed` exception when num of items collected by `search` and `atom-scan` was too big.
- Breaking: Remove experimental `Search.agCommandArgs` config.
  - Custom command args for `ag` search is no longer supported.
  - Removal is because this was just experiment while spec of narrow was not fixed yet.
  - I will consider this to revival if user really report necessity of this.
- Improve, New: Support `rg`( ripgrep ) for `search` provider
  - default `searcher` config is `ag`, choose `rg` to use `ripgrep`
  - Performance improved?
    - No. Although `rg` is generally faster than `ag`, no significant diff in usage of `narrow`.
    - Most of time consumed in `narrow` is spent in view-side( rendering in `narrow-editor`, header insertion to each item collected )
    - So in my opinion both `ag` and `rg` is fast enough for the purpose of `narrow`.
    - If you feel default `ag` serch is very slow, it must be slow of `narrow` itself(e.g. JavaScript and Atom).
- Internal: Automatic deprecation warning, removal of obsolete config parameter for provider config.
  - Warning, removal for obsolete config is provided for global( non-provider-config ) config only in previous release.

# 0.34.0:
- Improve: When `scan-by-current-word` invoked from on single-length-non-word-char, auto disable boundary( `\b` ) search.

# 0.33.0:
- New `select-files` provider specific `rememberQuery` config.
  - Default `false`.
  - When set to `true`, remember query **per provider basis** and apply it at startup.
- Improve: folder-icon on `control-bar` is green highlighted to indicate some files are excluded.
  - This is indicating files are **actually** excluded( filtered ).
  - **Not** indicating remembered `select-files` query is applied.
    - e.g. Applying remembered `.md!` query to non-markdown-file-items have no effect, no highlight.
- Improve: `narrow:reopen` restore excluded-files state and query used for `select-files`.

# 0.32.1:
- Fix: wildcard was not expanded correctly when query words include single char query.
- Doc: Add link to wiki on README.md.
- Internal: Now `ProviderBase::start` always return promise.
- Test: Add test for `select-files` provider.

# 0.32.0:
- Spec: Add basic level test for `search`.
- Breaking, Improve(?): Now `search` items are sorted by filePath.
- Internal: Consolidate `onDidStopChangingActiveItem` event observation.
- Improve: Current match highlight is done without **delay** for boundToSingleFile provider( e.g. `scan` ).
- New: Interactively select/exclude file to narrow by `select-files` meta provider.
  - SelectFiles provider is invoked from `narrow-ui`( `narrow-editor` ).
  - `cmd-backspace` is mapped by default.
  - Add short tutorial in `README.md`'s "Use `select-files` provider" section.
- New: `negateNarrowQueryByEndingExclamation` config option.
  - default `true` for `select-files` provider, `false` for other provider.
  - Narrow query support `!word`, expression to "exclude `word` matching item"(from older version).
  - When this option set to `true`, `word!` is also treated to exclude `word` matching item.

# 0.31.1:
- Fix: No longer throw exception on change active pane item while reading search input.

# 0.31.0:
- New: commands `narrow:reopen` ( no default keymap )
  - Reopen closed narrow editor up to 10 recent closed.
  - Items are re-collected( yes, just re-starting narrow with same `query` and other properties ).

# 0.30.0:
- Improve: Add basic test spec.
  - Add `Ui::onDidDestroy` to test easily.
- New: Support search input history in mini-input-editor.
  - Used for `search` and `atom-scan`
  - Keep max 100 recent search history.
  - `search-by-current-word`, `atom-scan-by-current-word` also saved to history.
  - Simplify `Input` class( used to read input ), no longer use custom element.
  - When focus changed to different app, keep mini-editor open( was closed in previous version ).

# 0.29.1:
- Bug: Fix `search` searches first project only even in multi-project search.
  - This is degradation introduced in v0.29.0.

# 0.29.0:
- Improve: #153 Per file refresh support for `search` and `atom-scan`
  - Old behavior: whole project was re-searched `onDidSave`.
  - New behavior: search only saved file is re-searched `onDidSave`.
    - When saved file have no existing items, items are appended to end of `narrow-editor`.
- Improve: Avoid re-search `onDidSave` for file which is not belonging to any project.
- Internal: Inserting/removing project/file header is done by UI( previously done by provider )
- Doc: #154 Add gitter link on README.

# 0.28.0:
- Breaking: #146 Remove `narrow:lines` in favor of `narrow:scan`
  - Asking you to use `narrow:scan`, it's better than old `narrow:lines`
- Improve: #151 `narrow:symbols` indent `text.md` syntax-ed markdown header. PR by @thancock20
- New: #129 Use selected text as initialQuery or initialSearchTerm generally.
  - For `search` and `atom-scan`, when invoked with selected text, use it as search term.
  - For other providers, use selected text as initial query.
  - What was changed?
    - Old behavior: `narrow:scan` can not use selected text. User have to use `narrow:scan-by-current-word`.
    - New behavior: `narrow:scan` can use selected text.
- Internal: Lots of cleanup.

# 0.27.0:
- New: `project-symbols` provider, following commands are available
  - `narrow:project-symbols`:
  - `narrow:project-symbols-by-current-word`:
- New: #145 [Experimental] Per provider config for existing `directionToOpen` with new values.
  - Each provider can override global `directionToOpen` setting.
  - Possible value and short descriptions are here.
    - `inherit`: pick global setting.
    - `right`: default, no behavior change
    - `right:never-use-previous-adjacent-pane`: don't use previous adjacent pane( only use next-adjacent )
    - `right:always-new-pane`:
    - `down`:
    - `down:never-use-previous-adjacent-pane`:
    - `down:always-new-pane`:
- New: #147 [Experimental] Provider specific `caseSensitivityForNarrowQuery`
- Improve, Breaking: #147, symbols no longer use line text, use tag name instead for better match.
  - Basically indented by line indent, special indentation handling for markdown header.
- Internal: Introduce `globalSubscriptions` to dispose long-lived subscriptions
  - Currently, used for watching tags file change for `project-symbols` provider.
- Internal: #144 Extract item concern( selecting, finding ) to `Items` class

# 0.26.1:
- Fix, Critical: Duplicate ui command registration.

# 0.26.0: Reveal on closest item on start! Now more helm-swoop-ish.
- New: Reveal closest item on start
  - New config param `revealOnStartCondition` control this behavior.
  - Value can be
    - `never`: never reveal( previous version's behavior )
    - `always`: always try to reveal
    - `on-input`: only when initial input query was provided via `-by-current-word` commands.
  - Each provider have different default value( opinionated ). So no global default.
    - Basic strategy to choose default value is here.
      - boundToSingleFile( `scan`, `fold`, `symbols` ) provider have `on-input` default
      - Other have `always` default( `search`, `atom-scan`, `git-diff-all` ).
  - If you want previous version's behavior back, set `never` to each.
- New: Rebind all text-editor except narrow-editor #140
  - This is big design change.
  - Now can `next-item`, `previous-item` for each active editor on every provider.
    - In previous release, `next-item`, `previous-item` is tied to bound editor.
    - So regardless os active-text-editor, these commands move cursor of narrow-invoking-editor.
- Fix: Editor's scroll-top was not restored correctly on cancel.
- Cosmetic: Change config order to less important providers come last.
- Doc: Update keymap example
- Improve: Avoid unnecessary refresh on re-bind to editor which have same filePath.
- Internal: #139 Rename `boundToEditor` provider property to `boundToSingleFile` since now every provider have editor bound

# 0.25.0:
- New: [Experimental] #136, #135 double click start `narrow:search`
  - When new `Search.startByDoubleClick` config set to `true`( default `false` )
  - Mouse double click start `narrow:search-by-current-word`.
  - `narrow-editor` for `search` is opened with pending state.
  - You can continue click and search without messing lots of `narrow-editor`.
  - command `narrow:toggle-search-start-by-double-click` toggle `Search.startByDoubleClick` value
- Fix, Critical: #137 When mini-editor for `search` `atom-scan` closed by canceled, `workspace.has-narrow` scope (css class) remain unnecessary.
  - Because UI instance was registered BEFORE reading input from mini-editor.
  - From this version UI instantiation is delayed until it really get prepared.
- Improve: `search`, `atom-scan` now can detect new match at `onDidSave` for every editor.
  - In previous release, the save event on editor which have no item was just ignored.
- Improve: keep originally selectedItem on manual refresh.
- Internal: Allow `narrow-editor` open in pending state, activate providerPane if activate set false( default = true )

# 0.24.0:
- Doc: Update keymap example in README
- Doc: #132 Fix link for `keymap.cson` pointed to stale branch.
- Improve: Auto preview on focus narrow-editor.
- Improve: #130 No longer restore editor state( cursor, scroll-top ), if non-narrow-editor was clicked.
  - In previous release, clicking non-narrow-editor is not treated as confirmation, so cursor had been restored after `narrow:close`.
- Improve: #134 highlight improve
  - Flash current match on `next-item`, `previous-item`
  - Limit emphasizing current match only in previewing.
  - Internal: All highlight related logic was moved to `highlighter.coffee` from `ui.coffee`

# 0.23.0:
- Fix: #123, Prevent mouse event propagation for provider-panel
  - When search-option button on provider-panel was clicked, no longer move cursor of `narrow-editor`.
  - `provider-panel` is embedded as narrow-editor's block-decoration, so need to explicitly suppress event propagation.
- Fix: Set unique title for each `narrow-editor`. So tab title no longer become `undefined`( title must not conflict within pane ).
- New: #121, New provider `git-diff-all`.
  - Show git diff items across projects( Existing `git-diff` shows diff for current file only )
- Improve: #119, #124 Usability/usefulness improve for `next-item` and `previous-item`.
  - These command is to move cursor to next/previous item without focusing `narrow-editor`
  - Mapped to `tab`, `shift-tab` for `vim-mode-plus` user, `ctrl-cmd-n`, `ctrl-cmd-p` for normal user.
  - What was changed?:
    - Land to `current-item` when `next-item` and `narrow-editor`'s current-item is forwarding to active-editor's cursor.
    - Land to `current-item` When `previous-item` and `narrow-editor`'s current-item is backwarding to active-editor's cursor.
    - In previous version, simply landed chose next/previous item's position regardless of active-editor's position.
    - So sometimes, user need `tab`, `shift-tab` to go/back to adjust exceeded movement.
- New: #128 Relaxed whole-word search.
  - What's benefit?: Now can search `@editor\b` by search `@editor` with `whole-word` enabled.
  - In previous release, when `whole-word` was enabled, search simply `\beditor\b`( `editor` is searching word here).
  - So when user search `@editor`, searched wth pattern `\b@editor\b`( never match ).
  - From this release, `word-boundary`(`b`) is **automatically relaxed as long as start or end can match with boundary**
  - Example
    - `editor`, -> `\beditor\b` ( start and end is word-char).
    - `@editor`, -> `@editor\b` ( relaxed start boundary ).
    - `editor!`, -> `\beditor!` ( relaxed end boundary ).
    - `@editor!`, -> `\b@editor!\b` ( No relax, relaxing both boundary means no-whole-word, contradict to user's intention ).
- New: Command `symbols-by-current-word`, since it sometime useful to quickly preview function definition under cursor.
- New: #126 New button in provider-panel( see README GIF to quick overview ).
  - Auto preview: click eye icon to toggle-auto-preview.
  - Protect: click lock icon to toggle protect narrow-editor( protected narrow-editor is no longer closedb by `ctrl-g` or confirm by `enter` ).
  - Refresh: clicking it manually refresh item. Also when search options was changed, it indicate search is running by changing icon to `X` icon.
- Internal, Performance: Use faster `DisplayMarkerLayer.clear()`
- Internal: #122 Consolidate file/project header injection/filter-out logic( was done in per provider, but now done by base-provider).

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
- Fix: `Point` is not imported on `utils.coffee`. rarely evaluated code path, I can't describe what situation cause error by this bug.

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
