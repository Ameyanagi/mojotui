# Mojotui plan

## Status

Mojotui is a new, production-oriented experimental TUI ecosystem for Mojo. It
borrows Ratatui's immediate-mode rendering model and familiar concepts, but it
does not promise Rust or Ratatui API compatibility. The public API should feel
native to Mojo and evolve with the language before 1.0.

The first supported platforms are macOS ARM64, Linux x86-64, and Linux ARM64,
where the pinned compiler package is available. The project targets Mojo
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

API modernization is now active. Ratatui `0.30.2` is the behavioral reference
for shared rendering concepts, not a source-compatibility target. The current
implementation proves feasibility, but its whole-buffer backend contract,
manual render loop, raw integer discriminants, resolved-only styles, and
order-based layout semantics must be corrected before the public core API is
treated as stable.

Stage A is implemented locally: `Terminal` now owns two reusable buffers,
prepares stable `Frame` transactions, centralizes changed-cell patches,
autoresizes, carries cursor intent, and commits only successful presentations.
The application runtime and dashboard use that path. Stage B is implemented
locally: public event, editor, layout, queue, style, and border semantic values
are nominal types, and absence uses `Optional` rather than public sentinels.
Twenty compile-fail fixtures guard those boundaries. Stage C is implemented:
composable style patches, underline colors, safe buffer and rich-text
conveniences, explicit overflow, and directly renderable text values are in
place. Stage D is implemented with Ratatui `0.30.2` fixtures, semantic
constraint priorities, margins, and all six non-legacy flex modes. Stage E is
implemented with word-wrapped/scrolled paragraphs, deeper blocks, multiline
lists and tables, selection policies, footers, and `Fill`; BarChart and Chart
are now implemented, while Canvas remains deliberately deferred. Stage F is implemented with startup
commands, default subscriptions, nominal exit control, adapter/application type
binding, embedded and POSIX terminal hosts, dashboard migration, PTY lifecycle
coverage, and documented API stability tiers.

Stage G is implemented locally on pinned stable Mojo `1.0.0`. Adapter batches
are retained losslessly across queue pressure, host turns have a finite message
budget, subscriptions reconcile after each batch, and `HostSchedule` separates
tick, Escape, frame, and adapter deadlines. Tick and resize messages coalesce
by stable key. Resize queries use the output descriptor, inline width follows
the terminal, and a split-descriptor PTY test covers that path. Rich-text spans
and selection states now carry `StylePatch`, while cells retain resolved
`Style`. Gauges use validated `Ratio`, scrollbars use validated symbol pairs,
and wrapping uses Unicode 17 whitespace data. Stage H is also
implemented locally: nominal capabilities, explicit profile fallbacks,
light/dark/unknown adaptive colors, conservative environment detection,
backend and terminal capability reporting, portable ANSI-16 output, dashboard
integration, and migration documentation are covered by the locked suite.
Stage I retains the existing extension commitments. Stage J is partially
implemented: BarChart, Chart, lazy `VirtualList` rendering, indexed collection
viewport jumps, and profiling benchmarks are shipped. Visible-line paragraph
layout, broader configuration depth, Canvas, and any additional frame
optimization remain gated work.

The editor application dogfood milestone is implemented locally. A complete
path-backed example now drives the non-copyable editor model through typed
messages and file effects. The integration exposed and corrected a rendering
boundary mismatch: `Application.view` remains read-only, while
`Editor.render_readonly` computes cursor visibility in frame-local viewport
data without copying the document or mutating the model. Focused headless and
PTY coverage gates editing, paste, history, file round trips, startup, exit,
and terminal restoration.

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

- Rust or Ratatui source compatibility
- Copying Rust ownership patterns when an explicit Mojo render transaction is
  clearer
- Windows support
- A networking runtime comparable to Tokio
- Python bindings
- Dynamic runtime widget plugins
- IDE completion, diagnostics, or language-server implementations
- General text-encoding conversion beyond UTF-8 integration hooks
- Arbitrary canvas drawing before symbol/capability contracts, or dynamically
  growing inline output
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

