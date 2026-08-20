# Architecture

Mojotui separates deterministic rendering from terminal I/O and task execution.
You can use the core and widgets without the application layer, and you can use
the editor engine without a terminal.

```text
terminal bytes -> InputParser -> typed events -> PosixReactor
                                                |
                                                v
                                     bounded MessageQueue
                                                |
                                                v
                                     update(model, message)
                                       |                 |
                                    commands       subscriptions
                                       |                 |
                                       +-- RuntimeScope--+
                                                |
                                                v
                                         typed messages

model -> view -> Frame -> Terminal diff -> FramePatch -> backend -> terminal
```

## Package direction

`core` defines geometry, style, cells, buffers, layout, and widget traits. It
also defines pure terminal capability values and adaptive colors without
reading the environment. `text` adds grapheme width and rich text. Widgets
depend on those two packages.

`terminal` owns presentation, while `event` parses input and polls descriptors.
Both packages call the private POSIX boundary where the standard library lacks
a safe terminal operation. Platform pointers do not appear in public types.

`app` owns sequential model updates, bounded messages, focus, keymaps, hit
testing, operation generations, and the runtime-neutral adapter contract.
Effects are data returned by `update`; views cannot run them.

`editor` owns documents, selections, history, rendering, controller mappings,
file services, highlights, and clipboard providers. `forms` builds `TextInput`
and `TextArea` on the editor rather than maintaining a second text model.

## Ownership

One application loop owns the model. `Terminal.begin_frame()` prepares a blank
frame against one observed viewport. A render pass borrows that frame's buffer
and ends before `Terminal.finish_frame()` presents it. Stateful widgets receive
their state from the caller. Background work returns typed messages and cannot
borrow the model.

Backends and applications use compile-time trait constraints. Mojotui does not
store heterogeneous runtime trait objects. A closed `Variant` is appropriate
when an application needs a finite set of runtime alternatives.

## Rendering

A `Buffer` is a dense row-major grid. Each cell stores one grapheme, its terminal
width, resolved style, and continuation state for a two-column glyph. Rich-text
spans and state highlights carry compositional `StylePatch` values that resolve
over the widget base at render time. All writes clip to the buffer rectangle.
Widgets draw in call order, so a later widget can cover an earlier one.

`Layout` uses a bounded one-dimensional allocator with Ratatui-compatible
non-legacy constraint priorities, margins, positive spacing, and flex
distribution. It does not embed a general Cassowary solver or a global cache;
the fixture contract and exclusions are recorded in
[docs/layout-compatibility.md](docs/layout-compatibility.md).

`Terminal` owns the last successfully presented frame, computes row-major cell
changes, tracks cursor intent, and commits history only after presentation
succeeds. Sequential frames reuse two swapped buffers rather than copying the
complete grid. `AnsiBackend` writes changes with absolute positions.
`InlineBackend` addresses the same patch relative to the cursor below its
fixed-height, terminal-width region. `HeadlessBackend` applies patches in memory
for tests. Dynamic backends
report their current viewport before each transaction, so resize handling does
not leak through the backend field.

Adaptive colors are resolved before rendering from an explicit
`TerminalCapabilities` value. Buffers store only resolved `Color`, keeping
frame equality and headless snapshots independent of backend policy. The
terminal package may detect conservative environment hints when an ANSI
backend is constructed; detection does not occur inside `view` or a widget.

## Terminal boundary

`TerminalSession` owns raw mode and enabled terminal features. `close()` restores
the saved terminal state; its destructor runs a best-effort restoration during
unwinding. PTY tests cover return, explicit errors, Ctrl-C, and resize handling.

The audited FFI lives in `mojotui/platform/posix.mojo`. The check task rejects
pointer and FFI operations elsewhere. See
[mojotui/platform/SAFETY.md](mojotui/platform/SAFETY.md) for each call invariant.

## Effects and tasks

`ApplicationRuntime` processes one message at a time. It returns commands to the
host and reconciles desired subscriptions by stable ID and revision.
`RuntimeScope` forwards that work to a concrete `RuntimeAdapter`. The adapter's
associated `ApplicationType` fixes both effect and message types at compile
time. Runtime-specific futures, channels, and task handles stay inside the
adapter.

`ApplicationHost` combines the sequential runtime, adapter scope, and terminal
transactions. `TerminalApplicationHost` adds ownership of `TerminalSession`,
`PosixReactor`, and `InputParser`, translates input/tick/resize observations
through optional application hooks, and closes every owned resource on normal
exit or error. `HostSchedule` derives polling from independent tick, Escape,
frame, and adapter deadlines. A retained adapter backlog and finite message
budget keep turns lossless and bounded. It coordinates task work but never
executes it itself.
