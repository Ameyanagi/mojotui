# Mojotui plan

## Status

Mojotui is a new, production-oriented experimental TUI ecosystem for Mojo. It
borrows Ratatui's immediate-mode rendering model and familiar concepts, but it
does not promise Rust or Ratatui API compatibility. The public API should feel
native to Mojo and evolve with the language before 1.0.

The first supported platforms are macOS and Linux on x86-64 or ARM64 where the
pinned compiler package is available. The project targets Mojo
developers building native terminal applications. Python and `ncurses` are not
runtime dependencies.

Implementation is gated. Each phase must meet its exit criteria before later
layers can rely on it.

The Phase 0 evidence and go decision are recorded in
[`FEASIBILITY.md`](FEASIBILITY.md). Phases 1 through 6 have local
implementations and test coverage, including the renderer, terminal session,
widgets, application state/effect model, editor engine, forms, inline output,
OSC 52 copy, and runtime-neutral task bridge. The complete locked check passes
on hosted macOS ARM64, Linux ARM64, and Linux x86-64 runners. Local macOS and
Linux ARM64 validation also covers PTY lifecycle, polling, restoration,
Unicode, static-generic APIs, and the unsafe boundary.

## Product scope

The project will provide these separately usable layers:

1. A backend-independent rendering core.
2. Terminal lifecycle, ANSI output, input parsing, and event polling.
3. Stateless and explicitly stateful widgets.
4. A typed application framework based on model, message, update, and view.
5. Integration adapters for Mojo's general async runtime.
6. A full text-editor engine and editor widget.
7. Form controls, file services, clipboard adapters, and other ecosystem
   packages.

The application framework must not be required to use the renderer. Mojotui
will not implement a competing general-purpose async executor.

### Initial non-goals

- Ratatui API or source compatibility
- Windows support
- A networking runtime comparable to Tokio
- Python bindings
- Dynamic runtime widget plugins
- IDE completion, diagnostics, or language-server implementations
- General text-encoding conversion beyond UTF-8 integration hooks
- Charts, arbitrary canvas drawing, or dynamically growing inline output
- Persistent undo history across editor sessions

## Design principles

### Safe by default

Unsafe code has a default budget of zero.

- `core`, `text`, `widgets`, `app`, and `editor` must contain no raw pointer or
  FFI operations.
- Platform-specific calls belong in small private modules under `platform`.
- Raw pointers must not escape into public APIs.
- Prefer Mojo ownership, `List`, `Span`, `String`, and `FileDescriptor` over
  custom storage.
- Do not use uninitialized allocation or custom allocators without benchmark
  evidence and a separate review.
- Every unavoidable unsafe or FFI operation needs a `SAFETY:` explanation,
  documented invariants, and focused integration tests.
- CI will maintain an allowlist and reject unsafe or FFI operations outside the
  platform boundary.
- A small private C shim is allowed only when it makes a platform ABI boundary
  narrower and easier to test than direct structure manipulation from Mojo.

Moving an operation to C does not make it safe. The C code and its Mojo wrapper
form one audited boundary.

### Deterministic rendering

Given the same model, widget state, terminal size, theme, and capabilities,
rendering must produce the same cell buffer. Rendering must not read the clock,
query the terminal, perform I/O, use randomness, or depend on hidden mutable
widget state.

### Static composition

Use Mojo's static generic dispatch for backends, applications, components, and
widgets. Third-party widgets render immediately into a borrowed frame. Do not
design around heterogeneous collections of runtime trait objects. Use closed
`Variant` types where runtime heterogeneity is required.

### Strict types

The pinned Mojo 1.1 compiler uses `def` as the single function declaration
syntax and rejects the removed `fn` keyword. This project preserves the strict
semantics formerly associated with `fn`: arguments and returned values are
statically typed, fallibility is declared with `raises`, polymorphism uses
trait-constrained compile-time generics, compiler warnings are errors, and
dynamic escape-hatch types are prohibited from the library package. The
machine-checked rules are documented in [`TYPE_SAFETY.md`](TYPE_SAFETY.md).

### Explicit state and effects

One application loop owns the model. Background operations return typed
messages and never mutate the model directly. Stateful widgets receive explicit
state. Side effects are typed commands interpreted outside `update`.

## Architecture

```text
terminal bytes
    |
    v
incremental parser -> events -> reactor -> application message
                                         |
                                         v
                                  update(model, message)
                                     /             \
                              commands           subscriptions
                                  |                    |
                                  +---- adapters ------+
                                           |
                                           v
                                      new messages

model -> view -> Frame + HitMap -> current Buffer
                                      |
previous Buffer -------------------- diff
                                      |
                                      v
                               terminal Backend
```