The pinned stable Mojo `1.0.0` release uses `def` as the standard function declaration
syntax. `fn` is deprecated upstream and is rejected by project policy and the
warnings-as-errors build. This project preserves the strict semantics formerly
associated with `fn`: arguments and returned values are statically typed,
fallibility is declared with `raises`, polymorphism uses trait-constrained
compile-time generics, compiler warnings are errors, and dynamic escape-hatch
types are prohibited from the library package. The machine-checked rules are
documented in [`TYPE_SAFETY.md`](TYPE_SAFETY.md).

### Stable language policy

- Pin stable Mojo `1.0.0` exactly in `pixi.toml`, `pixi.lock`, and the package
  recipe. Do not add a prerelease compiler lane or an unbounded dependency.
- Use `def` for functions, methods, closures, and function types. Do not add
  `fn`, including in examples or generated fixtures.
- Use explicit typed arguments and return types, `raises` for fallibility,
  `mut` for mutation, `var` only for ownership transfer, `out` for
  initialization, and `deinit` for consuming deinitialization.
- Prefer trait-constrained static generics and `comptime` control flow. Avoid
  dynamic erasure and private runtime/compiler APIs.
- Keep imports explicit. Mojo `1.0.0` rejects implicit intra-package access and
  combining same-named imported functions into an overload set.
- Prefer safe standard-library values and operations. Pointer and raw
  memory APIs are permitted only inside the audited platform boundary.
- Review the official stable release notes before each toolchain bump, run the
  complete locked check, and record any source migration in `docs/migration.md`.

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
- `Terminal` owns previous and current buffers and emits only changed cells.
- A `Frame` represents one stable render transaction. It exposes the prepared
  area, widget rendering, safe buffer access, and requested cursor state.
- The primary Mojo API uses explicit `begin_frame` and `finish_frame` ownership;
  a closure-based `draw` helper is optional when callable borrowing is proven
  ergonomic on the pinned compiler.
- Backends receive changed cells and terminal operations rather than owning a
  second copy of the renderer's complete frame.
- Later drawing replaces earlier drawing.
- Clear/opaque regions and explicitly skipped transparent cells support
  overlays without a general compositing engine.
- A frame is borrowed temporarily during one draw and is never retained.

### Unicode

- Strings remain UTF-8.
- Rendering and editing operate on extended grapheme clusters.
- Mojotui delegates terminal-width data to the versioned moji package, the
  ecosystem source of truth.
- Terminal width is always zero, one, or two cells for a rendered grapheme.
- Ambiguous-width behavior is configurable.
- Tests cover combining marks, CJK, emoji, ZWJ sequences, flags, variation
  selectors, tabs, controls, malformed input, and wide-cell replacement.
- Grapheme iteration must be linear; repeated indexed rescans are forbidden in
  hot paths.

### Terminal capabilities and adaptive colors

- `Color` remains a backend-independent, fully resolved cell value. Buffers,
  frame diffs, snapshots, and ANSI encoding never contain unresolved theme
  intent.
- Pure nominal values describe terminal color profile and background
  appearance. Invalid raw discriminants are rejected.
- `ProfiledColor` selects explicit monochrome, ANSI-16, ANSI-256, and truecolor
  fallbacks. `AdaptiveColor` selects light or dark alternatives before profile
  resolution.
- Resolution is deterministic and effect-free. It takes an explicit
  `TerminalCapabilities` value, performs no terminal query while rendering,
  and always returns an ordinary `Color`.
- Backends expose their configured capabilities. `HeadlessBackend` accepts an
  explicit value for deterministic theme tests; ANSI and inline backends use
  conservative environment detection unless the application overrides it.
- Capability precedence is explicit application override, safe detection,
  environment hints, then a documented ANSI-16/dark fallback. Detection never
  imports a private runtime API or broadens the unsafe boundary.
- A later optional OSC background query must be coordinated through the input
  reactor so its response cannot be mistaken for user input. It is not part of
  rendering and is never required for deterministic operation.

### Layout

The initial layout engine supports horizontal and vertical distribution with:

- fixed length
- minimum and maximum
- percentage
- ratio
- fill
- spacing
- alignment and flex distribution

