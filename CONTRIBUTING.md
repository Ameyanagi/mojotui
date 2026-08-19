# Contributing to MojoTUI

Thanks for helping build MojoTUI. Contributions should preserve its core
properties: deterministic rendering, explicit terminal capabilities, Unicode
correctness, and testable behavior without a live terminal.

## Development environment

Install Pixi, clone the repository, and run:

```bash
pixi install --locked
pixi run check
```

`pixi run check` is the required local gate. It covers formatting, strict type
and safety checks, the Mojo test suites, compile-fail fixtures, and PTY-backed
terminal tests. See `PLAN.md`, `ARCHITECTURE.md`, `RUNTIME.md`, and
`TYPE_SAFETY.md` before changing the corresponding subsystem.

## Changes

- Keep public imports deliberate; do not expose implementation details from
  `mojotui/__init__.mojo` or subpackage roots accidentally.
- Add focused unit tests for behavior changes and regression tests for fixes.
- Add virtual-buffer assertions for rendering changes. Add PTY coverage when
  behavior depends on a real terminal session.
- Keep platform-specific and unsafe operations inside the established terminal
  boundary.
- Update user documentation and `CHANGELOG.md` when a change affects users.
- Include reproducible benchmark methodology with performance changes.

## Pull requests

Keep pull requests scoped and explain the public behavior, tests, compatibility
impact, and performance impact. Run `pixi run check` before requesting review.
Breaking public API changes must be identified explicitly.

By contributing, you agree that your contribution is licensed under either the
Apache License 2.0 or the MIT License, at the user's option.
