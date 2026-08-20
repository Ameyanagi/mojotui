# API stability tiers

Mojotui is pre-1.0 and pins an exact Mojo nightly. These tiers describe how the
project manages source changes within that constraint; they are not a 1.0
compatibility promise.

## v0.1 release and distribution

`v0.1.0` is the first public release target. It will ship one independently
versioned `mojotui` distribution containing supported public subpackages and a
top-level convenience import. The subpackages are dependency boundaries, not
separately versioned artifacts.

The tagged source archive is canonical. The release uses Mojo
`1.1.0.dev2026081813`, pinned exactly in `pixi.toml` and resolved for every
supported target in `pixi.lock`. A precompiled package is compatible only with
that compiler and may be published only after fresh-prefix consumer tests pass
on Linux x86-64, Linux ARM64, and macOS ARM64. A compiler upgrade requires a
new tested release and migration notes when it changes source behavior.

Stage I package boundaries, public symbols, extension tests, builders, fixture
provenance, and packaging gates are part of `v0.1.0`. Stage J widget expansion
and measured performance work begins after that release.

## Supported foundation

The public APIs in `core`, `text`, `widgets`, and `terminal` are the supported
foundation. Their documented behavior, ownership rules, and safety invariants
are protected by tests. Breaking changes are reserved for a pre-1.0 minor
release, require migration notes, and must preserve a clear replacement path
unless the old behavior is unsafe or incorrect.

This tier includes frame transactions, buffers, layout, styles, rich text,
adaptive colors, explicit terminal capabilities, widget contracts, built-in
widgets, backend contracts, terminal sessions, and the ANSI, inline, and
headless backends. Ratatui-inspired names are covered only to the extent
documented in the API and layout compatibility pages.

## Experimental ecosystem

The public APIs in `event`, `app`, `editor`, `forms`, and file or clipboard
services are experimental. They are fully typed, tested, and safe by default,
but may change in any pre-1.0 minor release as Mojo's runtime and application
patterns mature. Changes still require release notes and migrations when a
mechanical replacement exists.

This tier includes `Application`, application hosts, `RuntimeAdapter`, input
parsing, the POSIX reactor, the editor engine, form controls, and service
interfaces. In particular, no concrete general-runtime adapter is stable until
Mojo exposes a supported public task runtime.

## Internal boundary

Private names, files under `platform`, generated Unicode tables, test fixtures,
and implementation details have no source-compatibility promise. The platform
boundary remains covered by the unsafe allowlist and integration tests, but it
is not an extension API.

Top-level `mojotui` imports do not imply a stability tier. Use this document and
the owning subpackage to determine the policy. The exact supported compiler is
always the version locked in `pixi.toml` and `pixi.lock`.
