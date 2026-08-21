# API map

Import common types from `mojotui`. Subpackages remain available when an
application wants narrower imports.

| Task | Public API |
| --- | --- |
| Geometry and layout | `Point`, `Size`, `Rect`, `Margin`, `Constraint`, `ConstraintKind`, `Direction`, `Layout`, `Flex` |
| Cells and styling | `Cell`, `Color`, `ColorKind`, `ColorProfile`, `TerminalAppearance`, `TerminalCapabilities`, `ProfiledColor`, `AdaptiveColor`, `ModifierSet`, `Style`, `StylePatch`, `Buffer`, `BufferWrite`, `BufferDifference` |
| Rich text | `Span`, `Line`, `Text`, `render_line`, `render_text`; all three values implement `Widget` |
| Stateless widgets | `Block`, `BorderType`, `Padding`, `TitlePosition`, `Paragraph`, `Fill`, `Ratio`, `Gauge`, `LineGauge`, `Sparkline`, `BarChart`, `Tabs`, `Clear` |
| Stateful widgets | `List`, `HighlightSpacing`, `Table`, `TableSelection`, `Scrollbar`, `ScrollbarSymbols`, `Editor`, `TextInput`, `TextArea` and their state types |
| Render transactions | `Frame`, `CompletedFrame`, `Terminal` |
| Terminal output | `FramePatch`, `AnsiBackend`, `InlineBackend`, `HeadlessBackend`, `detect_terminal_capabilities`, `terminal_capabilities_from_environment` |
| Terminal lifecycle | `TerminalSession`, `SessionOptions`, `MouseCapture` |
| Input | `InputParser`, `InputEvent`, `KeyCode`, `KeyModifiers`, `KeyEvent`, `MouseKind`, `MouseButton`, `MouseEvent`, `PasteEvent` |
| Polling | `PosixReactor`, `ReactorPoll` |
| Application state | `Application`, `InitResult`, `ApplicationRuntime`, `UpdateResult`, `ControlFlow`, `MessageQueue` |
| Effects | `Command`, `Subscription`, `OperationTracker`, `CancellationToken` |
| Runtime bridge and host | `RuntimeAdapter`, `RuntimeScope`, `ApplicationHost`, `TerminalApplicationHost`, `HostSchedule`, `HostStep` |
| Focus and input mapping | `FocusManager`, `Keymap`, `KeyChord`, `HitMap` |
| Editor data | `Document`, `SelectionSet`, `EditorEngine`, `EditorCommand`, `EditorCommandKind`, `ControllerActionKind`, `WrapMode`, `LineEnding` |
| Editor services | `LocalFileService`, `Clipboard`, `MemoryClipboard`, `Osc52Clipboard` |

Functions that can fail declare `raises`. The compiler checks trait constraints
and concrete associated types before execution. Semantic choices use nominal
values such as `Alignment`, `Direction`, `Flex`, `ScrollbarOrientation`,
`WrapMode`, and `EnqueueResult`; they are not interchangeable with raw `Int`
values. This includes keyboard and mouse tags, editor command and persistence
kinds, colors, style modifiers, and border sets. `ListState.selected` and
`TableState.selected` are `Optional[UInt]`; other optional payloads likewise use
`Optional` instead of a sentinel.

`Style` is a resolved cell style. `StylePatch` carries only requested changes,
including independent modifier additions and removals, and patches compose with
later changes taking precedence. Both types, plus `Span` and `Line`, provide
chainable `bold()`, `italic()`, `dim()`, `underlined()`, `reversed()`,
`crossed_out()`, `fg()`, and `bg()` shorthand. `Buffer.set_string()` returns
`BufferWrite`, so callers can observe clipping; it never writes half of a wide
grapheme.
`Buffer.resize()` retains only complete cell footprints and `Buffer.merge()`
overlays one complete buffer after growing to their union.
`Buffer.differences()` returns row-major `BufferDifference` values containing
both resolved cells and rejects buffers with different areas.
`Rect.centered(width, height)` clamps requested extents and centers them with
odd remainders biased toward the left and top.

`ColorProfile` distinguishes monochrome, ANSI-16, ANSI-256, and truecolor
targets. `TerminalAppearance` distinguishes light, dark, and unknown
backgrounds. `ProfiledColor` owns an explicit fallback for every profile;
`ProfiledColor.from_rgb()` deterministically derives xterm palette fallbacks.
`AdaptiveColor` selects light, dark, or explicit unknown-appearance intent and
then resolves it for `TerminalCapabilities`:

