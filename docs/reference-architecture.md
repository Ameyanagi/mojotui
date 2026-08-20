# MojoTUI reference architecture

This document records source research for the v0.1 package-boundary work. It
feeds MTUI-002 through MTUI-206 in the
[execution plan](v0.1-execution-plan.md); it does not replace
[ARCHITECTURE.md](../ARCHITECTURE.md) or define Rust or Go compatibility.

The references are development inputs only. MojoTUI copies no source, vendors
no reference package, and adds no runtime dependency from this research.

## Goals

- Keep headless rendering independently importable and free of terminal I/O.
- Make a frame one explicit transaction owned by `Terminal`.
- Preserve deterministic cell, Unicode-width, style, layout, and diff behavior.
- Keep terminal sessions, event readiness, and platform calls in outward
  effectful layers.
- Give third-party widgets a small, statically dispatched Mojo API.
- Keep one application loop as the sole owner of model mutation.
- Make failures observable without panics, sentinels, or partially committed
  frames.

## Non-goals

- Rust, Ratatui, Crossterm, Bubble Tea, or Elm source compatibility
- Vendored source, generated bindings, or a runtime dependency on a reference
- Runtime-erased widget, backend, message, effect, or application objects
- A public terminal-command DSL mirroring Crossterm
- Bubble Tea's goroutine scheduler or a second general-purpose task runtime
- Windows terminal support in v0.1
- A general constraint solver, global layout cache, negative spacing, or
  overlapping layout regions
- Escape-sequence payloads or forced display widths stored in ordinary cells

## Pinned references

The local clones are shallow, detached checkouts under
`/Users/ryuichi/dev/reference-libraries/mojotui/`. Commit links below are
immutable primary-source links.

