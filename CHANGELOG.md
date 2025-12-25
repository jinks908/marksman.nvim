# Changelog

## [Unreleased]



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

- **Added** - New features and functionality
- **Changed** - Changes to existing functionality
- **Fixed** - Bug fixes and corrections
- **Removed** - Removed features and code
- **Security** - Security vulnerability fixes and improvements
- **Deprecated** - Features marked for future removal

## Links

- [Repository](https://github.com/jinks908/marksman.nvim)
- [Issues](https://github.com/jinks908/marksman.nvim/issues)
- [Releases](https://github.com/jinks908/marksman.nvim/releases)
