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
