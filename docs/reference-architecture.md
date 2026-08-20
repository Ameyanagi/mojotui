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
  logical frame state. Terminal devices cannot roll back bytes already written,
  so transport failures instead enter an explicit resynchronization state.

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

The terminal owns both reusable buffers, the backend, an opaque owner token,
frame generation, resize observation, cursor intent, and presentation. A
successful presentation moves the completed buffer into history. A rendering
or backend failure leaves logical history and generation unchanged. A backend
failure may have changed the physical device; the terminal records that state
as unknown and requires the next successful presentation to perform a full
resynchronizing redraw.

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
the batching property, not the command DSL: `Terminal` sends one ordered,
package-constructed `FramePatch` to a backend, and a successful `present()`
means the backend encoded, wrote, and flushed that complete patch. There is no
separate public backend `flush()` or `clear()` operation. `Terminal` expresses
clearing through a full-redraw patch. Raw mode, alternate screen, paste, focus,
mouse capture, and cursor restoration remain a `TerminalSession` concern.

### Incremental input behind an owned reactor

Crossterm separates semantic events from platform implementations and permits
polling before a read. MojoTUI keeps a pure incremental `InputParser` and an
owned POSIX reactor. Reads may end within an escape sequence or contain several
events. The parser retains incomplete bytes within validated `ParserLimits`;
the host injects Escape timeouts and EOF explicitly. Readiness and descriptor
errors stay in the platform-facing layer.

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
backend. A headless presentation validates and stages the complete patch before
swapping its observable surface, so even package-internal corruption fixtures
cannot expose a partial surface. Clocks, capabilities, terminal size, and
runtime completions remain injectable in application tests.

## Rejected or modified ideas

| Reference idea | MojoTUI decision |
| --- | --- |
| Rust lifetimes, boxed widgets, reference-widget variants, and runtime trait objects | Use Mojo ownership and trait-constrained static generics. Use an application-defined `Variant` only for a finite runtime choice. |
| Panicking buffer indices or diff preconditions | Public fallible operations raise; clipped rendering returns an explicit outcome where useful. Geometry and wide-cell invariants are validated at construction or mutation. |
| Ratatui backend methods for cursor, clearing, sizing, flushing, and terminal lifecycle | Keep the backend surface patch-oriented. `Terminal` owns diff, full-redraw/clear intent, cursor intent, and host-observed resize invalidation; successful `present()` includes transport flush. `TerminalSession` owns modes and restoration. |
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
core -----------> private unicode-policy adapter
text -----------> core + private unicode-policy adapter
widgets --------> core + text

private unicode-policy adapter -> generated Unicode 17 bootstrap tables
private unicode-policy adapter -> Moji after the parity gate

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

The graph has five hard properties:

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

The Unicode adapter is the only temporary ecosystem seam in this graph. In the
bootstrap release it combines Mojo's pinned standard-library grapheme iterator
with MojoTUI's checksum-pinned Unicode 17.0.0 width tables. The terminal chooses
one explicit ambiguous-width policy for a render path; cells and widgets do not
override it independently. Geometry and layout operate only in integer terminal
cell coordinates. Grapheme segmentation, display-width measurement, and text
index conversion belong to the text policy, not to geometry or widgets.

When Moji has a tagged, pure-Mojo grapheme/width API, the adapter changes to
import Moji. The dependency is `MojoTUI -> Moji`, never the reverse, and the
public `mojotui.text` facade remains stable. Adoption requires the same Unicode
version and ambiguous-width result over the checked-in pathological corpus,
source/checksum provenance, headless snapshots with no changes, and equivalent
buffer topology for every fixture. Until that parity gate passes, the private
tables are a documented bootstrap implementation rather than a second public
Unicode authority.

The distribution remains one `mojotui` artifact. Narrow package roots control
compile dependencies; they do not require separate Conda artifacts.

## Ownership, mutation, and errors

### Rendering ownership

- `Terminal[B]` is non-copyable and owns one concrete backend, two reusable
  buffers, an opaque owner token, a monotonically increasing generation, and a
  device-synchronization flag. Moving a terminal preserves that identity. Owner
  tokens come from one package-private, synchronized, overflow-checked process
  counter; live tokens are never reused, wraparound raises during construction,
  and token values are never exposed.