Planned source layout:

```text
mojotui/
  __init__.mojo
  core/          geometry, style, cell, buffer, diff, layout
  text/          graphemes, terminal width, wrapping, rich text
  widgets/       stateless and stateful widgets
  terminal/      backend contract, ANSI backend, TerminalSession
  event/         input parser, event types, POSIX reactor
  app/           model/update/view loop, focus, keymaps, hit testing
  app/           commands, subscriptions, cancellation, runtime adapter
  editor/        document, selection, commands, undo, editor widget
  file/          loading, saving, metadata, external-change detection
  platform/      private platform and FFI boundary
tests/
examples/
benchmarks/
```

The exact package split may change during compiler feasibility work, but
dependency direction must remain from higher layers toward lower layers.

## Rendering model

### Geometry

- Public and internal geometry uses signed integers.
- Rectangles never have negative width or height after construction.
- Intersection, containment, translation, inset, union, and clipping operations
  handle empty rectangles and arithmetic boundaries predictably.
- Layout and rendering clip instead of indexing outside buffers.

### Cells and buffers

- A frame is a dense row-major `Buffer[Cell]` sized to the viewport.
- Start with `List[Cell]`; optimize storage only after measurement.
- A cell contains grapheme data, terminal width, style, and wide-character
  continuation state.
- Maintain previous and current buffers and emit only changed cells.
- Later drawing replaces earlier drawing.
- Clear/opaque regions and explicitly skipped transparent cells support
  overlays without a general compositing engine.
- A frame is borrowed temporarily during one draw and is never retained.

### Unicode

- Strings remain UTF-8.
- Rendering and editing operate on extended grapheme clusters.
- Mojotui owns versioned, generated terminal-width tables.
- Terminal width is always zero, one, or two cells for a rendered grapheme.
- Ambiguous-width behavior is configurable.
- Tests cover combining marks, CJK, emoji, ZWJ sequences, flags, variation
  selectors, tabs, controls, malformed input, and wide-cell replacement.
- Grapheme iteration must be linear; repeated indexed rescans are forbidden in
  hot paths.

### Layout

The initial layout engine supports horizontal and vertical distribution with:

- fixed length
- minimum and maximum
- percentage
- ratio
- fill
- spacing
- alignment and flex distribution

CSS grid and a general constraint solver are deferred until real applications
demonstrate the need.

### Widget contracts

- Stateless widgets render from value data into an area.
- Stateful widgets receive explicit mutable state such as selection or scroll
  offset.
- Large widgets render only visible rows and columns.
- Rendering inherits a clipping rectangle.
- Widgets may register interaction regions in a frame-local `HitMap`.

## Terminal and event model

`TerminalSession` owns raw mode, alternate-screen state, cursor visibility,
bracketed paste, mouse capture, capability state, and restoration. Normal
return, reported errors, catchable failures, and Ctrl-C must restore the
terminal. Recovery from `SIGKILL` is impossible and will not be promised.

The first backend is ANSI on POSIX. Headless rendering is implemented alongside
it for tests. Inline viewport support follows reliable full-screen behavior.

The input parser is incremental. Descriptor reads may contain a fraction of an
event or several events. It supports:

- key press, release, and repeat information when available
- mouse buttons, movement, drag, and scrolling
- terminal resize
- bracketed paste
- focus changes
- configurable Escape-sequence timeout

The event queue is bounded. Keys and paste data are never silently discarded.
Resize, focus, redraw, animation ticks, and mouse movement may be coalesced.
Background producers receive backpressure or an explicit overflow result.

## Application model

An application provides `init`, `update`, `view`, and `subscriptions`.

- `init` creates the model and initial commands.
- `update` processes one concrete application message and returns commands.
- `view` deterministically renders the current model.
- `subscriptions` declaratively identifies ongoing event sources using stable
  IDs.

Updates are sequential. Background work produces versioned messages. Operation
keys and generations prevent stale search, highlight, completion, or file
results from changing current state.

The loop redraws when state changes, coalesces messages before drawing, and
supports explicit redraw requests and an optional animation frame cap. Time is
provided by an injected monotonic clock; tests use a controllable clock.

Components are generic values with explicit state, message, update, and render
contracts. Parents own child state and map child messages. Focus uses stable
`FocusId` values, traversal order, modal scopes, and restoration. Contextual
keymaps translate single keys or timed key sequences into semantic commands.

## General Mojo runtime integration

Mojotui does not own an executor. The stable application surface uses commands,
subscriptions, operation IDs, cancellation tokens, and typed messages rather
than exposing unstable runtime implementation types.

