# Dashboard example

Run the system monitor from the repository root:

```sh
pixi run dashboard
```

The example implements the typed `Application` contract and runs it through
`TerminalApplicationHost`. The host owns `TerminalSession`, the `AnsiBackend`
terminal, `PosixReactor`, `InputParser`, message processing, rendering, and
orderly restoration. `Terminal` observes resize, computes each frame diff, and
asks the backend to present changed cells.

The screen uses nested horizontal and vertical layouts. Blocks, tabs, gauges, a
sparkline, a stateful process table, and rich text all render into the same
frame. A separately scheduled 100 ms tick advances deterministic sample data;
input traffic cannot starve it. No process inspection or network access occurs.

At startup the example detects one `TerminalCapabilities` value, passes it to
both `DashboardApplication` and `AnsiBackend`, and resolves the dashboard's
adaptive accent, warning, and selection colors into `DashboardModel`. Light
and dark palettes therefore share one render path, while every frame remains
effect-free and every cell still contains a resolved `Color`.

Controls:

- Up and Down select a process row.
- Tab, Left, and Right change the active tab.
- `q` or Ctrl-C exits.

`on_input()` and `on_tick()` translate host observations into a closed
`DashboardMessage` variant. `update()` alone mutates `DashboardModel`, while
`view()` renders deterministically. The included no-op adapter demonstrates the
runtime boundary without importing an executor; it can later be replaced by a
concrete general-runtime adapter.
