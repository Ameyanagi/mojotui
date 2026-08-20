# Backends and terminal ownership

`Backend` reports its current viewport and presents a `FramePatch` containing
changed cells, full-redraw intent, and an optional cursor position.
`Terminal[B]` holds one concrete backend type, owns frame history, and computes
patches, so calls specialize at compile time without giving every backend a
second full-frame diff implementation. In the normal sequential loop, it swaps
and clears two reusable buffers rather than copying the completed frame.

The normal render loop uses an explicit transaction:

```mojo
var frame = terminal.begin_frame()
frame.render_widget(widget, frame.area())
frame.set_cursor_position({3, 1})  # optional
var completed = terminal.finish_frame(frame^)
```

`begin_frame()` observes backend size and returns a blank immediate-mode frame.
`finish_frame()` rejects stale transactions and out-of-bounds cursor requests,
presents only changed cells, then commits the frame. `CompletedFrame` reports
the viewport, generation, changed-cell count, full-redraw status, and cursor.
`Terminal.clear()` clears backend output and resets frame history;
`Terminal.flush()` delegates to transports that buffer writes.

## Capabilities and theme resolution

`Backend.capabilities()` reports a copied `TerminalCapabilities` value, and
`Terminal.capabilities()` forwards it. Theme code resolves `AdaptiveColor`
before rendering and writes the resulting ordinary `Color` into cells. A
backend does not rewrite cell colors during presentation.

```mojo
var capabilities = TerminalCapabilities(
    ColorProfile.ANSI256,
    TerminalAppearance.LIGHT,
)
var terminal = Terminal(
    HeadlessBackend(Rect(0, 0, 80, 24), capabilities=capabilities)
)
var resolved = accent.resolve(terminal.capabilities())
```

`AnsiBackend` and `InlineBackend` call `detect_terminal_capabilities()` when
the constructor receives no explicit capability. Detection respects
`NO_COLOR`, then checks `COLORTERM` and `TERM` for truecolor or 256-color hints,
and uses the final `COLORFGBG` field when it is a recognizable ANSI background
index. Unknown or malformed hints fall back to ANSI-16 on a dark background.
An explicit typed constructor argument always wins.

Detection performs no terminal query and never runs from a widget or render
transaction. Applications that need exact behavior, remote-client profiles,
or reproducible output should inject `TerminalCapabilities` explicitly.

## Headless

`HeadlessBackend` applies patches to an in-memory frame and stores the
presentation count and cursor. Use `Terminal.last_frame()` for snapshots and
`HeadlessBackend.resize()` for deterministic autoresize tests. It performs no
I/O and defaults to `TerminalCapabilities.headless()` rather than reading the
process environment.

## Full screen

`AnsiBackend` emits absolute cursor positions and changed cells. Pair it with a
`TerminalSession`, which enables raw input and configured terminal modes.

```mojo
var session = TerminalSession()
var terminal = Terminal(AnsiBackend.from_terminal())
# run the event and render loop
session.close()
```

Create the session before the loop and call `close()` on every normal exit path.
The destructor also attempts restoration when a raising function unwinds.

## Inline

`InlineBackend(width, height)` owns a fixed number of rows at the current cursor
location. Its width follows host-observed terminal resize events while its
height stays fixed. It keeps the cursor on the line below those rows between
frames and uses relative cursor motion, so it can render after existing shell
output.

Do not write unrelated bytes to the same descriptor while an inline backend is
active. Such writes move the anchor and invalidate the next diff. Call
`clear()` to erase the owned rows; the next presentation reserves them again.

## Custom backends

Implement `Backend` with an owned viewport and
`present(mut self, patch: FramePatch) raises`, plus `clear()` and `flush()`.
Override `capabilities()` when the transport knows a more specific output
profile; the default is the conservative ANSI-16/dark value.
Override `resize_viewport(mut self, size: Size) raises` when a host-observed
terminal size should mutate the backend viewport; the default is a no-op.
Reject a patch whose area differs from the viewport. Apply `patch.changes` in
order, use `patch.full_redraw` to reset transport state when necessary, and
honor `patch.cursor`. Keep transport handles in the backend implementation and
expose cells, rectangles, and owned values at the public boundary.

A backend may perform I/O and raise errors. Widgets and application views should
remain deterministic; presentation happens after the view returns.
