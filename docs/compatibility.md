# Compatibility

Mojotui `0.1.1` is tested with stable Mojo `1.0.0` and Moji `0.1.0`. Both are
exact runtime dependencies of the precompiled Conda artifact because `.mojoc`
compatibility is compiler-specific.

Supported native targets are:

- Linux x86-64 (`linux-64`)
- Linux ARM64 (`linux-aarch64`)
- macOS ARM64 (`osx-arm64`)

The `mojo-mojotui` package is ahead-of-time compiled, but stable Mojo 1.0 links
the compiler runtime dynamically. Mojotui therefore does not describe the
artifact as a fully static or dependency-free binary. Applications should keep
the hosted Mojotui channel, Modular MAX channel, and conda-forge in that order
and install the exact release they test.

Mojotui is pre-1.0. Supported foundation APIs follow the policy in
[stability.md](stability.md); experimental application, editor, event, and form
APIs may change in a later pre-1.0 minor release with migration notes.
