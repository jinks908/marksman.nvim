# Changelog

## [1.4.5] - 2025-01-09

### Added
- Option to ignore builtin marks from next/prev navigation
- Enable/disable builtin mark types in Telescope picker


## [1.4.4] - 2025-01-06

### Fixed
- Replace `night_vision.nv_state` with correct `night_vision.nv_state[bufnr]` (for per-buffer behavior)
- Remove redundant `get_config_options()` function (just use `local config = require('marksman.config')`)
- Refactor notification logic (i.e., whether `silent = true/false` is set) 


## [1.4.3] - 2025-01-04

### Fixed
- Sign column / Line number conflicts with multi-marked lines (i.e., manual marks vs builtin marks)
- Refactored Night Vision core logic for better maintainability


## [1.4.2] - 2025-01-03

### Changed
- Builtin marks are unaffected by toggle function
- Added line number option for builtin marks
- Option to enable/disable specific builtin mark types


## [1.4.0] - 2025-12-31

### Added
- Create configs for default Marksman keymaps
- Enable manual keymaps for setting/deleting marks (i.e., `ma`/`dma`, `mb`/`dmb`, etc.) by default


## [1.3.4] - 2025-12-31

### Added
- Toggle function to add/remove mark on current line (reduces mental overhead)
- Custom sign column icons for builtin marks
- Custom virtual text for builtin marks


## [1.3.3] - 2025-12-30

### Added
- Separate highlights for builtin marks in Telescope picker


## [1.3.2] - 2025-12-30

### Fixed
- Real-time Night Vision refreshing when leaving Visual mode (for `<` and `>` signs)
- nil value errors for `last_jump_line` / `last_jump` line content (set default text instead)

### Changed
- Refactor config options structure (merge highlight settings)


## [1.3.0] - 2025-12-30

### Added
- Support for Neovim's builtin marks (i.e., `. ^ ' " < > [ ]`)
    - Option to enable/disable
    - Set custom Night Vision highlights for builtin marks


## [1.2.0] - 2025-12-25

### Changed
- Refactored sign management to improve performance and maintainability
- Revise README.md to reflect new features and changes

### Removed
- Unused `hide_line`/`show_line`/`get_sign_name` functions
- Unused variables


## [1.1.2] - 2025-12-25

### Added
- Set custom sign column character/icon


## [1.1.1] - 2025-12-25

### Added
- Set virtual text to mark letter


## [1.1.0] - 2025-12-25

### Added
- Extra space after NV icon for better visibility
- Enable/disable virtual text
- Set custom virtual text for Night Vision


## [1.0.0] - 2025-12-22

### Added

- Semantic version constants for Marksman and minimum Neovim requirement
- Comprehensive docstrings and public API annotations across all modules
- Mark letter validation to ensure only valid mark letters (a-z) are accepted
- Telescope extension auto-loading for seamless picker integration
- Native manual mark setting keymaps (ma, mb, etc.) enabled by default

### Fixed

- File I/O error handling for mark data read/write operations
- Timestamp persistence error handling for save/load operations
- Night Vision refresh behavior when marked lines are deleted or restored
- Proper visual state management during buffer modifications

### Changed

- Removed temporary section comments from codebase for cleaner code organization

## [0.9.0-alpha] - 2025-12-21

### Added

- Initial alpha release of Marksman plugin
- Core Night Vision highlighting system with real-time visual feedback
- Line background highlighting for marked lines
- Line number highlighting in gutter
- Sign column support with mark letters and icons
- Virtual text icons with smart hide-on-edit behavior
- Telescope picker extension for browsing and managing marks
- Mark timestamp tracking for recency-based sorting
- Per-buffer Night Vision state management for multi-window editing
- Auto-cleanup of timestamp data older than 30 days
- Configuration system for customizing highlights and behaviors

### Removed

- Defunct scaffolding files from initial project setup

---

## Legend

- **Feature** - New features and enhancements
- **Added** - Small improvements and functionality
- **Changed** - Changes to existing functionality
- **Fixed** - Bug fixes and corrections
- **Removed** - Removed features and code
- **Security** - Security vulnerability fixes and improvements
- **Deprecated** - Features marked for future removal

## Links

- [Repository](https://github.com/jinks908/marksman.nvim)
- [Issues](https://github.com/jinks908/marksman.nvim/issues)
- [Releases](https://github.com/jinks908/marksman.nvim/releases)