- `begin_frame()` observes one viewport and returns a movable frame tagged with
  the terminal's unforgeable owner token and current generation. Frame
  constructors and identity fields are package-controlled.
- More than one frame may be outstanding for the same owner and generation.
  The first one that presents successfully increments the generation; its
  siblings then fail as stale before diffing or backend mutation. A failed
  presentation does not increment the generation, so another same-generation
  frame remains eligible for a full-resynchronizing retry.
- Rendering mutates only that frame's buffer and optional cursor intent. A frame
  may be moved or retained until completion, but `finish_frame(frame^)` consumes
  it exactly once and accepts it only at its originating terminal.
- `Cell`, `Buffer`, `Frame`, and `FramePatch` expose behavior and read-only
  inspection rather than caller-mutable representation. `FramePatch` has no
  public constructor. Third-party backends receive a synchronous read-only
  borrow and must not retain it or call back into its `Terminal`.
- Package-controlled construction never relies on a public `_validated` flag or
  ignored sentinel. Internal constructors require an unexported nominal token.
  Where the pinned Mojo compiler cannot enforce field visibility, completion
  treats reachable representation as hostile and revalidates it; compile-only
  consumer fixtures record exactly which access the compiler rejects.
- Before producing a patch, `finish_frame(frame^)` validates owner, generation,
  viewport, cursor, buffer shape, area arithmetic, every cell and resolved
  style, and the complete wide-cell topology. Width and height are non-negative,
  their product cannot overflow, and the cell count equals that product. A
  leader contains exactly one grapheme whose policy-derived width is one or two;
  zero-width input is combined or rejected by the text facade rather than stored
  as a leader. A two-column leader is followed by one same-style empty
  width-zero continuation inside the row, and no continuation is orphaned. A
  resolved style contains only declared modifier bits and valid default,
  indexed, or bounded RGB color payloads; unresolved `StylePatch` state never
  reaches a cell.
- The package-generated patch is validated before presentation: its area is the
  current viewport; cursor and changes are in bounds; changes are strictly
  row-major and unique; no continuation is emitted independently; and a wide
  leader's footprint fits. A full-redraw patch means reset the complete viewport
  to blank/default state, apply its ordered cells that differ from a default
  blank (including styled blanks), then apply cursor intent.
- All predictable validation failures occur before the backend is called and
  leave frame history, generation, reusable buffers, cursor intent, backend
  state, and the physical device untouched.
- `Terminal`, its backend, and a frame completion are single-owner and
  non-reentrant. Exclusive `mut` calls serialize viewport observation,
  presentation, and history mutation; none of these types promises thread
  safety.
- Production backends own transport state rather than another full rendering
  buffer. `HeadlessBackend` deliberately owns an observable in-memory surface
  for tests, exposed only through copies or read-only accessors.

### Logical and device atomicity

- A successful backend `present()` has validated, encoded, written, and flushed
  the whole patch. Only then does `Terminal` swap history and increment its
  generation.
- A runtime write or flush failure can leave an unknowable byte prefix on the
  terminal. MojoTUI guarantees logical atomicity, not rollback of physical
  output: history and generation remain unchanged, while the terminal marks the
  device unknown and forces the next presentation to be a full redraw. For a
  minimal raising-only backend contract, every `present()` error takes this safe
  path even if the concrete backend knows it failed before its first write.
- A full redraw is a resynchronization operation. Concrete terminal backends
  emit an unconditional reset/clear/home baseline and do not trust cached cursor
  or first-frame state. They publish new transport bookkeeping only after the
  complete output flush succeeds.
- If resynchronization also fails, the device remains unknown and the call
  raises. Later calls may retry; the terminal is not permanently poisoned.
  Session teardown remains available regardless of synchronization state.
- Backends perform every predictable patch, descriptor, capability, and encoding
  check before their first write. Documentation for an unexpected runtime
  failure states that the physical cursor, style, and visible cells are
  unspecified until a full redraw succeeds.

### Terminal session lease