Shared Ratatui constraint names must have compatible observable behavior for
priority, over-constrained allocation, rounding, spacing, and flex. A generated
golden corpus from Ratatui `0.30.2` defines that behavior. If the compact
allocator cannot meet the corpus without becoming misleading, it will be
renamed `StackLayout` and the compatible solver will own the `Layout` name.

CSS grid remains deferred until real applications demonstrate the need.

### Widget contracts

- Stateless widgets render from value data into an area.
- Stateful widgets receive explicit mutable state such as selection or scroll
  offset.
- Large widgets render only visible rows and columns.
- Rendering inherits a clipping rectangle.
- Widgets may register interaction regions in a frame-local `HitMap`.

## Terminal and event model

`TerminalSession` owns raw mode, alternate-screen state, cursor visibility,
bracketed paste, mouse capture, and restoration. Backends own their configured
capability value, while adaptive color resolution remains a pure core
operation. Normal return, reported errors, catchable failures, and Ctrl-C must
restore the terminal. Recovery from `SIGKILL` is impossible and will not be
promised.

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

## Ratatui-informed API modernization

The goal is a familiar mental model with Mojo-native ownership and static
dispatch. Compatibility is divided into three categories:

1. **Behavioral compatibility:** shared concepts such as constraints, style
   composition, widget layering, viewport preparation, and frame diffing should
   behave predictably for developers arriving from Ratatui.
2. **Naming compatibility:** established names such as `Frame`, `Widget`,
   `StatefulWidget`, `Paragraph`, `Layout`, `Constraint`, `Span`, `Line`, and
   `Text` are retained when their semantics match.
3. **Deliberate divergence:** Mojo ownership, explicit render transactions,
   checked fallibility, static generics, built-in typed application state, and
   the editor remain native Mojotui designs.

### API rules

- Public semantic states are not represented by arbitrary integers. Direction,
  alignment, flex, colors, key codes, mouse actions, borders, modifiers,
  command kinds, and result codes use nominal types or closed variants.
- Absence uses `Optional`; public `-1` sentinels are removed.
- Invalid configuration is unrepresentable when practical and otherwise
  rejected explicitly. Constructors do not silently change an invalid enum-like
  value into an unrelated default.
- `Style` composes. Unspecified foreground, background, underline, and modifier
  changes do not erase lower-level styling.
- Cells retain Mojotui's wide-grapheme invariant. Buffer convenience methods do
  not expose mutation that can orphan a continuation cell.
- Rendering is deterministic. A render transaction cannot query the terminal,
  execute effects, or retain a frame after presentation.
- Existing public APIs receive a documented migration path when removal is not
  required to prevent incorrect behavior.

### Modernization stages and gates

#### Stage A: frame and terminal ownership

- Add `Frame`, `CompletedFrame`, cursor intent, and explicit begin/finish
  transactions.
- Move previous/current buffers and diff responsibility into `Terminal`.
- Replace backend-specific resize calls in applications with terminal
  autoresize and stable frame areas.
- Give backends a changed-cell presentation contract plus clear, flush, cursor,
  size, and optional scrolling capabilities.
- Migrate `ApplicationRuntime`, examples, headless tests, ANSI golden tests, and
  documentation.

Exit: applications never allocate the root frame or reach through
`terminal.backend` during a normal render loop. Full, unchanged, changed,
resized, inline, fixed, cursor-visible, and cursor-hidden transactions have
focused tests. Existing PTY restoration tests still pass.

#### Stage B: semantic type strictness

- Replace public raw-integer tags and bit masks with nominal values or variants.
- Replace list/table selection sentinels with `Optional[UInt]`.
- Type message queue results, editor commands, key and mouse events, layout
  configuration, borders, modifiers, and wrap modes.

Exit: the static policy rejects new public enum-like `Int` fields, invalid
states have negative compile fixtures or raising constructors, and the full
suite contains no compatibility regression hidden by silent normalization.

#### Stage C: styles, cells, buffers, and text

- Add composable style patches with foreground, background, underline, and
  modifier add/remove semantics.
- Add safe string, span, line, style-region, resize, merge, and difference-sequence
  buffer operations.
- Make `Span`, `Line`, and `Text` directly renderable widgets and add concise
  raw/styled constructors, alignment, append, height, and patch operations.