| Reference | Pin and license | Role | Inspected modules and APIs |
| --- | --- | --- | --- |
| [Ratatui](https://github.com/ratatui/ratatui/tree/e665c36cb14752a61cd777fbd06dbef8474f2add) | `ratatui-v0.30.2`, peeled commit `e665c36cb14752a61cd777fbd06dbef8474f2add`, [MIT](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/LICENSE) | Immediate rendering, frame ownership, layout, extension seams | [`ratatui-core`](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/lib.rs), [`BufferDiff`](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/buffer/diff.rs), [`Terminal::try_draw`](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/terminal/render.rs), [`Frame`](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/terminal/frame.rs), [`Widget`](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/widgets/widget.rs), [`StatefulWidget`](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/widgets/stateful_widget.rs), [`TestBackend`](https://github.com/ratatui/ratatui/blob/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/backend/test.rs), [`symbols`](https://github.com/ratatui/ratatui/tree/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/symbols), and [`layout`](https://github.com/ratatui/ratatui/tree/e665c36cb14752a61cd777fbd06dbef8474f2add/ratatui-core/src/layout) |
| [Crossterm](https://github.com/crossterm-rs/crossterm/tree/36d95b26a26e64b0f8c12edfe11f410a6d56a812) | `0.29`, commit `36d95b26a26e64b0f8c12edfe11f410a6d56a812`, [MIT](https://github.com/crossterm-rs/crossterm/blob/36d95b26a26e64b0f8c12edfe11f410a6d56a812/LICENSE) | Terminal commands, raw mode, event parsing and platform isolation | [`Command`, queue, and execute](https://github.com/crossterm-rs/crossterm/blob/36d95b26a26e64b0f8c12edfe11f410a6d56a812/src/command.rs), [`Event`, `poll`, and `read`](https://github.com/crossterm-rs/crossterm/blob/36d95b26a26e64b0f8c12edfe11f410a6d56a812/src/event.rs), [`terminal`](https://github.com/crossterm-rs/crossterm/blob/36d95b26a26e64b0f8c12edfe11f410a6d56a812/src/terminal.rs), and the private [Unix terminal boundary](https://github.com/crossterm-rs/crossterm/blob/36d95b26a26e64b0f8c12edfe11f410a6d56a812/src/terminal/sys/unix.rs) |
| [Bubble Tea](https://github.com/charmbracelet/bubbletea/tree/73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290) | `v2.0.9`, peeled commit `73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290`, [MIT](https://github.com/charmbracelet/bubbletea/blob/73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290/LICENSE) | Sequential model/update flow, commands, host lifecycle | [`Model`, `Cmd`, `Program`, and event loop](https://github.com/charmbracelet/bubbletea/blob/73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290/tea.go), [`Batch` and `Sequence`](https://github.com/charmbracelet/bubbletea/blob/73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290/commands.go), injected [program options](https://github.com/charmbracelet/bubbletea/blob/73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290/options.go), the [renderer boundary](https://github.com/charmbracelet/bubbletea/blob/73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290/renderer.go), and [program-loop tests](https://github.com/charmbracelet/bubbletea/blob/73b6d91ac1c3854dd4af046ab5f9e51d3b3b4290/tea_test.go) |

Ratatui `0.30.2` declares Crossterm `0.29`, so those two checkouts describe a
coherent renderer/backend boundary. Bubble Tea is independent and informs only
the application-host layer.

## Adopted ideas

### Immediate, complete frames

Ratatui asks the view to render the complete current frame, then compares it
with the prior frame. MojoTUI keeps that behavior. A widget writes only into the
borrowed frame or buffer it receives; it does not retain a rendering context or
perform terminal I/O.

The terminal owns both buffers, the backend, frame generation, resize
observation, cursor intent, and presentation. A successful presentation moves
the completed buffer into history. A rendering or backend failure leaves
history and generation unchanged.

### Narrow extension contracts

Ratatui's core crate gives widget authors geometry, buffers, styles, text,
layout, widget traits, and a test backend without requiring an application
framework. MojoTUI should provide the same narrow capability inside one Mojo
distribution. `Widget` and `StatefulWidget` remain static traits; mutable widget
state remains caller-owned.

Ratatui's public symbol families support customization without replacing whole
widgets. MojoTUI should expose independently designed, validated symbol values
after the package boundary is stable.

### Batched terminal presentation

Crossterm distinguishes queued commands from an explicit flush. MojoTUI adopts
the batching property, not the command DSL: `Terminal` sends one ordered
`FramePatch` to a backend, and the backend owns encoding and transport flushes.
Raw mode, alternate screen, paste, focus, mouse capture, cursor restoration,
and descriptor ownership remain a `TerminalSession` concern.

### Incremental input behind an owned reactor

Crossterm separates semantic events from platform implementations and permits
polling before a read. MojoTUI keeps a pure incremental `InputParser` and an
owned POSIX reactor. Reads may end within an escape sequence or contain several
events. The parser retains incomplete bytes; readiness and descriptor errors
stay in the platform-facing layer.

### Sequential application state and typed effects

Bubble Tea's useful invariant is one central update loop: input and completed
work become messages, one update changes the model, and commands return future
messages. MojoTUI keeps that direction with compile-time associated
`Model`, `Message`, and `Effect` types. Runtime adapters execute work; the host
coordinates finite turns and never lends the model to a producer.

### Headless tests as a public extension tool

Ratatui's `TestBackend` and Bubble Tea's injected input, output, size, and
environment show the value of deterministic seams. MojoTUI should expose
stable snapshot formatting and cell-invariant assertions over its headless
backend. Clocks, capabilities, terminal size, and runtime completions remain
injectable in application tests.

## Rejected or modified ideas

| Reference idea | MojoTUI decision |
| --- | --- |
| Rust lifetimes, boxed widgets, reference-widget variants, and runtime trait objects | Use Mojo ownership and trait-constrained static generics. Use an application-defined `Variant` only for a finite runtime choice. |
| Panicking buffer indices or diff preconditions | Public fallible operations raise; clipped rendering returns an explicit outcome where useful. Geometry and wide-cell invariants are validated at construction or mutation. |
| Ratatui backend methods for cursor, clearing, sizing, and terminal lifecycle | Keep the backend surface patch-oriented. `Terminal` owns diff and cursor intent; `TerminalSession` owns modes and restoration. |
| Ratatui cell escape payloads, forced widths, and general diff-skip controls | Keep ordinary cells to validated graphemes, width, continuation state, and resolved style. Add escape-aware cells only through a separate proposal with invariants and tests. |
| Crossterm's process-global event reader and process-global raw-mode snapshot | Use instance-owned `InputParser`, `PosixReactor`, and `TerminalSession` values so tests and embedded hosts have explicit ownership. |
| Crossterm's public command vocabulary | Keep ANSI encoding private to concrete backends. Applications render cells and request typed session capabilities. |
| Bubble Tea's dynamically typed messages and interface-valued model | Bind one application, model, message, and effect family at compile time. |
| Bubble Tea's command closures and goroutine-per-command execution | Keep execution behind `RuntimeAdapter`, with scoped cancellation, retained completions, backpressure, and bounded host turns. |
| Bubble Tea views as ANSI strings that also select terminal modes | Render typed cells into a borrowed buffer. Configure session modes outside `view`; resolve capabilities before writing cells. |
| Time-based tests and sleep-driven interactive assertions | Inject a clock and use headless, byte-exact, or PTY fixtures with observable completion gates. |
| A closure-based draw API as the only render path | Keep `begin_frame()` / `finish_frame()` canonical. Add `draw()` only if MTUI-205 proves Mojo's borrow ends before presentation and a raised callback cannot commit. |

## Target layers and dependency direction

In this graph, `A -> B` means package A may import package B. Names are logical
boundaries; MTUI-002 owns their final Mojo import spelling.

```text
core -----------> private unicode-width kernel
text -----------> core + private unicode-width kernel
widgets --------> core + text

terminal-core --> core
terminal-posix -> terminal-core + private POSIX boundary
event-parser ---> standard library only
event-posix ----> event-parser + core + private POSIX boundary

app-core -------> core + terminal-core + event-parser
app-posix ------> app-core + terminal-posix + event-posix

editor-engine -------> core + text
editor-widget -------> editor-engine + widgets
editor-controllers --> editor-engine + event-parser + app-core
editor-file-service -> editor-engine + private POSIX boundary
forms ---------------> editor-widget + widgets

mojotui convenience root -> all supported public packages
```

The graph has four hard properties:

1. `core`, `text`, `widgets`, and `terminal-core` import no POSIX module.
2. `terminal-core` owns `Backend`, `FramePatch`, `Frame`, `Terminal`, and
   `HeadlessBackend`; terminal descriptors and session modes live outward.
3. The input parser accepts bytes without owning a descriptor. POSIX readiness
   and reads live outward.
4. `app-core` hosts injected backends and runtimes. The terminal-owning POSIX
   host is an outward adapter rather than a reason to import platform code into
   the application contract.
5. The application and editor layers depend inward. No foundation package
   imports them.

The distribution remains one `mojotui` artifact. Narrow package roots control
compile dependencies; they do not require separate Conda artifacts.

## Ownership, mutation, and errors

### Rendering ownership

- `Terminal[B]` owns one concrete backend and two reusable buffers.
- `begin_frame()` observes one viewport and returns a movable frame tagged with
  the current generation.
- Rendering mutates only that frame's buffer and optional cursor intent.
- `finish_frame(frame^)` checks generation, viewport, cursor, and cell
  invariants, presents one patch, then swaps history.
- A frame cannot be retained, reused, or finished by another terminal.
- Production backends own transport state rather than another full rendering
  buffer. `HeadlessBackend` deliberately owns an observable in-memory surface
  for tests.

### Application ownership

- One sequential loop owns the model.
- `update` receives one owned message and returns typed commands plus redraw and
  control-flow decisions.
- Stateful widget state belongs to the application and is passed explicitly.
- Runtime work receives owned effect data and returns owned messages. It never
  borrows the model or a frame.
- Lossless messages apply backpressure. Coalescing requires a stable non-empty
  key and is reserved for latest-value observations such as resize and tick.

### Error rules

- Invalid public configuration is rejected by a raising constructor or
  represented by a nominal type.
- Expected absence uses `Optional`; it does not use a raw integer or empty
  string sentinel.
- Pure rendering should be non-raising after validated construction where the
  compiler permits it. Bounds inspection, allocation, parsing, I/O, and backend
  presentation may raise explicitly.
- A view or presentation error commits neither buffer history nor frame count.
- `TerminalSession.close()` is explicit and raising. Destruction performs only
  best-effort restoration; PTY tests prove normal, error, interrupt, and
  implicit-cleanup paths.
- Internal parser incompleteness is state, not an error. Complete unsupported
  input becomes a typed unknown event; descriptor failures raise.

## Minimal Mojo public API sketch

The public core should stay close to these contracts:

```mojo
trait Widget:
    def render(self, area: Rect, mut buffer: Buffer): ...


trait StatefulWidget:
    comptime State: Deinitable & Movable

    def render(
        self,
        area: Rect,
        mut buffer: Buffer,
        mut state: Self.State,
    ) raises:
        ...


trait Backend(Deinitable, Movable):
    def viewport(mut self) raises -> Rect: ...
    def present(mut self, patch: FramePatch) raises: ...
    def clear(mut self) raises: ...
    def flush(mut self) raises: ...


struct Terminal[B: Backend](Movable):
    def begin_frame(mut self) raises -> Frame: ...
    def finish_frame(mut self, var frame: Frame) raises -> CompletedFrame: ...
```

A caller renders without an application framework:

```mojo
var terminal = Terminal(HeadlessBackend(Rect(0, 0, 80, 24)))
var frame = terminal.begin_frame()
frame.render_widget(widget, frame.area())
var completed = terminal.finish_frame(frame^)
```

The optional application layer adds one statically bound contract:

```mojo
trait Application(Deinitable, Movable):
    comptime Model: Deinitable & Movable
    comptime Message: Deinitable & Movable
    comptime Effect: Deinitable & Movable

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]: ...
    def update(
        mut self,
        mut model: Self.Model,
        var message: Self.Message,
    ) raises -> UpdateResult[Self.Effect]: ...
    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises: ...
```

Narrow consumers import these names from their owning subpackage. The
`mojotui` root may re-export supported conveniences, but it is not the source of
truth for ownership or dependency direction.

## Testing implications

### Pure and headless layers

- Keep unit and property tests for geometry, clipping, layout, styles,
  grapheme width, wide leader/continuation repair, and row-major diffs.
- Add a fault-injecting backend that raises before presentation completes.
  Assert that the terminal's previous frame, reusable buffer, cursor intent,
  and generation remain unchanged.
- Publish deterministic snapshot formatting and invariant assertions through
  the MTUI-203 test-support package.
- Compile a third-party widget fixture using only public core, text, symbol,
  and test-support imports.
- Regenerate layout compatibility fixtures from the pinned Ratatui commit and
  retain inputs, generator version, license, and checksum.

### Terminal and event layers

- Test the parser with every meaningful split point in escape, UTF-8, mouse,
  focus, and bracketed-paste sequences.
- Keep descriptor readiness, resize, hangup, interruption, and error tests at
  the POSIX boundary.
- Keep byte-exact ANSI and inline backend fixtures separate from PTY lifecycle
  tests.
- Exercise normal return, raised render/update/backend errors, Ctrl-C, resize,
  split input/output descriptors, and best-effort cleanup through PTYs.

### Application layer

- Inject clocks, runtime completions, capabilities, and viewport sizes.
- Test message ordering, startup commands, subscription reconciliation,
  cancellation generations, backpressure, coalescing keys, and finite turn
  budgets without sleeping.
- Keep a small end-to-end PTY example, but do not make PTY timing the only
  proof of application semantics.

### Public boundaries

- Add import-only and compile/run fixtures for every supported subpackage.
- Keep compile-fail fixtures for dynamic erasure, invalid nominal values,
  moved frames, and private imports where the compiler can express the
  boundary.
- Run the headless consumer fixture without importing or linking the POSIX
  boundary.

## Benchmark implications

Benchmarks remain methodology, not comparative claims. Record compiler, target,
CPU, OS, optimization flags, warmup, iterations, and medians.

- Split render, diff, ANSI encode, and transport costs so one layer does not
  hide another.
- Retain full-frame, one-cell-change, and unchanged 80x24 cases.
- Add wide-grapheme replacement and resize cases because they exercise diff
  correctness work absent from ASCII-only frames.
- Measure parser batches across one-byte, typical terminal-read, and large
  paste chunks.
- Measure host turns with empty, lossless-backlog, and coalesced-resize queues;
  assert finite work separately from elapsed time.
- Compare changes with at least five interleaved baseline/candidate runs on the
  same host. CI reports results without cross-machine pass/fail thresholds.

Reference benchmark harnesses are not copied. MojoTUI's checked-in benchmarks
must call its public or deliberately internal measurement seams directly.

## Issue-order consequences

The research does not add a parallel roadmap. It sharpens the current order:

1. **MTUI-002 first:** encode the logical graph above and name temporary
   violations. It must also decide whether `app-core` / `app-posix` are nested
   public roots or an internal split behind one public `app` root. A package
   move without the executable graph can recreate a cycle under a new name.
2. **MTUI-101 next:** move terminal width into one private leaf used by `Cell`
   and the public text facade. This makes the Ratatui-like core boundary real
   without duplicating Unicode data.
3. **MTUI-102 in parallel:** put `Backend`, `FramePatch`, `Terminal`, and
   `HeadlessBackend` in the headless boundary. Move descriptors, sessions,
   environment detection, ANSI transports, and inline terminal ownership
   outward. Add the fault-injecting transaction test in this issue.
4. **MTUI-103 in parallel:** preserve Bubble Tea's useful unidirectional flow
   while separating editor data from widget, controller, clipboard, and file
   effects. Do not introduce a second executor.
5. **Split the host before MTUI-104 if MTUI-002 adopts the nested app roots:**
   keep injected `ApplicationHost` in `app-core` and move the session-owning
   host to the outward POSIX adapter. This is a structural child issue, not an
   application feature milestone.
6. **MTUI-104 before extensions:** compile narrow consumers and audit the root.
   The reference matrix does not justify exporting internal adapters or
   platform values.
7. **MTUI-201 then MTUI-202:** define validated symbol families independently,
   then migrate widgets without changing default snapshots.
8. **MTUI-203 before MTUI-204:** stabilize headless snapshots and invariants
   before publishing the third-party widget template.
9. **MTUI-205 remains an experiment:** Ratatui demonstrates the desired atomic
   callback behavior, but Mojo's ownership proof decides whether `draw()` is
   viable. Explicit frame transfer stays canonical until that proof compiles.
10. **MTUI-206 stays pinned:** regenerate layout data from the Ratatui commit in
   this document, with no Ratatui runtime or source dependency.
11. **MTUI-301 and MTUI-302 enforce the result:** installed headless consumers
    must compile without POSIX, and platform consumers must pass on all declared
    targets.

Bubble Tea does not justify new v0.1 application features. The existing typed
host already improves on the reference where MojoTUI needs stronger static
binding, cancellation, and fairness. Finish the dependency boundary before
expanding the host.

## Reproduction record

The research checkouts were created with:

```sh
git clone --depth 1 --branch ratatui-v0.30.2 \
  https://github.com/ratatui/ratatui.git \
  /Users/ryuichi/dev/reference-libraries/mojotui/ratatui
git clone --depth 1 --branch 0.29 \
  https://github.com/crossterm-rs/crossterm.git \
  /Users/ryuichi/dev/reference-libraries/mojotui/crossterm
git clone --depth 1 --branch v2.0.9 \
  https://github.com/charmbracelet/bubbletea.git \
  /Users/ryuichi/dev/reference-libraries/mojotui/bubbletea
```

Verify each pin with `git -C <path> rev-parse HEAD` and its license with the
checked-out `LICENSE` file. The clones are evidence directories, not repository
inputs, and are intentionally absent from MojoTUI's source tree.
