# Mojotui feasibility record

## Decision

Proceed with the project. The rendering, Unicode, static-generic API, terminal
lifecycle, input parsing, POSIX polling, and performance experiments are viable
on the pinned Mojo nightly. The complete locked check passes in GitHub Actions
on macOS ARM64, Linux ARM64, and Linux x86-64.

## Tested toolchain

- Mojo `1.1.0.dev2026081813` (`8cd05901`)
- Pixi `0.76.2`
- Unicode width data `17.0.0`, provided by the installed moji package
- Workspace targets: `osx-arm64`, `linux-64`, and `linux-aarch64`

`pixi.lock` resolves the exact Mojo build for every target. The GitHub Actions
matrix runs `pixi run --locked check` on ARM64 macOS plus x86-64 and ARM64
Linux runners.

## Terminal boundary

The direct Mojo-to-libc experiment succeeded without representing `termios` in
Mojo. The private platform module passes aligned opaque storage through
`tcgetattr`, `cfmakeraw`, and `tcsetattr`. It interprets only the stable scalar
layouts of `pollfd` and `winsize`.

On the tested macOS host, a C ABI probe reported:

```text
termios=72 align=8 pollfd=8 winsize=8 nfds_t=4
```

Mojotui reserves 256 initialized bytes aligned to eight bytes for the opaque
terminal snapshot. The focused PTY suite proves:

- raw mode disables canonical input and echo;
- terminal size is read correctly;
- stdin readiness and timeouts work through `poll`;
- input bytes reach the incremental parser;
- size changes are coalesced after reactor wakeups;
- explicit close restores the original settings;
- scope destruction restores the original settings;
- a raised Mojo error restores the original settings; and
- raw Ctrl-C is parsed as `Control+c`, after which cleanup restores the TTY.

Direct FFI is preferable to a C shim at this stage. A shim would duplicate the
same libc calls while adding a native build and consumer-link requirement. The
current boundary has nine documented calls in one allowlisted file, exposes
no pointers, and uses no `UnsafePointer`. Reconsider a shim if Linux CI finds a
layout mismatch, signal handling requires a nontrivial `sigaction` mapping, or
Mojo packaging gains a dependable way to ship native companion objects.

## Generic APIs

Representative `Backend`, `Widget`, and `Application` traits compile using
static specialization. The application contract has concrete associated model
and message types, so no runtime trait objects or type erasure are required.

## Unicode and parsing

Generated width lookups cover combining characters, East Asian width,
ambiguous-width policy, emoji presentation, variation selectors, ZWJ clusters,
and regional-indicator flags. The input parser tolerates fragmented UTF-8 and
escape sequences and supports keys, modifiers, focus, bracketed paste, and SGR
mouse input.

## Performance sample

The Phase 0 benchmark constructs and encodes complete logical frames, including
buffer allocation. On the local arm64 Mac it measured:

```text
80x24 full ANSI diff mean:      114.26 us (about 8,752 frames/s)
80x24 one-cell ANSI diff mean:   61.73 us (about 16,199 frames/s)
```

These are development measurements rather than stable regression thresholds,
but they clear the initial 60 frames-per-second target by a wide margin.

## Async runtime finding

The pinned standard library does not expose a supported general-purpose async
task API. Its `_asyncrt` source explicitly says that the task primitives are
private, unfinished, expected to change substantially, and should not be used
outside the standard library and kernel library. Mojotui therefore will not
import that private module merely to claim integration.

The stable design remains runtime-neutral: typed commands, subscriptions,
operation generations, cancellation intent, a bounded message queue, and a
reactor wakeup descriptor. A future adapter can bind those contracts to Mojo's
public general runtime when that API exists. Until then, the synchronous POSIX
reactor is the supported implementation, and stale-result rejection remains
the fallback where underlying work cannot be cancelled.

## Deferred evidence

- Test restoration after a background-task failure once a supported runtime
  adapter exists; raised synchronous failures are already covered.
- Add sanitizer jobs for the allowlisted platform module when the CI toolchain
  can link the sanitizer runtimes on both targets.
