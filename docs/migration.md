# Pre-1.0 API migrations

Mojotui is still pre-1.0, so the modernization work described in
[`PLAN.md`](../PLAN.md) can make intentional breaking changes. This page keeps
the mechanical migrations in one place.

## Terminal-owned render transactions

Applications no longer allocate the root `Buffer` and ask a backend to compare
complete frames. Replace the old loop:

```mojo
var area = terminal.viewport()
var buffer = Buffer(area)
view(area, buffer)
terminal.present(buffer)
```

with a terminal-owned transaction:

```mojo
var frame = terminal.begin_frame()
view(frame.area(), frame.buffer)
var completed = terminal.finish_frame(frame^)
```

`begin_frame()` observes resize and returns a blank immediate-mode frame.
`finish_frame()` centralizes diffing, presents a `FramePatch`, and commits the
new previous frame only after the backend succeeds. Use
`frame.set_cursor_position(point)` to request a visible hardware cursor; the
default intent is hidden. `Terminal.present(buffer^)` remains a temporary
compatibility path for a complete caller-built buffer.

Custom backends now implement:

```mojo
def viewport(mut self) raises -> Rect: ...
def present(mut self, patch: FramePatch) raises: ...
def clear(mut self) raises: ...
def flush(mut self) raises: ...
```

They apply `patch.changes`, reset transport state when `patch.full_redraw` is
true, and honor `patch.cursor`. Backends no longer retain a second complete
frame solely to calculate changes.

## Optional collection selection

`ListState.selected` and `TableState.selected` changed from an `Int` using `-1`
for absence to `Optional[UInt]`:

```mojo
var state = ListState(selected=UInt(2))
state.select(None, item_count)  # clear selection

if state.selected:
    var index = Int(state.selected.value())
```

Negative selection sentinels no longer compile.

## Nominal semantic values

The following public values are no longer raw integer tags:

- `Alignment`
- `ConstraintKind`, `Direction`, and `Flex`
- `ScrollbarOrientation`
- `KeyCode`, `KeyModifiers`, `KeyEventKind`, `MouseKind`, `MouseButton`, and
  `MouseCapture`
- `EditorCommandKind`, `ControllerActionKind`, `MarkerAffinity`, `PieceSource`,
  `WrapMode`, and `LineEnding`
- `ColorKind`, `ColorProfile`, `TerminalAppearance`, `ModifierSet`, and
  `Borders`
- `MessageClass` and `EnqueueResult`

Use their named constants, such as `Alignment.CENTER`, `Direction.VERTICAL`,
`Flex.END`, and `WrapMode.SOFT`. Passing an unrelated `Int` is a compile-time
error. Explicit construction with an out-of-range value raises instead of
silently choosing a default.

## Layout priority and flex behavior

`Layout` now resolves non-legacy constraints in Ratatui order (`Min`, `Max`,
`Length`, `Percentage`, `Ratio`, then `Fill`) instead of clipping later
declarations first. `Flex.SPACE_EVENLY`, `Flex.SPACE_AROUND`, `Margin`, and
Ratatui-named builder methods are available. Zero-weight fills are preserved;
percentages and ratios may exceed one whole and participate in priority-based
shrinking.

This changes some earlier allocations. For example, after a fixed five-column
segment and two one-column gaps, weighted fills `1:2` split 13 remaining
columns as `4:9`, not `5:8`. Negative spacing and `Flex::Legacy` remain outside
Mojotui's shared contract. See [layout compatibility](layout-compatibility.md).

`MouseEvent.button` is now `Optional[MouseButton]`: scrolling and movement
without a physical button carry `None`. `EditorControllerAction.command` is
`Optional[EditorCommand]`, so mode transitions no longer contain a dummy
command. Editor desired-column state also uses `Optional[UInt]` instead of
`-1`.

## Resolved styles and composable patches

`Style.modifiers` is now a validated `ModifierSet`, and resolved styles include
`underline_color`. Use `StylePatch` when applying a partial style so omitted
fields preserve the lower layer:

```mojo
var selected = base.patched(
    StylePatch(
        background=Color.indexed(4),
        add_modifiers=Style.BOLD,
        remove_modifiers=Style.DIM,
    )
)
```