The first event reactor is synchronous and multiplexes terminal input, timers,
resize notifications, and a wakeup channel. `RuntimeAdapter` defines the typed
integration point for Mojo's future public task runtime without importing the
private `_asyncrt` package. All work is scoped to an adapter or subscription;
detached work is not supported. If underlying cancellation is unavailable,
stale results are safely ignored.

Async limitations do not block the renderer, application state model, or editor
from shipping.

## Text-editor engine

The editor is an independent subsystem built after the rendering and
application foundations.

- Tree-backed piece table with cached byte, grapheme, newline, and display
  metadata
- Incremental line index
- Canonical byte-offset positions
- Persistent markers that move predictably through edits
- Ordered, non-overlapping multiple selections internally
- Grapheme-aware horizontal motion and desired-display-column vertical motion
- Transactional undo and redo with selection state
- Configurable history limits and explicit truncation behavior
- Tabs preserved in the document and expanded at configurable tab stops
- No-wrap and soft-wrap modes
- Versioned asynchronous syntax-highlight ranges
- Conventional default editing commands
- Separate Vim and Emacs controller/keymap packages
- UTF-8 with BOM and LF/CRLF detection and preservation
- File loading, atomic saving where available, metadata checks, and external
  change detection in a separate file-service package
- Pluggable clipboard with internal and optional OSC 52 implementations

Completion engines, language servers, diagnostics, and syntax grammar
implementations are integrations rather than editor-core responsibilities.

## Initial widgets

The first widget set contains:

- `Block`
- `Paragraph`
- `List` and `ListState`
- `Table` and `TableState`
- `Tabs`
- `Scrollbar`
- `Gauge` and `LineGauge`
- `Sparkline`
- `Clear`
- editor widget

Rich text uses `Span`, `Line`, and `Text`. Form controls follow the editor so
text fields and text areas share its editing behavior.

## Delivery phases

### Phase 0: feasibility

Deliverables:

1. Pin the exact Mojo nightly in project configuration.
2. Add macOS and Linux environments and CI coverage.
3. Prove package, trait, ownership, test, and benchmark conventions.
4. Enter raw mode, query terminal size, read bytes, and restore state.
5. Multiplex stdin, resize, and a timer through POSIX polling.
6. Test restoration after success, errors, Ctrl-C, and task failure.
7. Attempt direct Mojo-to-libc `termios` integration.
8. Compare direct FFI with a minimal private C shim if ABI mapping is brittle.
9. Run one AsyncRT task without blocking terminal input.
10. Test cancellation or safe stale-result rejection and reactor wakeup.
11. Generate and query a small Unicode terminal-width table.
12. Compile representative generic `Backend`, `Widget`, and `Application`
    contracts.
13. Benchmark a full and changed 80x24 cell buffer.
14. Audit the unsafe/FFI allowlist.

Exit: publish a go, redesign, or stop record. Terminal restoration, Unicode
width, nonblocking input, and viable generic APIs are hard gates. AsyncRT may be
deferred without stopping the project.

### Phase 1: rendering core

Implement geometry, styles, grapheme-aware cells, buffers, clipping, diffing,
layout, and rich text. Exit when unit/property tests, buffer snapshots, Unicode
fixtures, and initial benchmarks pass.

### Phase 2: terminal and input

Implement the backend contract, ANSI backend, headless backend,
`TerminalSession`, POSIX reactor, input parser, and capability state. Exit when
PTY tests prove lifecycle restoration, resize behavior, fragmented parsing, and
minimal changed-cell output on macOS and Linux.

### Phase 3: widgets and dashboard

Implement the initial widget set and an interactive system-monitor dashboard.
The dashboard must exercise nested layout, rich text, lists, tables, gauges,
Unicode, input, resizing, state, and frequent redraws.

### Phase 4: application framework

Implement model/message/update/view, commands, subscriptions, focus, contextual
keymaps, hit testing, deterministic time, cancellation conventions, and
background result delivery.

### Phase 5: editor

Implement the document structure, selections, edit transactions, undo/redo,
wrapping, editor view, highlighting interface, file service, and clipboard
interface. Exit when editing and viewport navigation remain smooth on 10-50 MB
UTF-8 files without whole-document work per keystroke.

### Phase 6: ecosystem

Add form controls, inline viewport support, optional clipboard providers,
runtime integration boundaries, and advanced widgets driven by demonstrated
application needs.

Local deliverables:

- `TextInput` and `TextArea` share the editor engine; `Checkbox` and `Button`
  compose the existing render primitives.
