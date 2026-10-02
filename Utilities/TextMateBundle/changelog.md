# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## v0.11.1

Date: 2026-06-29

### Fixed
- Fixed the expression for the form of numeric constants supported

### Added
- Added support for new XXMI v0.9.2 Pool section type and new operators
- Added support for new XXMI feature to allow `$variables` as setting statement values

### Changed
- Changed the scope names of some section headers and other items to diversify highlighting

**Full Changelog**: https://github.com/lupomikti/migoto-vscode/compare/v0.11.0...v0.11.1

## v0.11.0

Date: 2026-06-16

This release doesn't change functionality very much.
It's a refactor of the syntaxes to be more in line with the way the grammar.js file of tree-sitter-migoto is written.
Alignment will make things easier to maintain going forward.

**Full Changelog**: https://github.com/lupomikti/migoto-vscode/compare/v0.10.4...v0.11.0

## v0.10.4

Date: 2026-02-16

### Fixes

- Fixed an issue that prevented the arguments to a draw instruction from highlighting correctly in certain circumstances

**Full Changelog:** https://github.com/lupomikti/migoto-vscode/compare/v0.10.3...v0.10.4

## v0.10.3

Date: 2026-01-31

Moved code base into its own repository in preparation for submodule implementation in previous repository.

### Added

- Created CHANGELOG file.
- Added a CONTRIBUTING.md file
- Added support for .3dm and .migoto file extensions

### Changed

- Updated LICENSE file name.
- Implemented the use of Bun for package management

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.10.2...v0.10.3

## v0.10.2

Date: 2026-01-11

### Fixes

- Fixed handling of whitespace in section headers.
- Fixed handling of paths that start with `..`.
- Fixed `draw` insructions not supporting full operational expressions.
- Fixed precedence of `key-value` in a Setting Statement's value.
- Fixed scope name of Preset Section run instruction.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.10.1...v0.10.2

## v0.10.1

Date: 2025-07-10

### Fixes

- Fixed a typo in the override parameter scope name.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.10.0...v0.10.1

## v0.10.0

Date: 2025-07-08

### Major Refactor

This refactor addresses the growing number of issues that were popping up with v0.7.x and v0.8.x versions. The structure of the syntax should be more sensible and align with future plans for the tree-sitter grammar that will expand editor support.

### Additions

- Added support for fuzzy match expressions.
- Added `dll_initialization_delay` key in System section.
- Added `screen_width`, `screen_height`, `dump_path` keys in System section.
- Added support for a blank namespace declaration (`namespace = `).

### Changes

- Changed Regular Expression tmLanguage scope name to include `.pcre2`.
- Updated character class highlighting in Regular Expression tmLanguage files.
- Adjusted precedence of `#path_value` in Setting Statement rules.
- Adjusted excluded special characters in identifier-related Regexes.
- Changed handling of `null` to no longer be a static value as it is only present in Setting Statements and Resource Usage Expressions.
- Improved detection of hexadecimal numbers in clear instructions.
- Updated paths to handle the use of `..` inside of them.

### Fixes

- Fixed TextureOverride section vertex limit raising related keywords' Regex.
- Fixed Assignment Statement variable identifier matching part of Regex.
- Fixed Primary Statement Regex to properly match the shader and buffer variables.
- Fixed Analysis Options in Hunting section.
- Fixed trailing space on Declarations breaking highlighting.
- Fixed incorrect exclusion of spaces in namespaced variables and sections.
- Fixed handling of file names with spaces that aren't a part of a fully qualified path.
- Fixed Regex handling of some `match_`-related keys.
- Fixed dump instruction highlighting.
- Fixed highlighting for `blend[N]` and `blend_factor[N]` keys in CustomShader section.
- Fixed `true` and `false` being treated as language constants; they are only allowed as Setting Statement values.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.8.3...v0.10.0

## v0.8.3

Date: 2025-05-14

### Changes

- Update excluded namespace characters in a Namespace Declaration to include `=` and `$`.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.8.2...v0.8.3

## v0.8.2

Date: 2025-05-14

### Changes

- Update excluded namespace characters in a namespace resolution to include `=` and `$`.
- Update path and file regexes to exclude `=` and `$`.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.8.1...v0.8.2

## v0.8.1

Date: 2025-05-13

### Changes

- Update excluded namespace characters in a namespace resolution to no longer include `\`.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.8.0...v0.8.1

## v0.8.0

Date: 2025-05-13

### Changes

- Update preamble to handle the include condition declaration.
- Allow Conditional Expressions in the Constants section.
- Update a few scope names.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.7.0...v0.8.0

## v0.7.0

Date: 2025-05-09

### Changes

- Update DSL name to "Migoto".
- Update handling of namespaces to explicitly exclude some characters.
- Update Literal List to exclude `unless_null` in the match.
- Update path and file handling to allow `/`.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.5.0...v0.7.0

## v0.5.0

Date: 2025-04-15

### Additions

- Added DXGI formats for highlighting.

### Changes

- Updated Lword values.

### Fixes

- Fixed section names breaking highlighting when preceded by whitespace.
- Fixed Include and Preset sections being treated as commandlist sections.
- Fixed detection of a Definition vs. a Declaration.
- Fixed allowing constants to match an Lexpression.
- Fixed Literal List highlighting.
- Fixed a long-standing issue with highlighting file names with spaces.

**Full Changelog:** https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.4.3...v0.5.0

## v0.2.0 - v0.4.3

Please see the Full Changelog at https://github.com/lupomikti/3dmigoto-ini-extension/compare/v0.2.0...v0.4.3