- `TerminalSession` is a non-copyable movable exclusive lease over terminal
  modes. It owns state transitions and saved mode data, not the supplied input
  and output descriptors. Descriptors are borrowed, are never closed by the
  session, and must remain valid until the session, backend, and reactor finish.
- A package-owned lease registry uses terminal device identity, not merely the
  descriptor integer, to reject a second live MojoTUI session for the same TTY.
  This registry contains no raw-mode snapshot. External processes cannot be
  excluded, so embedders must also prevent unrelated mode changes and writes.
- The session is the only owner of feature enter/leave sequences. The backend is
  the only writer during active rendering, and the reactor is the only reader.
  Split input/output descriptors are supported only when both pass their
  documented TTY validation and lifetime requirements.
- Construction acquires the lease and captures all restoration data before its
  first mutation. If raw-mode application or any enter write/flush fails, it
  attempts every applicable inverse step in reverse order, releases the lease
  only after recording cleanup state, and raises the primary error with stable
  cleanup context.
- `close()` attempts every still-required leave, cursor/style reset, flush, and
  terminal-mode restoration step even when an earlier step fails. It is
  idempotent after complete success. After partial cleanup it retains enough
  state for a retry and raises deterministically; destruction retries remaining
  steps best-effort and finally releases the in-process lease.
- Nested or overlapping sessions on the same TTY are rejected. Interrupt and
  normal application-host paths call `close()` explicitly; destructors are a
  last-resort non-raising fallback, not the primary signal-handling mechanism.

### Parser and reactor ownership

- `ParserLimits` validates finite positive bounds for one supplied feed batch,
  an unclassified terminal sequence, and bracketed-paste content. Defaults are
  part of the compatibility contract; there is no unlimited mode in v0.1.
- `InputParser` is movable, non-copyable, single-owner, and non-reentrant. It
  owns only buffered bytes and parser state. `feed(bytes^)` accepts owned bytes;
  it never owns a descriptor or clock.
- The host owns the clock. When the configured deadline expires it calls
  `on_escape_timeout()`, which deterministically resolves one leading Escape and
  resumes parsing the remaining bytes.
- `finish_eof()` parses every complete event, resolves a bare Escape, and raises
  a truncation error for an incomplete UTF-8, control, or paste sequence. A
  successful EOF finalizes the parser; later calls raise a closed-parser error.
  Truncation and limit errors clear retained input and poison that parser
  instance; callers construct a new parser before consuming more bytes.
- Crossing any parser limit raises before retaining the byte that exceeds the
  bound, clears all partial state, and poisons the parser. No event list is
  returned from that call. This makes application-host behavior explicit: input
  overflow is a terminal input failure, not silent truncation or an unbounded
  allocation.
- A POSIX reactor borrows descriptors for its lifetime and owns readiness state,
  not descriptor closure. One host serializes reactor reads, parser calls, model
  updates, and backend writes; concurrent reads or calls back into the parser are
  outside the contract.

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
  Presentation errors additionally require the device resynchronization policy
  above; they do not promise rollback of already written terminal bytes.
- `TerminalSession.close()` is explicit and raising. Destruction performs only
  best-effort restoration; PTY tests prove normal, error, interrupt, and
  implicit-cleanup paths.
- Internal parser incompleteness is state, not an error. Complete unsupported
  input becomes a typed unknown event; EOF truncation, resource-limit overflow,
  and descriptor failures raise under the policies above.

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


struct FramePatch(Movable):
    # Package-constructed; backends receive read-only access only.
    def area(self) -> Rect: ...
    def is_full_redraw(self) -> Bool: ...
    def cursor(self) -> Optional[Point]: ...
    def change_count(self) -> Int: ...
    def change(self, index: Int) raises -> CellChange: ...


trait Backend(Deinitable, Movable):
    def capabilities(self) -> TerminalCapabilities: ...
    def viewport(mut self) raises -> Rect: ...
    # Success includes encoding, writing, and flushing the complete patch.
    def present(mut self, patch: FramePatch) raises: ...


struct Terminal[B: Backend](Movable):
    def begin_frame(mut self) raises -> Frame: ...
    def finish_frame(mut self, var frame: Frame) raises -> CompletedFrame: ...
    def invalidate(mut self): ...
    def clear(mut self) raises -> CompletedFrame: ...


