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
