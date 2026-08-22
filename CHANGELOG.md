# Changelog

All notable user-facing changes to MojoTUI are documented here.

## [Unreleased]

## [0.1.1] - 2026-08-22

This is the first source-tagged corrective release.

### Added

- Bounded terminal input batches, control sequences, and bracketed paste with
  deterministic EOF finalization and permanent poison-on-rejection semantics.
- Cross-terminal frame ownership checks, buffer and patch topology validation,
  checked partial-write handling, and full-redraw recovery after failed
  presentation.
- Same-input terminal-session overlap rejection plus PTY coverage for nested
  sessions, retryable split cleanup, and host-construction rollback.
- Dirty-editor quit confirmation, display-column status for CJK/emoji, and
  actionable load/save errors.
- A focused fuzzy input workflow and complete form example with traversal,
  validation, submit, cancel, and shared key/paste-to-editor mapping.
- Installed-package coverage across the root and public subpackage imports.

### Changed

- Pin stable Mojo `1.0.0` and Moji `0.1.0` exactly in workspace, recipe, lock,
  and emitted runtime metadata.
- Build and test source and packages natively on Linux x86-64, Linux ARM64,
  and macOS ARM64 before publication.
- Make optimized, symbolized profiling builds explicit and keep recorded
  timings labeled as machine-specific evidence.

## [0.1.0] - 2026-08-21

An initial Conda package was published on all three supported platforms without
a corresponding Git tag or GitHub source release. Its runtime compiler metadata
was broader than the precompiled ABI contract. Version `0.1.1` supersedes it;
new consumers should not install `0.1.0`.

[Unreleased]: https://github.com/Ameyanagi/mojotui/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/Ameyanagi/mojotui/releases/tag/v0.1.1
[0.1.0]: https://github.com/Ameyanagi/mojo-channel
