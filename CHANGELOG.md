# Changelog

All notable user-facing changes to MojoTUI are documented here.

## [Unreleased]

## [0.1.2] - 2026-09-05

### Fixed

- Preserve existing ordinary file permissions and ownership during atomic
  editor saves. Create new files and exclusively owned temporary files with
  restrictive permissions, reject symlink and non-regular destinations, and
  remove owned temporary files after recoverable failures. Saves require a
  caller-controlled containing directory; ACLs, extended attributes, and
  crash durability remain outside the file-service contract.
- Reject file loads when metadata changes during the read so a stale snapshot
  cannot authorize overwriting an external update.
- Advance partial writes by byte offsets without slicing UTF-8 text inside a
  code point. Exercise byte-exact recovery after a real partial write.
- Keep PTY readiness inside the visible viewport and exercise short-write
  recovery on native pipes and reduced-capacity Linux pipes.

### Changed

- Share checksum-verified source archive creation and restoration between PR
  and release workflows. Test the extracted library and a fresh consumer on
  all three supported native targets.

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

[Unreleased]: https://github.com/Ameyanagi/mojotui/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/Ameyanagi/mojotui/releases/tag/v0.1.2
[0.1.1]: https://github.com/Ameyanagi/mojotui/releases/tag/v0.1.1
[0.1.0]: https://github.com/Ameyanagi/mojo-channel
