# Editor example

Run the full-screen editor from the repository root:

```sh
pixi run editor -- notes.txt
```

Omit the path to open an in-memory demonstration buffer. Mojotui loads and
saves UTF-8, preserves a detected BOM and LF or CRLF line endings, and checks
the loaded file metadata before replacing it atomically. A conflicting
external change therefore reports a save failure instead of being silently
overwritten.

Controls:

- Arrow keys move the cursor; Shift-Left and Shift-Right extend a selection.
- Home and End move to the current line boundaries.
- Ctrl-A selects all; Ctrl-C, Ctrl-X, and Ctrl-V use the application-owned
  in-memory clipboard.
- Ctrl-Z and Ctrl-Y undo and redo complete edit transactions.
- Ctrl-S saves a path-backed buffer; Ctrl-Q exits.
- Terminal bracketed paste inserts the complete paste as one transaction.

The example implements `Application` with a non-copyable `EditorExampleModel`.
Its closed message variant contains key events, semantic editor commands, and
file completions. `update` is the only code that mutates the model. `view`
calls `Editor.render_readonly`, so rendering computes cursor visibility without
changing or copying the document, history, selections, or stored viewport.

`LoadFileEffect` and `SaveFileEffect` are data. `EditorAdapter` interprets them
through `LocalFileService` and returns typed completion messages. It is a small
synchronous adapter for the example, not a general executor. A future adapter
can run the same effects on Mojo's supported task runtime without changing the
application or editor contracts. Save completions carry the document version,
so a delayed completion cannot incorrectly mark newer edits as saved.

## Test it

Run the focused deterministic tests:

```sh
pixi run mojo run -I . tests/test_editor_example.mojo
pixi run mojo run -I . tests/test_editor_widget.mojo
```

The first suite covers text input, paste, undo, borrowed-state rendering, and a
load/edit/save round trip through the typed adapter. The second protects both
mutable viewport persistence and the read-only application rendering path.

`pixi run check` also builds the editor executable and starts it through a real
pseudo-terminal. The PTY test waits for the initial frame, sends Ctrl-Q, and
verifies the alternate screen and terminal attributes are restored.

The in-memory clipboard intentionally does not read the operating-system
clipboard. Native terminal paste still works through bracketed-paste events;
applications that need system clipboard reads can supply another statically
typed `Clipboard` implementation.
