# MojoTUI reference architecture

This document preserves the still-applicable architecture research from the
superseded draft PR #5 and reconciles it with the `v0.1.1` implementation. It
informs the remaining [extension-foundation plan](v0.1-execution-plan.md); it
does not claim that the target package graph already ships.

The references are design inputs only. Mojotui copies no source, vendors no
reference package, and adds no runtime dependency from this research.

## Pinned references

| Reference | Pin | Ideas inspected |
| --- | --- | --- |
| [Ratatui](https://github.com/ratatui/ratatui/tree/e665c36cb14752a61cd777fbd06dbef8474f2add) | `ratatui-v0.30.2`, commit `e665c36cb14752a61cd777fbd06dbef8474f2add` | Complete immediate-mode frames, buffer diffs, static/stateful widgets, headless testing, symbols, layout |
| [Crossterm](https://github.com/crossterm-rs/crossterm/tree/36d95b26a26e64b0f8c12edfe11f410a6d56a812) | `0.29`, commit `36d95b26a26e64b0f8c12edfe11f410a6d56a812` | Terminal lifecycle, queued output, semantic events, POSIX isolation |
| [Bubble Tea](https://github.com/charmbracelet/bubbletea/tree/73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290) | `v2.0.9`, commit `73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290` | Sequential model/update flow, typed effects, host lifecycle and injected tests |

Ratatui `0.30.2` declares Crossterm `0.29`, so those references describe one
coherent renderer/backend boundary. Bubble Tea informs only the application
host; Mojotui does not adopt its runtime or dynamic message types.

## Adopted direction

- A widget writes only into the borrowed frame or buffer it receives. It does
  not retain a rendering context or perform terminal I/O.
- `Terminal[B]` owns one concrete backend, frame history, resize observation,
  cursor intent, presentation, and buffer reuse.
- `Widget` and `StatefulWidget` use static dispatch. Mutable widget state stays
  application-owned.
- Backends consume one ordered `FramePatch`; lifecycle modes remain a
  `TerminalSession` concern rather than a public ANSI command language.
- Input parsing is incremental and descriptor-independent. The reactor owns
  readiness, while the parser owns only bounded partial bytes.
- One sequential update loop owns the model. Runtime adapters turn owned
  effects into owned messages and never borrow model or frame state.
- Deterministic headless rendering, injected clocks/capabilities, byte-exact
  ANSI tests, and PTY lifecycle tests are separate proof layers.

Rejected ideas include runtime trait objects, panic-based buffer contracts,
process-global input readers, dynamically typed messages, goroutine-per-command
execution, views that return ANSI strings, and sleep-driven correctness tests.

## Current `v0.1.1` contracts

### Frame ownership and presentation

Each `Terminal` owns an `ArcPointer` identity allocation. Every frame shares
that allocation; completion compares allocation identity, so equal viewport and
generation values cannot make a frame valid at another terminal. No global
counter, unsafe pointer, or forgeable integer token is required.

More than one frame may be outstanding at one generation. The first successful
completion advances the generation; siblings are then stale. Validation checks
owner, generation, viewport, cursor, complete buffer topology, and generated
patch topology before calling the backend.

`Cell` no longer normalizes an invalid requested width. `Buffer.set_cell`
rejects malformed cells and standalone continuations. Presentation revalidates
storage length, every cell, and wide leader/continuation adjacency because
stable Mojo 1.0 field privacy is convention-based rather than a complete
security boundary.

`FramePatch.validate()` rejects out-of-area, invalid, unordered, duplicate, and
wide-overlapping changes. Concrete backends call it before output. A backend
failure commits neither history nor generation. Physical output may contain a
written prefix, so the next eligible completion is forced to a full redraw;
this is logical atomicity and resynchronization, not physical rollback.

### Parser and reactor ownership

`InputLimits` validates finite batch, incomplete-sequence, and bracketed-paste
bounds. There is no unlimited mode. A limit error clears retained input and
permanently poisons that parser instance; later feed, timeout, or EOF operations
raise deterministically rather than interpreting an attacker-controlled suffix.

`InputParser.finish()` drains complete events, resolves a bare Escape, and
rejects incomplete UTF-8, control sequences, or bracketed paste. Successful EOF
closes the parser. `TerminalApplicationHost` finalizes input on hangup before an
Escape timeout can reinterpret an incomplete control sequence.

### Terminal session lifecycle

`TerminalSession` borrows descriptors and never closes them. It validates the
output TTY before changing input mode, writes enter/leave controls through a
checked partial-write loop, and tracks raw-mode ownership independently from
presentation ownership. Explicit close clears each half only after successful
cleanup, so a repeated close or the non-raising destructor retries unfinished
work.

Stable Mojo 1.0 provides no safe mutable process-global registry for an exact
device-wide lease. Mojotui instead rejects an input descriptor whose termios is
already exactly `cfmakeraw` state. This deterministically prevents nested
Mojotui sessions on the same input TTY and avoids destructive restore ordering.
It does not detect two sessions that use different input TTYs with the same
output TTY, nor can it exclude another process. Documentation therefore calls
this an overlap guard, not a complete device lease.

PTY coverage proves explicit close, implicit cleanup, raised application error,
Ctrl-C, resize, split descriptors, retryable failure of either cleanup half,
same-input overlap rejection, and restoration when a later host field fails
during construction.

### Unicode policy

Mojotui `0.1.1` depends on Moji `0.1.0` for Unicode data, grapheme iteration,
and display width. The dependency direction is `Mojotui -> Moji`, never the
reverse. Cells contain resolved width and style; geometry and layout operate
only in integer terminal columns. The editor status, selection motion, buffer
clipping, and wide topology use the same width facade.

## Target `v0.2.0` package direction

The current source offers public import namespaces, but `core.cell` still
imports the public text facade and `terminal.backend` still includes POSIX
implementations. The dependency-directed Stage I target is:

```text
private Moji width adapter
            |
            v
           core <--------- text
            |               |
            +-------> widgets
            |               |
            +-------> terminal-core
                            |
private POSIX boundary ---> terminal-posix
                            |
event-parser --------------> event-posix
                            |
                            v
                         app-core ---> app-posix

core + text ------------> editor-engine
widgets + editor-engine -> editor-widget
event + app ------------> editor-controllers
private POSIX boundary -> editor-file-service
editor-widget + widgets -> forms

all supported namespaces -> mojotui convenience root
```

The target has five hard properties:

1. Core, text, widgets, terminal-core, and editor-engine import no POSIX layer.
2. Terminal-core owns backend/frame contracts and `HeadlessBackend`; descriptor
   output and sessions live outward.
3. The input parser remains pure; POSIX readiness and reads live outward.
4. Application and editor integrations depend inward without a second runtime.
5. The distribution remains one Conda artifact unless evidence justifies a
   packaging split.

The target is intentionally future scope. `v0.1.1` package smoke proves public
imports work; it does not falsely certify this final dependency graph.

## Extension surface still open

Stage I retains validated public symbol families, deterministic snapshot and
wide-invariant helpers, an external third-party widget fixture, normalized
builders, and reproducible Ratatui layout fixture generation. These are useful
extension guarantees, but none is required to describe the implemented
renderer, editor, fuzzy picker, or form workflow honestly in `v0.1.1`.

## Performance implications

Benchmarks must isolate render, diff, ANSI encode, parser batch, and transport
costs; record compiler, target, CPU, OS, flags, warmup, iterations, and medians;
and compare at least five interleaved baseline/candidate runs on one host.

The checked profiling build uses `-O3 -g1`. Existing lazy-list evidence shows a
large startup/memory reduction by avoiding 50,000 eager rich-text values, while
visible rows remain grapheme-aware object work. SIMD is appropriate only for a
profiled numeric or byte-oriented kernel with a scalar reference and semantic
equivalence tests. It is not justified for arbitrary `String`, grapheme, or
`Cell` object paths merely to satisfy a performance label.