- Define an explicit overflow policy so wrapping never silently loses a wide
  grapheme.

Exit: nested style tests preserve existing span attributes, wide-cell property
tests cover every convenience path, and simple text rendering no longer
requires nested manual constructors.

#### Stage D: layout compatibility

- Generate Ratatui `0.30.2` fixtures for all constraint kinds, over-constrained
  layouts, rounding, margins, spacing, and flex modes.
- Implement compatible priorities plus `SpaceAround` and `SpaceEvenly`, or
  publish the current allocator under a clearly different name.
- Add optional caching only after benchmarks show a repeated-layout benefit.

Exit: every shared `Layout` case matches the fixture corpus and all returned
rectangles remain contained, nonnegative, and deterministic.

#### Stage E: widget depth

- Add paragraph word wrapping, trim, scroll, and alignment.
- Add block border sets, asymmetric padding, multiple title positions, and safe
  border composition.
- Add multiline list items, scroll padding, table row heights, footer,
  row/column/cell selection, and highlight-spacing policies.
- Add `Fill`; add bar charts and charts after the dashboard demonstrates the
  core configuration APIs.

Exit: the existing widgets cover the common Ratatui configuration paths in
golden tests without compromising editor/form behavior.

#### Stage F: application host and ecosystem boundary

- Allow `Application.init` to return initial typed commands.
- Provide default empty subscriptions and explicit continue/exit control flow.
- Add a lifecycle-safe fullscreen and inline host that owns the session,
  terminal, reactor, parser, runtime, and adapter scope.
- The host polls and coordinates only; `RuntimeAdapter` remains responsible for
  general task execution.
- Document stable `core`, `text`, `widgets`, and `terminal` APIs separately from
  experimental `event`, `app`, `editor`, and `forms` APIs.

Exit: a complete typed application needs no hand-written terminal plumbing,
startup commands run through the adapter, all work is scoped on shutdown, and
the renderer remains independently usable.

#### Stage G: host correctness and compiler hardening

- Make adapter-to-host delivery lossless under queue pressure. A host must not
  destroy the unconsumed tail of a transferred completion batch.
- Add a finite work budget per host turn and reconcile subscriptions once after
  a processed batch. Sustained producers must not starve rendering.
- Separate application tick, input escape, frame, and runtime deadlines. Derive
  each reactor timeout from the nearest deadline so continuous input cannot
  starve ticks.
- Carry delivery policy with host-generated messages: keys and paste remain
  lossless, while tick and resize messages use stable latest-value keys.
- Query terminal dimensions from the output descriptor and define dynamic
  inline resize behavior. Cover distinct input/output descriptors with PTYs.
- Resolve widget styles by composing `StylePatch` values over inherited base
  styles. Selection and paragraph rendering must not erase span attributes.
- Replace silent normalization of invalid ratios and glyph sets with validated
  nominal values and raising construction.
- Pin or explicitly document Unicode whitespace behavior used by word wrapping.

Exit: oversized adapter batches are retained without loss, every host turn is
bounded, periodic ticks progress under continuous input, resize is correct with
separate descriptors and inline output, nested style tests retain prior
attributes, and the full stable-toolchain validation suite passes.

#### Stage H: adaptive capabilities and portable themes

- Add validated `ColorProfile`, `TerminalAppearance`, and
  `TerminalCapabilities` values in the rendering core.
- Add `ProfiledColor` and `AdaptiveColor` with deterministic resolution to a
  fully resolved `Color`. Include explicit light, dark, unknown-appearance,
  monochrome, ANSI-16, ANSI-256, and truecolor behavior.
- Expose capabilities from the backend contract and `Terminal`; make every
  built-in backend configurable, with a deterministic headless default.
- Add conservative environment detection without FFI. Explicit configuration
  must override detection, and malformed or contradictory hints must fall back
  safely.
- Exercise adaptive colors in the dashboard and document theme construction,
  backend configuration, limitations, and pre-1.0 migration.
- Add unit, compile-fail, ANSI, backend, and platform-environment coverage while
  retaining resolved cells and the existing unsafe allowlist.

