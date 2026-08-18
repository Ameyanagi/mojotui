# Dashboard example

Run the system monitor from the repository root:

```sh
pixi run dashboard
```

The example opens a `TerminalSession`, constructs an `AnsiBackend`, and polls
stdin and terminal size with `PosixReactor`. Every iteration creates a fresh
buffer, renders the current model, and presents the diff.

The screen uses nested horizontal and vertical layouts. Blocks, tabs, gauges, a
sparkline, a stateful process table, and rich text all render into the same
frame. A 100 ms timer advances deterministic sample data. No process inspection
or network access occurs.

Controls:

- Up and Down select a process row.
- Tab, Left, and Right change the active tab.
- `q` or Ctrl-C exits.

The `handle_key` function mutates `DashboardModel`; render functions only read
the model. This split is the same one expected by the `Application` trait, even
though the example keeps its event loop explicit so each terminal operation is
visible in one file.
