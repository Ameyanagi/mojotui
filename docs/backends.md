# Backends and terminal ownership

`Backend` has two operations: report a viewport and present a complete buffer.
`Terminal[B]` holds one concrete backend type, so calls specialize at compile
time.

## Headless

`HeadlessBackend` stores the current frame and presentation count. Use it for
widget snapshots and application tests. It performs no I/O.

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
location. It keeps the cursor on the line below those rows between frames and
uses relative cursor motion, so it can render after existing shell output.

Do not write unrelated bytes to the same descriptor while an inline backend is
active. Such writes move the anchor and invalidate the next diff. Call
`clear()` to erase the owned rows; the next presentation reserves them again.

## Custom backends

Implement `Backend` with an owned viewport and `present(mut self, buffer)`.
Reject a buffer whose area differs from the viewport. Keep transport handles in
the backend implementation and expose cells, rectangles, and owned values at
the public boundary.

A backend may perform I/O and raise errors. Widgets and application views should
remain deterministic; presentation happens after the view returns.