Exit: applications can resolve one portable theme deterministically for
headless, monochrome, ANSI-16, ANSI-256, and truecolor targets; light/dark
selection is explicit and tested; backends report the configured capability
value; invalid semantic discriminants do not compile through unrelated raw
integers; and the complete locked check passes without new unsafe calls.

#### Stage I: extension foundation

- Separate the distribution into dependency-directed core, widgets, POSIX
  terminal, application, and editor packages, with a convenience package that
  re-exports the supported surface.
- Add public validated border, line, bar, scrollbar, shade, and braille symbol
  sets instead of hardcoding glyph choices inside individual widgets.
- Publish a headless extension test kit with buffer snapshots, stable golden
  output, wide-grapheme invariant helpers, and a third-party widget template.
- Adopt consistent Mojo-native `with_*` builders and evaluate a safe
  closure-based `Terminal.draw()` convenience over explicit frame
  transactions.
- Record differential fixture provenance using the published Ratatui tag,
  peeled commit, generator version, and corpus checksum.

Exit: a third-party widget can depend only on the rendering core, configure
symbols without copying widget internals, and test deterministic output without
private Mojotui helpers.

#### Stage J: widget depth and measured performance

The first measured slice is implemented. BarChart and Chart ship with semantic
tests, `VirtualList` constructs only visible rows, and indexed List/Table
viewport jumps avoid rescanning from row zero. Checked collection benchmarks
and profiler modes document startup, frame-time, and memory tradeoffs.

Remaining Stage J work will:

- deepen configuration coverage for existing widgets before adding another
  broad family;
- compose lazy visible-line paragraph layout where profiling demonstrates a
  benefit;
- defer Canvas until symbol merging, overlay semantics, and terminal
  capability negotiation are stable;
- Optimize frame preparation and diffing in measured layers: first use safe
  flat scalar traversal, eliminate unchanged-cell copies, and specialize
  invariant-preserving bulk fill; then evaluate compact numeric cell metadata
  before attempting SIMD.
- A SIMD path must compare exact semantic state or verify every possible
  collision, use only safe standard-library APIs, retain a scalar remainder,
  and beat the scalar path on full, one-cell, and unchanged frame benchmarks.
- GPU work is not part of core terminal diffing. Device dispatch and
  synchronization are reserved for a later optional high-resolution Canvas or
  image pipeline whose workload demonstrates an end-to-end benefit.
- Stream or reuse frame-diff scratch storage only when profiling shows a
  material gain without weakening the backend transaction contract.

Exit: common widgets cover their primary Ratatui configuration paths, data
visualization has stable symbol/style contracts, large text or collection
rendering remains proportional to the visible viewport, and retained render
optimizations have checked-in semantic coverage plus reproducible before/after
benchmarks on the pinned stable release.

#### Editor application dogfood milestone

- Add a borrowed-state editor rendering path compatible with the pure
  `Application.view` contract while retaining persistent viewport updates for
  callers of the mutable `StatefulWidget` path.
- Build a full-screen example around one non-copyable application model, a
  closed input/completion message variant, the default semantic keymap,
  transactional paste, history, and an application-owned clipboard.
- Represent load and save as typed effects interpreted by `RuntimeAdapter`.
  Preserve BOM and line endings, check external metadata, perform atomic
  replacement, and carry document versions through save completions.
- Keep the example adapter synchronous and replaceable. Do not bind the public
  editor or application API to a private or unstable task-runtime type.
- Add focused headless tests, build the executable in the locked suite, run it
  through a PTY, and document both interactive and deterministic test paths.

Exit: another developer can run a real editor with one Pixi command, inspect a
strictly typed application and effect boundary, edit and save a UTF-8 file,
and reproduce its headless and terminal-lifecycle tests without unsafe code
outside the existing audited platform layer.

## Delivery phases

### Phase 0: feasibility

Deliverables:

