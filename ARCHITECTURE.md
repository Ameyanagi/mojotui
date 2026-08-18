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

model -> view -> Buffer -> backend diff -> terminal
```

## Package direction

`core` defines geometry, style, cells, buffers, layout, and widget traits.
`text` adds grapheme width and rich text. Widgets depend on those two packages.

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

One application loop owns the model. A render pass borrows a buffer and ends
before terminal presentation. Stateful widgets receive their state from the
caller. Background work returns typed messages and cannot borrow the model.

Backends and applications use compile-time trait constraints. Mojotui does not
store heterogeneous runtime trait objects. A closed `Variant` is appropriate
when an application needs a finite set of runtime alternatives.

## Rendering

A `Buffer` is a dense row-major grid. Each cell stores one grapheme, its terminal
width, style, and continuation state for a two-column glyph. All writes clip to
the buffer rectangle. Widgets draw in call order, so a later widget can cover an
earlier one.

`AnsiBackend` compares the previous frame with the current frame and writes
changed cells. `InlineBackend` uses the same cells but addresses a fixed region
relative to the cursor below it. `HeadlessBackend` keeps the last frame in
memory for tests.

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
`RuntimeScope` forwards that work to a concrete `RuntimeAdapter`, whose associated
types fix the effect and message types at compile time. Runtime-specific futures,
channels, and task handles stay inside the adapter.