`first.then(second)` produces the same result as applying `first` and then
`second`; the later patch wins conflicts. `Cell`, `Buffer`, `Span`, `Line`, and
`Text` expose patch helpers.

## Buffer and rich-text conveniences

`Buffer.set_string()` returns a `BufferWrite` containing the end position,
graphemes and columns written, and a `truncated` flag. Writes stop before a wide
grapheme that cannot fit. `Buffer.resize()` preserves only complete footprints,
and `Buffer.merge()` grows to the rectangle union before overlaying the other
buffer.

`Buffer.differences()` returns a row-major sequence with the before and after
cell at each changed coordinate. Different-area comparisons raise explicitly.

`Span`, `Line`, and `Text` now implement `Widget` directly and provide concise
`raw()` and `styled()` constructors. Text constructors split newline-delimited
input, and `aligned()` applies an alignment builder. `Span.write()` and
`Line.write()` expose clipping through `BufferWrite`. Direct `Text` rendering
does not wrap; continue to use `Paragraph` when wrapping is desired.
Wrapping at a width narrower than one grapheme preserves that grapheme on its
own logical line. Rendering may clip it, but wrapping does not discard content.

## Deeper widget configuration

`Paragraph` now word-wraps by default when wrapping is enabled. Use
`.wrap(trim=False)` to preserve boundary whitespace, `.without_wrap()` for
clipping, `.scroll(vertical=..., horizontal=...)` for viewport offsets, and
`.alignment(...)` for all logical lines.

`Block.with_padding(Padding(...))` replaces direct asymmetric integer fields.
The older symmetric `padding_x` and `padding_y` constructor arguments remain.
`BorderType` and `TitlePosition` select border glyphs and top/bottom title
placement without integer tags.

`ListItem` now owns `Text`, so `ListItem.from_text()` splits newline-delimited
items. `HighlightSpacing`, repeated markers, and `scroll_padding` configure
list navigation. `Row` now owns `Text` cells; migrate existing line-based rows
to `Row.from_lines([...])`. Explicit row heights, table footers,
`TableState.selected_column`, and `TableSelection` provide row, column, and cell
highlighting.

## Application initialization and hosting

`Application.init()` now returns both the model and optional startup commands:

```mojo
def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
    return InitResult(
        Model(),
        [Command(LoadInitialData())],
    )
```

Return `InitResult[Self.Model, Self.Effect].ready(Model())` when no startup
effect is needed. `subscriptions()` can now be omitted for applications with no
ongoing sources. `UpdateResult.exit()` replaces a separate loop-owned quit
flag, while `on_input()`, `on_tick()`, and `on_resize()` optionally translate
host observations into typed messages.

`RuntimeAdapter` no longer declares independent `Effect` and `Message`
associated types. It declares `ApplicationType`; method signatures use
`Self.ApplicationType.Effect` and `Self.ApplicationType.Message`. This prevents
constructing a host whose adapter and application disagree.

Use `ApplicationHost` for embedded or custom loops. For a complete POSIX
terminal loop, construct `TerminalApplicationHost` with the adapter first (so
Mojo can infer its associated application type), then the application, clock,
and backend:

```mojo
var host = TerminalApplicationHost(
    MyAdapter(),
    MyApplication(),
    SystemClock(),
    AnsiBackend.from_terminal(),
    options=SessionOptions(mouse=MouseCapture.MOTION),
)
host.run()
```

`SessionOptions.mouse_capture: Bool` was replaced by the nominal
`SessionOptions.mouse: MouseCapture` policy. Choose `MouseCapture.CLICKS`,
`MouseCapture.DRAG`, or `MouseCapture.MOTION`; the default is
`MouseCapture.OFF`.

Kitty keyboard disambiguation and event-type reporting are now enabled by
default as a progressive enhancement. Set
`SessionOptions(keyboard_enhancement=False)` to opt out; unsupported terminals
harmlessly ignore the protocol push and pop sequences.

The host owns restoration and adapter shutdown. The adapter still owns and
executes general background tasks.

## Host scheduling and delivery