1. Pin the exact stable Mojo release in project configuration.
2. Add macOS and Linux environments and CI coverage.
3. Prove package, trait, ownership, test, and benchmark conventions.
4. Enter raw mode, query terminal size, read bytes, and restore state.
5. Multiplex stdin, resize, and a timer through POSIX polling.
6. Test restoration after success, errors, Ctrl-C, and task failure.
7. Attempt direct Mojo-to-libc `termios` integration.
8. Compare direct FFI with a minimal private C shim if ABI mapping is brittle.
9. Run one AsyncRT task without blocking terminal input.
10. Test cancellation or safe stale-result rejection and reactor wakeup.
11. Prove Unicode terminal-width lookup against the moji package.
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

### Phase 7: public API modernization

Execute Stages A through F above in order. This phase may make breaking changes
because the project is pre-1.0. Each stage must update examples, reference docs,
migration notes, compile-time API tests, benchmarks, and the limitations page
before the next stage treats its surface as stable.

### Phase 8: correctness and extension foundation

Execute Stages G through J in order. Correctness and bounded scheduling precede
package splitting or new widgets. Performance changes require a checked-in
benchmark and must not broaden the unsafe allowlist.

## Verification strategy

- Unit tests for pure data structures and algorithms
- Property tests for rectangles, layout allocation, clipping, buffer diffs,
  parsing, cursor motion, selections, and undo invariants
- Golden tests for cell grids and emitted ANSI bytes
- PTY integration tests for raw mode, resize, input, partial sequences, errors,
  Ctrl-C, and restoration
- Differential and conformance fixtures for Unicode width
- Differential fixtures generated from Ratatui `0.30.2` for layout and style
  behavior shared by name
- Compile fixtures proving nominal public types reject unrelated integer values
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

No source tag has been created. An untagged `0.1.0` Conda artifact was published
on 2026-08-21; `0.1.1` is the corrective first source-tagged release. Earlier
planning used release-like labels for capability checkpoints:

| Earlier label | Completed, unpublished capability |
| --- | --- |
| `0.1` | Rendering core, terminal backend, initial widgets, and dashboard |
| `0.2` | Application framework and reactor |
| `0.3` | Editor engine and editor widget |
| `0.4` | Forms, file services, and runtime-neutral adapter boundary |
| `0.5` | Frame transactions, terminal-owned rendering, nominal types, style composition, and layout compatibility |
| `0.6` | Deeper widgets, application host, and API stability tiers |
| `0.6.1` | Lossless host backpressure, bounded scheduling, resize correctness, and inherited style composition |
| `0.6.2` | Explicit terminal capabilities, portable themes, and deterministic color degradation |
| `0.6.3` | Interactive editor example, borrowed-state rendering, typed file effects, and editor PTY coverage |

The earlier `0.7` and `0.8` labels referred to Stage I and Stage J planning,
not published releases. The public targets below replace those labels.

`v0.1.1` packages the completed work above with exact compiler/dependency
metadata, bounded input, frame/session safety hardening, installed-subpackage
smoke tests, and coherent editor, fuzzy, and form workflows. The distribution
is one independently versioned `mojotui` library containing import namespaces
and a top-level convenience package; those namespaces are not separate release
artifacts.

Stage I is explicitly rescheduled to `v0.2.0`: dependency-directed public
packages, validated symbol families, headless extension testing, consistent
builders, reproducible Ratatui fixtures, and an external widget fixture remain
open. Version `0.1.1` does not claim those gates are complete.

Stage J started before `v0.1.1`: BarChart, Chart, lazy `VirtualList` rendering,
indexed collection viewport jumps, and their profiling benchmarks are shipped.
The remaining visible-paragraph, configuration-depth, Canvas, GPU, and any
benchmark-earned frame-optimization work follows the release gates.

Pre-1.0 minor releases may make breaking changes. Each release pins and names
one exact tested stable Mojo release and includes migration notes. The tagged source
archive is canonical. A precompiled package may be published only after its
recipe pins the compiler compatibility from `pixi.toml` and `pixi.lock` and
passes fresh-prefix consumer tests on every supported target.

For each source-tagged release, maintain a quick start, architecture overview,
dashboard tutorial, editor example, custom-widget guide, backend guide, API
documentation, terminal support matrix, and known-limitations page.

## Local release evidence

The 2026-08-22 `v0.1.1` release candidate on macOS ARM64 uses stable Mojo
`1.0.0`, Moji `0.1.0`, and Pixi `0.76.2`.

