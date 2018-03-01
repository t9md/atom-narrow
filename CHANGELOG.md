# 0.64.0:
- Rename: Rename command name. Need update your `keymap.cson`, Warn deprecated when old command was used.
  - Old: `narrow-ui:switch-ui-location`
  - New: `narrow-ui:relocate`
- New: `relocateUiByTabBarDoubleClick` config
  - Default `true`
  - When you clicked tab-bar for ui, clicked ui is relocated(same effect as you invoke `narrow-ui:relocate`)
- Fix: No longer throw exception when searchOptions change commands invoked from provider which doesn't have one(e.g. `symbols`, `fold`).
  - So calling these commands from non-search provider is safe now.
    - `toggle-search-whole-word`, `toggle-search-ignore-case`, `toggle-search-use-regex`

# 0.63.0:
- Improve: Refine startup preview timing to avoid multiple preview call which is unnecessary. #286
- Breaking: Simplify how `getItems` should be implemented. #287
  - Now removed requirement to call `Provider.prototype.finishUpdateItems` within `getItems`.
  - Instead just return array of items, it's the message to finish item update.

# 0.62.1:
- Improve: suppress cursor flash on `narrow-ui:switch-ui-location` when cursor is at query-prompt.

# 0.62.0:
- Improve: atom-scan now direct-editable again #284, #285
  - From `v0.48.0`, `narrow:update-real-file` was disabled for safety(avoid dangerous/immature mutation happening).
  - Now: By normalizing `atom-scan`'s item to well fit to direct-edit feature which does whole-line by line replace.

# 0.61.0: Dock-able narrow-editor
- New, Breaking: `narrow-editor` can open in dock #283
  - First: If you immediately revert to previous behavior, set global `locationToOpen` to `center`, that's it!!
  - What's this?
    - In previous version `narrow-editor`(=ui) is openable only in center workspace's pane.
    - From this version `narrow-editor` is openable in both `center` workspace and `bottom` dock.
    - Technically it's openable in other dock like `right`, `left` but I want start it from `bottom` only.
  - User can move `narrow-editor` in between `center` and `bottom` by
    - drag&drop
    - Clicking provider name at controlBar(e.g. click `scan` on controlBar).
    - Or invoking `narrow-ui:switch-ui-location`(no default keymap) command.
  - New: `locationToOpen` global and per-provider config which define default location(`center` or `bottom`).
    - This value is referred at very first invocation of narrow after atom launch.
    - Following narrow invocation open ui at last opened location.
    - Last location is kept per provider basis, not shared across providers.
- Other improvement:
  - Now flash cursor row if items count is greater than 2.(was 5 before but it was a bit strange threshold).
  - Centering `narrow-editor`'s cursor row on startup to reduce chance for getting lost.
  - No longer unnecessary restore editor state when `focusOnStartCondition` was `never` and cursor moved at narrow initiator editor after launch.
  - Flash current row regardless of `focus` to `narrow-editor` on startup(flashed only on `focused` in previous version).

# 0.60.3:
- Fix: just fix release number bug in CHANGELOG.md.

# 0.60.2:
- Fix: When `narrow:scan` start without any input, don't preview first row item #281
  - This is regression introduced in v0.60.0.
  - Plus: No longer start auto-preview when prompt query was clicked.

# 0.60.1:
- Fix: RegExp search for `search`, `atom-scan`, `scan` didn't work because of regression.
  - After v0.57.0.
- Style: Modify match color and line-marker color.

# 0.60.0:
- Fix: When non-narrow-editor was active, first click on narrow-editor didn't start auto-preview item, but no longer.
- New: Config `drawItemAtUpperMiddleOnPreview` to scroll item to be displayed at upper-middle of viewport on preview.
  - Default enabled for provider `fold`, `symbols` and `project-symbols`
  - Intention? I use `symbols` by `cmd-o` shortcut to quickly refer function/method body. So my general workflow is
    1. Encounter function/method, then preview it by `cmd-o`.
    2. After reading function body close by `ctrl-g`.
  - Before this change function sometimes shown at bottom of screen which require hand scroll to read function body.