`TerminalApplicationHost.poll_timeout_ms` was replaced by independent timing
configuration:

```mojo
var host = TerminalApplicationHost(
    MyAdapter(),
    MyApplication(),
    SystemClock(),
    AnsiBackend.from_terminal(),
    tick_interval_ms=100,
    escape_timeout_ms=25,
    frame_interval_ms=16,
    maximum_poll_ms=1_000,
    max_messages_per_step=64,
)
```

`HostSchedule` derives each poll timeout from the nearest application tick,
incomplete-Escape, frame, or runtime-adapter deadline. `RuntimeAdapter` has
default `next_deadline_ns()` and `on_deadline(now_ns)` hooks for adapters that
own timers. Existing adapters need no methods when they have no deadline.
Application ticks are disabled by default; pass a positive `tick_interval_ms`
when `on_tick()` drives application behavior.

The host now retains completion batches that do not fit the bounded queue,
processes at most `max_messages_per_step` in one turn, and reconciles
subscriptions after the batch. Tick and resize messages coalesce by stable key;
input and adapter completions remain lossless.

`Backend.resize_viewport(size)` is a default no-op. Resizable custom backends
should override it. The POSIX host queries size through the output descriptor,
and `InlineBackend` follows the observed width while retaining fixed height.

## Compositional text and state styles

`Span.style` is now `StylePatch`, while terminal `Cell.style` remains a resolved
`Style`. Use `Span.patched()` to construct a span from a patch and
`span.resolved_style(base)` when inspecting its final style. `Paragraph`
resolves its base first, then span intent, then state highlighting.

List, table, and tabs selection styles, plus table header/footer styles, now
accept `StylePatch`:

```mojo
var selection = StylePatch(
    background=Color.indexed(4),
    add_modifiers=Style.REVERSED,
)
var list = List(items, selected_style=selection)
```

This preserves an existing span foreground when the selection only requests a
background or modifier.

## Validated ratios and scrollbar symbols

Gauges no longer clamp invalid floating-point values. Construct a nominal
`Ratio`, or use its checked integer-percent helper:

```mojo
Gauge(Ratio(0.5))
LineGauge(Ratio.percent(75))
```

NaN and values outside zero through one raise during `Ratio` construction.
Custom scrollbar glyphs use a validated pair instead of independent strings:

```mojo
Scrollbar(symbols=ScrollbarSymbols("·", "█"))
```

Both symbols must contain exactly one grapheme occupying one terminal column.
Word wrapping now classifies separators with the Unicode 17 `White_Space`
property rather than an ASCII-only space/tab test.

## Adaptive colors and terminal capabilities

Built-in backends now report `TerminalCapabilities`, and `Terminal` forwards
that value with `terminal.capabilities()`. Existing custom backends continue to
compile because `Backend.capabilities()` has a conservative ANSI-16/dark
default. Override it when the transport knows the real client profile.

ANSI and inline backend constructors accept an optional typed `capabilities`
argument. When omitted, they inspect `NO_COLOR`, `COLORTERM`, `TERM`, and
`COLORFGBG`, plus `TERM_PROGRAM` for synchronized-output support, once during
construction. `HeadlessBackend` never reads the environment and retains a
deterministic default. Known mode-2026 terminals set
`TerminalCapabilities.synchronized_output`; ANSI and inline presentations then
use synchronized-output brackets.

Existing `Style` and `Color` construction remains valid and keeps its explicit
meaning. Portable themes opt in by resolving before rendering:

```mojo
var capabilities = detect_terminal_capabilities()
var accent = AdaptiveColor(
    ProfiledColor.from_rgb(80, 40, 160),
    ProfiledColor.from_rgb(80, 200, 255),
)
var style = Style(foreground=accent.resolve(capabilities))
var backend = AnsiBackend.from_terminal(capabilities=capabilities)
```

Indexed foreground/background colors zero through fifteen now use basic ANSI
SGR codes such as `31` and `104`, rather than equivalent `38;5` or `48;5`
sequences. Visual behavior is unchanged, but byte-level ANSI snapshots should
be updated. Underline colors continue to use SGR `58` because ANSI has no basic
16-color underline form.