```mojo
var accent = AdaptiveColor(
    ProfiledColor.from_rgb(80, 40, 160),
    ProfiledColor.from_rgb(80, 200, 255),
)
var style = Style(foreground=accent.resolve(capabilities))
```

The two-color constructor uses its dark alternative for unknown appearance;
pass a third `ProfiledColor` to choose a separate unknown fallback. Resolution
returns a normal `Color`. Cells, buffers, diffs, and snapshots never contain
adaptive intent.

`Layout` follows Ratatui's non-legacy constraint priorities and six flex modes,
including `Flex.SPACE_EVENLY` and `Flex.SPACE_AROUND`. Constructor keywords are
available for concise Mojo code; `margin()`, `horizontal_margin()`,
`vertical_margin()`, `spacing()`, and `flex()` provide familiar builders. See
the [fixture-backed compatibility contract](layout-compatibility.md) for the
intentional exclusions.

Rich-text `Span.style` is a `StylePatch`, so a paragraph background, a span
foreground, and a selection modifier compose instead of erasing one another.
Use `Span.resolved_style(base)` when a caller needs the final cell style.

Use `Span.raw()` / `Span.styled()` / `Span.patched()`, `Line.raw()` /
`Line.styled()`, and
`Text.raw()` / `Text.styled()` for concise construction. `Line.append()` and
`Text.append()` build richer values, while `width()` and `Text.height()` expose
terminal dimensions. `Text` constructors split newline-delimited input into
logical lines; `aligned()` applies alignment to a line or all text lines.
`Span.write()` and `Line.write()` return the same explicit `BufferWrite`
outcome as a buffer string write. Rendering any of `Span`, `Line`, or `Text`
through `render_widget()` clips safely; `Text` renders logical lines without
implicit wrapping. `Paragraph` owns wrapping behavior.
When a grapheme is wider than the requested wrap width, wrapping preserves it
on a dedicated logical line; rendering then clips it rather than emitting half
of the glyph.

`Paragraph` word-wraps without flattening span styles, can preserve or trim
boundary whitespace, scrolls in both axes, and applies line alignment.
`Block.with_padding()` supports independent edges; blocks select plain,
rounded, double, or thick borders and top/bottom aligned titles. Lists support
multiline items, scroll padding, repeated highlight symbols, and explicit
highlight spacing. Tables support multiline row heights, headers, footers,
scroll padding, and row/column/cell selection. `Fill` accepts exactly one
single-column grapheme so repeated painting cannot corrupt wide-cell state.

`Gauge` and `LineGauge` accept `Ratio`, whose constructor rejects NaN and values
outside zero through one; `Ratio.percent()` validates an integer percentage.
Custom scrollbars accept a `ScrollbarSymbols` pair whose track and thumb are
each exactly one grapheme and one terminal column.

`Application.init()` returns `InitResult`, allowing startup commands alongside
the initial model. Subscriptions and terminal input/tick/resize mapping hooks
default to no work. `UpdateResult.exit()` requests orderly loop shutdown.
`ApplicationHost` coordinates a typed runtime adapter, sequential application
state, and terminal frames without owning a platform session.
`TerminalApplicationHost` additionally owns the terminal session, POSIX
reactor, incremental parser, and their cleanup; `SessionOptions` selects
fullscreen or inline-compatible behavior, while `MouseCapture` selects clicks,
drag tracking, all motion, or no mouse capture. `KeyCode.F1` through
`KeyCode.F12` represent terminal function keys. A `RuntimeAdapter` declares one
`ApplicationType`, so its effect inputs and message outputs are proven to match
the application at compile time. `HostSchedule` independently tracks ticks,
Escape resolution, frame cadence, and optional adapter deadlines. Host turns
retain lossless adapter backlogs, process a bounded message batch, reconcile
subscriptions once, and coalesce only latest-value tick and resize messages.

Every backend implements `capabilities()`, and `Terminal.capabilities()`
forwards that configured value. `HeadlessBackend` defaults deterministically to
ANSI-16 on a dark background with synchronized output disabled. ANSI and inline
backends detect conservative environment hints unless their `capabilities`
constructor argument is set. Known mode-2026 terminals set
`TerminalCapabilities.synchronized_output`, causing each nonempty presentation
to be bracketed as one synchronized update.

See [API stability tiers](stability.md) for the supported foundation,
experimental ecosystem, and internal platform boundary.