- Improve: Update `project-symbols`'s tag `kind`.
  - old: `cfm`
  - new: `cfmr`(now JavaScript's method is shown)

# 0.59.0:
- Improve, Experiment: Automatically append space at end of query on `move-to-prompt` to input next query immediately #278.

# 0.58.0:
- Fix: No longer throw exception when `core:move-up`/`core:move-down` command was executed with empty items #276
- Improve: History #277
  - Tune when history is saved for `atom-scan`, `search`, `scan` provider(added confirm timing).
  - When recall history No longer move to item when cursor is at prompt of narrow editor.
  - History feature itself is not new, was provided by default keymap which is available globally as long as workspace `has-narrow`.
    - `ctrl-cmd-[`(`narrow:previous-query-history`)
    - `ctrl-cmd-]`(`narrow:next-query-history`)
  - For user who want to recall history from narrow-editor's prompt as like normal search-tool, define following keymap in `keymap.cson`.
    - NOTE: This is vim-mode-plus user specific example
    ```coffeescript
    'atom-text-editor.narrow.narrow-editor.vim-mode-plus.insert-mode.prompt':
      # with up/down arrow key
      'up': 'narrow:previous-query-history'
      'down': 'narrow:next-query-history'

      # or ctrl-p, ctrl-n
      'ctrl-p': 'narrow:previous-query-history'
      'ctrl-n': 'narrow:next-query-history'
    ```

# 0.57.1:
- Fix: Regression where markerLayer for highlight `truncationIndicator` was not defined. #275
  - No longer throw error where narrow-editor have `[truncated]` and scroll to there.

# 0.57.0:
- Breaking, Plugin Support: Bump `narrow` service version from `1.0.0` to `2.0.0`
  - `ProviderBase` is no longer provided.
  - Use `Provider` but usage is different.
- Architecture redesign: Narrow provider use composition rather than inherit. #272
  - Each provider no longer inherit `ProviderBase`, instead it have `Provider` instance as prop and use it's functionality.
- Refactoring:
  - Extract narrow-able editor concern as `NarrowEditor` class.
  - And more and more but I'm too lazy to put detail here.

# 0.56.1:
- Fix: Regression `toggle-inline-git-diff` button didn't work.

# 0.56.0:
- Internal: Cleanup, remove lots of unnecessary indirection in code which was remains in historical reason.
- Support: Remove (I think) no longer necessary old warning of vmp specific keymap removal.
- Fix: Inaccurate item choice on `narrow:next-item`, `narrow:previous-item`
  - Which was caused by comparing point between different file.
  - Points are comparable only on same file. Now no longer does this inappropriate comparison.

# 0.55.0:
- New: `git-diff-all` provider support `inline-git-diff`. #266
  - Click new `octface` icon on controlBar to enable/disable `inline-git-diff`.
  - If not installed, manually install or answer `Yes` for auto-install suggestion on click `octface` icon timing.
- Internal:
  - Apply `standard` linter/syntax #267
  - Did some code rewriting for readability.

# 0.54.4:
- Fix: `fold` provider now collect fold only rather than collect all lines as fold in Atom-v1.24.0-beta

# 0.54.3:
- Fix: `current-project-by-current` no longer throw exception. fixed by @jonboiser thanks!
  - This is regression introduced in v0.54.2. Sorry

# 0.54.2:
- Fix: Quick workaround for narrow grammar is not set in Atom-v1.24.0-beta0.
  - Not sure why calling `pane.activateItem` revert grammar from narrow to null-grammar.
  - To workaround this, set grammar after `pane.activateItem`.

# 0.54.1:
- Fix: Remove leftover `console.log` for provider `fold`.

# 0.54.0:
- New: Provider `fold` now save foldLevel to config. by @slavaGanzin

# 0.53.2:
- Change in default: More distinguishable/color scheme safe default value for header appearance.
  - `projectHeaderTemplate`: default `[__HEADER__]`, was just `__HEADER__`
  - `fileHeaderTemplate`: default `# __HEADER__`, was just `__HEADER__`
- Fix: No longer access `vimState.modeManager`, so no loger warned.

# 0.53.1:
- Fix: Now show keymap removal notification only once.

# 0.53.0: vim-mode-plus specific default keymaps are REMOVED
- Breaking: Remove vim-mode-plus specific default keymap to avoid conflicts. #252
  - User can recover older version keymap manually, see [wiki](https://github.com/t9md/atom-narrow/wiki/ExampleKeymap#restore-vim-mode-plus-specific-default-keymap-defined-old-version).
- New: When `select-files` confirmed, move to confirmed filePath item. #254
  - So `select-files` can be used to move to specific filePath item quickly as long as filtering filePaths to show.
- Fix: When revealing on initial open, now flash selected item correctly(was broken so fixed).
- Fix: Broken `narrow:fold` from Atom-v1.22.0-beta #253

# 0.52.0:
- New: project header and file header styles are now configurable
  - Following global setting is used as template for file and project header.(`__HEADER__` is replaced with actual value).
    - `projectHeaderTemplate`: default `__HEADER__`
    - `fileHeaderTemplate`: default `__HEADER__`
  - From this release project and file header add no `#` prefix. If you like older version's style, you can recall it by setting.
    - `projectHeaderTemplate` to `# __HEADER__`
    - `fileHeaderTemplate`: to `## __HEADER__`
- Improve: Differentiate file-header color and project-header color on `narrow-editor`.
- Improve: When `searcher`(`ag` or `rg`) command not found, notify error as notification dialog. @slavaGanzin #244

# 0.51.0:
- Fix: [Critical] Guard infinite loop(Atom freeze) when moving to last line on `narrow-editor`. #239, #241.
  - This issue happen when `editor.scrollPastEnd` is `false`(default).
  - This is basically upstream Atom-core's bug to fire `onDidChangeScrollTop` event with same scrollTop value.
    - Reported/fixed on Atom-core but not released yet.
  - This time fix is to ignore event when called with same scrollTop value to avoid infinite loop.
- Improve: Truncate long line on `narrow-editor` #243
  - This is to to avoid Atom hang when render very long line `narrow-editor`.
  - Typically happen when searching minified/uglified file.
  - New config:
    - `textTruncationThreshold`( default `200` ):
      - Truncate line exceeding this width.
    - `textPrependToTruncatedText`( default `[truncated]` ):
      - When text was truncated, Text `[truncated]` is pretended to original text for user easily notice truncation.

# 0.50.5:
- Fix: Critical #239 fix Atom freeze issue.
  - When `editor.scrollTop` was `false`( default ), Atom freeze because of infinite loop at `onDidChangeScrollTop` event.

# 0.50.4:
- Fix: narrow grammar is not properly set when package panel of narrow was initially opened on Atom launch #240
  - This is because package's main is loaded earlier than activation timing when pkg panel was opened.

# 0.50.3:
- Fix: #236 refresh when query change from xxx to empty('').
  - This is regression introduced in v0.50.x.
  - When query get emptied, still last searched items are displayed where it should be cleared.
- Improve: #237 Redraw control-bar when query including "\n" was inserted.

# 0.50.2:
- Fix, Cosmetic: ControlBar regex button now correctly reflect useRegex state

# 0.50.1:
- Fix: `narrow-ui:open-here` now properly show original editor when active editor changed while previewing.

# 0.50.0:
- Breaking: Rename command from `narrow-ui:confirm-open-here` to `narrow-ui:open-here`.
  - This is command introduced in v0.49.0 in a few hours ago. And have default keymap, so the impact should be not big I believe.
- Improve: `narrow-ui:open-here` restore original editor's scrollTop when necessary.
  - Since user opened item in same pane of UI. The scrollTop change made while preview should be reverted.
  - This was not issue before since confirmed item was always opened at original editor's pane.

# 0.49.0:
- New: `narrow-ui:confirm-open-here` which open file at same pane of UI.
  - `O` is mapped by default in `read-only` mode of UI.
- Fix: unsaved-change-aware ability of `git-diff-all` was broken from v0.48.1. #234.
  - Because I blindly use `TextBuffer.load` which just load fileContent from disk, so unsaved modification was just ignored.
- Fix: unsaved-change was incorrectly ignored on `update-real-file` from v0.48.1 #234.
  - This is same reason of `git-diff-all` bug I mentioned above.

# 0.48.1:
- Fix: `git-diff-all` and `update-real-file` no longer add temporally opened editor into workspace. #232.

# 0.48.0:
- Fix: `select-files` sometimes failed to open when it fail to determine pane to open.
  - Now no longer fail to open by explicitly specifying which pane to open( it's same pane of original UI ).
- Internal: Avoid overuse of ProviderBase.
  - Avoid usage as proxy to utility methods, now explicitly import utility method by each file.
- Breaking: Provider `atom-scan` no longer support direct edit.
  - `atom-scan` use `workspace.scan` method internally, and it item truncate matched lineText to fit screen width.
  - Since `narrow:update-real-file` works by replacing whole line, this `workspace.scan`'s truncation doesn't work fit well.
  - Why I supported this feature for this provider is just because of my lack of understanding of this caveat.

# 0.47.0:
- New: #230 `narrow:git-diff-all` now aware of unsaved modification.
  - Refresh items without explicit save.
    - Old: items are refreshed on save( `editor.onDidSave` ).
    - New: items are refreshed on modified( `editor.onDidStopChanging` ).

# 0.46.1:
- FIX: #227 `narrow:search-current-project-by-current-word` did not work correctly.
  - Always threw `Uncaught TypeError: dir.contains is not a function`. but no longer.

# 0.46.0: Available from Atom v1.19.0-beta0 and above
- Support: Engine `^1.19.0-beta0`.
- Internal: All code are converted from CoffeeScript to JavaScript #218, #219, #220
- Improve: Use decoration to highlight narrow-editor.
  - Atom v1.19.0 and above allow foreground color change by decoration type `text`.
  - Now when multiple matches found on single line, item in narrow-editor highlight matched part only.
  - e.g. scan `foo`, for text `foo foo`. (NOTE: `()` surrounded means highlighted)
    - Old: 1st-item = `(foo) (foo)`, 2nd-item = `(foo) (foo)` <- can not distinguish visually
    - New: 1st-item = `(foo) foo`, 2nd-item = `foo (foo)` <- can see matched part.
  - All highlight is done by decoration, no longer use grammar info to highlight narrow-editor.
- Breaking: #224 Now no longer display line/column info by default.
  - Affected provider: `scan`, `search`, `atom-scan`, `git-diff-all`, `project-symbols`
- Fix: #226 `search` no longer show items for the file not belonging to any project.
  - This was incorrectly shown if files are modified.

# 0.45.1:
- Fix: `symbols` incorrectly showed file and project header.
- Fix: `project-symbols` did not show file and project header where it should show.

# 0.45.0:
- Fix: Search option state now correctly restored on `narrow:reopen`.
- New, Experiment: Add service for external custom provider.
  - Super experimental, immature state. Will be changed in future.

# 0.44.2:
- Fix: Critical: items for modified files are not shown on ui on `search`
  - Modified files was updated only when modified after ui opened.
- Fix: Critical: when project include modified file, `atom-scan` throw exception.
  - This is old bug, NOT related to recently introduced modified-file-aware enhancement.
- Fix: Result in no-focus on `narrow:close` if active paneItem was changed after ui open(except preview).
  - Introduced from v0.42.0.

# 0.44.1:
- Fix: Critical bug `search` finish rendering before all search task have not yet finished.
  - In other word, not all items found are rendered on Ui. sorry!.
# 0.44.0:
- Improve: #213 `search`, `atom-scan` now aware of unsaved modification.
  - Refresh items without explicit save.
    - Old: items are refreshed on save( `editor.onDidSave` ).
    - New: items are refreshed on modified( `editor.onDidStopChanging` ).
  - Can direct-edit( `update-real-file` ) for files which have unsaved modification.
    - Old: direct-edit warn and cancelled when trying to change files which have unsaved modification.
    - New: direct-edit can change files which have unsaved modification.

# 0.43.0:
- New: QueryHistory support
  - History are maintained per provider and persists across Atom reload.
  - Max 100 entries are kept.
- New: Default keymap for following keymap to commands for `has-narrow` scope.
  `ctrl-cmd-[`: `narrow:previous-query-history`
  `ctrl-cmd-]`: `narrow:next-query-history`
  `ctrl-cmd-e`: `narrow:next-query-history` ( override default `cmd-e` but only when workspace have `narrow-editor`)

# 0.42.0: BIG CHANGE.
New: `narrow-ui:delete-to-end-of-search-term`.
  - If cursor is not at end of searchTerm, it delete text till end of searchTerm.
  - If cursor is already at end of searchTerm it delete to beginning of line.
  - Keystroke `ctrl-u` is mapped only on `narrow-editor.prompt`
Fix: When `ag` searched with `regex` enabled, it couldn't find multiple match on single line.
  - Remove `--nomultiline` from ag option. #206
  - The cause still not yet cleared( I reported to the_silver_searcher repo ).
  - With this option enabled, search result found strange position when pattern was regex.
New, Breaking: Now `atom-scan`, `search` take searchTerm from first query of narrow-editor #205.
  - As like `scan` provider have been already doing.
  - So you can modify searchTerm after start `narrow:search`.
  - Behavioral changes:
    - searched items are incrementally rendered instead of collect-all-items-then-render-in-bulk.
    - FilePaths appeared on `narrow-editor` is no longer ordered, just appeared in the order of finished.
    - Previously running search task(external process/item rendering) is cancelled on new search request.
  - New `refreshDelayOnSearchTermChange` control amount of delay to start search.
    - `search` and `atom-scan`: Default `700`ms
    - `scan`: default `10`ms
  - Breaking: No longer read searchTerm from dedicated `mini-editor`.
  - Breaking: Remove input-history feature( might come back in future )
  - Breaking: `space` contained searchTerm is currently NOT searchable( will find the way in future release ).
  - Breaking: `rememberUseRegex` for `search` and `atom-scan` was removed. (will find the way in future release ).
  - Breaking: Config `useRegex` is renamed to `searchUseRegex`. No auto-migration, sorry.
New: Super useful `query-current-word`.
  - Replace `narrow-editor`'s query with cursor-word, and `narrow-editor` automatically refreshed.
  - You can invoke this command from inside or outside of `narrow-editor`.
- Breaking: Remove not much useful(IMO) providers. #209
  - Removed following providers
    - `bookmarks`, `linter`, `git-diff`
  - Why? Just I want to reduce amount of code I need to maintain.
  - I haven't used these providers since then I created, it's just exercise to test architecture of narrow( ui and provider ).
  - Sorry in case someone like and uses these providers.
- Breaking, Improve: Closing `narrow-editor` in normal way no longer activate provider's pane. #210
  - In Previous release:
    - There is no behavioral diff between `narrow:close` command and closing `narrow-editor`'s tab manually.
  - From this release.
    - Closing `narrow-editor` by mouse of normal `core:close` do nothing about active focus.
    - Closing `narrow-editor` by `narrow:close` activate( focus to ) original editor after close.
- Bug: When autoPreview was disabled, confirm didn't scroll to new cursor position.
- Improve: Keep minimum 3 column width to reduce chance where item-text side-shifted on item filtered.
  - Was 2 column width in previous release.

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