struct ParserLimits(Copyable):
    def __init__(
        out self,
        max_feed_bytes: Int = 65_536,
        max_sequence_bytes: Int = 4_096,
        max_paste_bytes: Int = 1_048_576,
    ) raises: ...

    @staticmethod
    def default() -> Self: ...


struct InputParser(Movable):
    def __init__(out self): ...
    def __init__(out self, limits: ParserLimits): ...
    def feed(mut self, var bytes: List[UInt8]) raises -> List[InputEvent]: ...
    def on_escape_timeout(mut self) raises -> List[InputEvent]: ...
    def finish_eof(mut self) raises -> List[InputEvent]: ...
```

A caller renders without an application framework:

```mojo
var terminal = Terminal(HeadlessBackend(Rect(0, 0, 80, 24)))
var frame = terminal.begin_frame()
frame.render_widget(widget, frame.area())
var completed = terminal.finish_frame(frame^)
```

`Terminal.clear()` is a terminal-owned empty full redraw, not a direct backend
escape hatch. `invalidate()` only marks the next completed frame as a full
redraw. Multiple frames returned before a successful completion share a
generation; after one commits, completing any sibling raises a stale-frame error
without calling the backend.

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
- Add package-internal corruption fixtures for buffer-length/area mismatch,
  invalid style and width values, orphan/duplicate continuations, a wide leader
  at the row edge, out-of-bounds cursor, and unordered, duplicate, or
  out-of-bounds patch changes. Every failure must precede backend or headless
  surface mutation.
- Prove terminal identity with two equal-view, equal-generation terminals: a
  frame from one must fail at the other. Prove same-generation semantics with
  two outstanding frames: the first successful completion wins, a sibling is
  stale after that commit, and a sibling remains eligible after a failed
  presentation.
- Add a fault-injecting backend that raises before output and after each of the
  first N encoded operations. Assert that logical history, reusable buffers,
  cursor intent, and generation remain unchanged; device state becomes unknown;
  and the next successful presentation is an unconditional full resync. A
  failed resync remains retryable.
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
- Exercise parser input exactly at and one byte beyond every configured limit.
  Verify poisoning and cleared retained state after overflow, explicit Escape
  timeout behavior, bare-Escape EOF, and truncation errors for incomplete UTF-8,
  CSI, and bracketed paste.
- Keep byte-exact ANSI and inline backend fixtures separate from PTY lifecycle
  tests.
- Exercise normal return, raised render/update/backend errors, Ctrl-C, resize,
  split input/output descriptors, and best-effort cleanup through PTYs.
- Inject failure after raw-mode entry, during enter output, during each leave
  step, and during termios restoration. Verify every applicable cleanup action
  is attempted, retry state is retained, borrowed descriptors remain open,
  repeated successful close is harmless, and a nested same-TTY session is
  rejected.

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
  moved frames, public Frame/FramePatch construction, direct invariant-field
  mutation, and private imports where the compiler can express the boundary.
- Run the headless consumer fixture without importing or linking the POSIX
  boundary.
- Keep one checksum-pinned Unicode 17 parity corpus shared by the private
  adapter and the future Moji gate. It covers combining marks, variation
  selectors, ZWJ emoji, regional indicators, ambiguous-width characters, CJK,
  clipping, and wide-cell replacement without snapshot drift.

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
   and the public text facade. Freeze the Unicode 17.0.0 bootstrap policy and
   the MojoTUI-to-Moji parity gate there. This makes the Ratatui-like core
   boundary real without duplicating Unicode data inside MojoTUI or creating a
   reverse dependency from Moji.
3. **MTUI-102 in parallel:** put `Backend`, `FramePatch`, `Terminal`, and
   `HeadlessBackend` in the headless boundary. Move descriptors, sessions,
   environment detection, ANSI transports, and inline terminal ownership
   outward. Its scoped child work freezes opaque frame identity, immutable patch
   inspection, same-generation completion, complete invariant validation,
   fail-after-N resynchronization, the reduced backend trait, the exclusive
   session lease, and bounded parser/EOF behavior before the boundary is called
   stable.
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