- `pixi run --locked check` passes 306 Mojo tests across 33 test modules and
  all 20 compile-fail fixtures.
- Eight examples build, and 15 PTY lifecycle cases pass, including overlapping
  raw-session rejection, retryable cleanup halves, partial host-initialization
  rollback, dirty-editor confirmation, and virtual-list navigation.
- The unsafe audit finds 10 documented FFI calls in one allowlisted platform
  file and none elsewhere.
- The local Conda package resolves exact public `mojo-compiler ==1.0.0` and
  `mojo-moji ==0.1.0` dependencies, precompiles with warnings as errors, passes
  its expanded installed-subpackage smoke, and passes exact artifact-metadata
  validation.
- Optimized symbolized profiles (`-O3 -g1`) and current timing evidence are
  recorded in `benchmarks/README.md`.

For historical context, the earlier PR #4 refresh recorded the following
pre-candidate baseline.

The 2026-08-22 macOS ARM64 PR #4 refresh used stable Mojo `1.0.0` and Pixi
`0.76.2` after merging `main` at `5a65cdf`.

- `pixi run check`: 280 Mojo tests passed across 32 test modules; 20
  compile-fail fixtures enforced nominal API boundaries.
- Seven examples built, and PTY tests passed normal close, implicit
  destruction, raised error, hosted inline application, Ctrl-C, resize, split
  descriptors, editor startup/quit, and virtual-list navigation cases.
- Formatting and README snippet checks passed; the package precompiled with
  `--Werror --warn-on-unstable-apis`; release-contract tests accepted the exact
  stable pin and rejected non-exact requirements.
- The strict-type policy found no obsolete `fn` declarations, `AnyType`, or
  `PythonObject` use in the library.
- The unsafe audit found nine documented FFI calls in one allowlisted platform
  file and none elsewhere.
- The Conda recipe pinned `mojo-compiler =1.0.0`; its package task built the
  precompiled library and runs an installed-package consumer smoke test.
- Current collection profiling evidence and reproduction commands live in
  `benchmarks/README.md`; this refresh does not relabel older toolchain timing
  samples as stable-`1.0.0` measurements.

The compiler distribution links against a newer macOS deployment target than
the local build target and emits linker warnings during executable builds. The
builds exit successfully. This toolchain warning is outside Mojotui source.

The CI workflow runs both the locked source suite and an isolated-source package
build with installed-package smoke and exact metadata validation on macOS ARM64,
Linux ARM64, and Linux x86-64. A separate tag workflow builds one canonical
source archive, repeats both matrices from that archive, and publishes only
after every target passes.

## Risk register

| Risk | Response |
| --- | --- |
| Mojo async APIs change | Keep stable APIs runtime-neutral; isolate the experimental adapter. |
| POSIX ABIs differ | Use a narrow audited boundary and allow a minimal C shim. |
| Dynamic trait objects are unavailable | Use static generics, immediate rendering, and closed variants. |
| Grapheme count differs from terminal width | Use moji's versioned width tables and conformance tests. |
| Compiler upgrades break source | Keep stable `1.0.0` exact and upgrade only through tested commits. |
| Editor scope delays usable rendering | Ship it as an independent later subsystem. |
| Terminal state leaks after failure | Use a session guard and PTY lifecycle tests. |
| Unsafe optimization spreads | Enforce a zero-default budget and an explicit allowlist in CI. |
| Familiar names have incompatible semantics | Require differential fixtures or use clearly different names. |
| Frame migration breaks applications | Keep one staged compatibility adapter, migration examples, and compile-time API tests. |
| A high-level host becomes an executor | Restrict it to polling and coordination; keep task execution behind `RuntimeAdapter`. |

## Definition of done

The planned project is complete when the renderer, POSIX terminal backend,
initial widgets, application framework, editor engine, file and clipboard
interfaces, and general Mojo runtime adapter meet their phase gates on macOS and
Linux; modernization Stages A through J meet their exit criteria; documentation
and migration material are sufficient for another developer to build an
application without backend-specific render plumbing; and all unsafe or FFI code
is confined to documented, tested, audited platform boundaries.