- `InlineBackend` owns a fixed-height region using relative ANSI movement.
- `Osc52Clipboard` is opt-in, UTF-8 aware, and bounded before encoding.
- `RuntimeAdapter` and `RuntimeScope` keep future runtime types private, scope
  task shutdown, and transfer concrete messages.
- `PosixReactor` can poll terminal input and a background wakeup descriptor in
  one audited libc call.
- Public setup, architecture, editor, runtime, dashboard, widget, backend,
  terminal, API, type-safety, and limitations documentation is present.

The pinned toolchain has no supported public general task runtime, so the
concrete AsyncRT binding remains deferred. The runtime-neutral adapter contract
is implemented and tested without importing private `_asyncrt` internals.

## Verification strategy

- Unit tests for pure data structures and algorithms
- Property tests for rectangles, layout allocation, clipping, buffer diffs,
  parsing, cursor motion, selections, and undo invariants
- Golden tests for cell grids and emitted ANSI bytes
- PTY integration tests for raw mode, resize, input, partial sequences, errors,
  Ctrl-C, and restoration
- Differential and conformance fixtures for Unicode width
- Benchmarks for full/diff redraw, layout, width lookup, parsing, editor edits,
  undo/redo, and large-file scrolling
- Debug and optimized CI runs
- Scheduled AddressSanitizer and ThreadSanitizer runs for the platform boundary

Initial performance targets:

- changed 80x24 frames comfortably exceed 60 frames per second
- rendering work is proportional to visible content
- application input is reflected within one frame
- no whole-document scan occurs per editor keystroke
- navigation and editing remain smooth on 10-50 MB files

## Release plan

- `0.1`: rendering core, terminal backend, initial widgets, dashboard
- `0.2`: application framework and reactor
- `0.3`: editor engine and editor widget
- `0.4`: forms, file services, and the runtime-neutral adapter boundary

Pre-1.0 minor releases may make breaking changes. Each release pins and names an
exact tested Mojo nightly and includes migration notes. Source packages are the
initial distribution format; precompiled packages wait for dependable compiler
compatibility.

Before the first public release, provide a quick start, architecture overview,
dashboard tutorial, editor example, custom-widget guide, backend guide, API
documentation, terminal support matrix, and known-limitations page.

## Local release evidence

The 2026-08-19 macOS arm64 run used Mojo
`1.1.0.dev2026081813` and Pixi `0.76.2`.

- `pixi run check`: 151 Mojo tests passed across 26 test modules.
- Both examples built, and PTY tests passed normal close, implicit destruction,
  raised error, Ctrl-C, and resize cases.
- Formatting passed; the package precompiled with `--Werror`.
- The strict-type policy found no obsolete `fn` declarations, `AnyType`, or
  `PythonObject` use in the library.
- The unsafe audit found nine documented FFI calls in one allowlisted platform
  file and none elsewhere.
- The 80x24 benchmark measured 111.91 us for a full ANSI frame and 63.14 us for
  a one-cell diff, about 8,936 and 15,837 frames per second.
- The 10 MiB editor benchmark measured 3.94 us per middle edit, 3.21 us per
  undo/redo operation, and 609.05 us per 80x24 viewport render.

The compiler distribution links against a newer macOS deployment target than
the local build target and emits linker warnings during executable builds. The
builds exit successfully. This toolchain warning is outside Mojotui source.

GitHub Actions run `32193144975` passed the same locked check on macOS ARM64,
Linux ARM64, and Linux x86-64. The CI workflow runs on pushes and pull requests.
A separate tag workflow repeats the matrix and creates a source release only
after every target passes.

## Risk register

| Risk | Response |
| --- | --- |
| Mojo async APIs change | Keep stable APIs runtime-neutral; isolate the experimental adapter. |
| POSIX ABIs differ | Use a narrow audited boundary and allow a minimal C shim. |
| Dynamic trait objects are unavailable | Use static generics, immediate rendering, and closed variants. |
| Grapheme count differs from terminal width | Own versioned width tables and conformance tests. |
| Nightly compiler changes break source | Pin exact versions and upgrade through tested commits. |
| Editor scope delays usable rendering | Ship it as an independent later subsystem. |
| Terminal state leaks after failure | Use a session guard and PTY lifecycle tests. |
| Unsafe optimization spreads | Enforce a zero-default budget and an explicit allowlist in CI. |

## Definition of done

The planned project is complete when the renderer, POSIX terminal backend,
initial widgets, application framework, editor engine, file and clipboard
interfaces, and general Mojo runtime adapter meet their phase gates on macOS and
Linux; documentation is sufficient for another developer to build an
application; and all unsafe or FFI code is confined to documented, tested,
audited platform boundaries.
