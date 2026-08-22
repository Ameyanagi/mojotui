# Mojotui

[![CI](https://github.com/Ameyanagi/mojotui/actions/workflows/ci.yml/badge.svg)](https://github.com/Ameyanagi/mojotui/actions/workflows/ci.yml)

Mojotui is an experimental terminal UI library for Mojo. Its rendering model
borrows the useful parts of Ratatui: immediate-mode widgets draw into a cell
buffer, a terminal-owned frame transaction computes changes, and application
state stays outside widgets.
The API follows Mojo's ownership and static generic system instead of copying
Ratatui's Rust types.

## Install

To use Mojotui from your own Pixi project, add the hosted Mojotui channel and
the Mojo and conda-forge channels to the `channels` list in your project's
`pixi.toml`:

```toml
[workspace]
channels = [
    "https://ameyanagi.github.io/mojo-channel",
    "https://conda.modular.com/max",
    "conda-forge",
]
```

Then add the package:

```sh
pixi add "mojo-mojotui==0.1.1"
```

Once installed, run your own file with:

```sh
pixi run mojo run my_app.mojo
```

For a source checkout, install [Pixi](https://pixi.sh/) and a system C
compiler/linker. Xcode Command Line Tools provide the linker on macOS; Ubuntu's
`build-essential` package provides it on Linux. Mojotui targets macOS and Linux,
and its Mojo compiler version is pinned to stable `1.0.0`, so use Pixi rather
than a globally installed compiler. Then run:

```sh
pixi install --locked
pixi run check
pixi run dashboard
pixi run editor -- notes.txt
pixi run fuzzy
pixi run form
pixi run virtual-list
```

Run your own file against the checkout with:

```sh
pixi run mojo run -I . your_file.mojo
```

The dashboard exits with `q` or Ctrl-C. Up and Down change the selected process;
Tab, Left, and Right change the active view.

The editor accepts an optional UTF-8 file path. Ctrl-S saves; Ctrl-Q exits a
clean buffer and asks for a second Ctrl-Q before discarding unsaved changes.
Ctrl-Z/Ctrl-Y undo and redo, and terminal bracketed paste becomes one editor
transaction. Running `pixi run editor` without a path opens an in-memory
buffer. See [the editor example guide](docs/editor-example.md) for controls,
architecture, and headless testing.

The virtual-list example navigates 50,000 logical rows without constructing
50,000 rich-text values. Home/End and Page Up/Page Down demonstrate distant
viewport jumps, with page size derived from the live terminal viewport; `q` or
Escape exits.

The fuzzy picker keeps one focused editor-backed query, reports empty/result
counts, and prints the chosen value. The form example demonstrates Tab and
Shift-Tab traversal, field validation with error focus, toggles, submit, and
cancel as one typed application workflow.

`pixi run check` runs the Mojo tests, builds the executable fixtures, exercises
terminal restoration through a PTY, verifies formatting, compiles with
`--Werror`, checks the static type policy, and audits the unsafe boundary.

## Quickstart

Widgets are values. Pure renderers can draw directly into a caller-owned
`Buffer`; interactive applications ask `Terminal` for a `Frame`, render into
its stable viewport, and finish the transaction. The terminal owns frame
history, resize detection, diffing, and cursor intent.

```mojo
from mojotui import Buffer, Line, Paragraph, Rect, Text


def main() raises:
    var area = Rect(0, 0, 24, 3)
    var frame = Buffer(area)
    var message = Paragraph(Text.from_line(Line.from_text("hello from Mojo")))
    message.render(area, frame)

    var first_row = String()
    for x in range(area.x, area.right()):
        var cell = frame.cell({x, area.y})
        if not cell.continuation:
            first_row += cell.symbol
    print(first_row)
```

The same program is checked in as `examples/hello.mojo`:

```sh
pixi run mojo run -I . examples/hello.mojo
```

## Features

The repository currently includes:

- clipped Unicode-aware buffers, composable style patches, portable adaptive
  colors, directly renderable rich text, layout, and ANSI diffs;
- full-screen, inline, headless, and POSIX terminal support;
- wrapped/scrolled paragraphs, configurable blocks, multiline lists and tables,
  a lazy `VirtualList` for large result sets, fill, tabs, gauges, scrollbars,
  forms, and an editor widget;
- typed application state, effects, subscriptions, focus, and keymaps;
- a lifecycle-safe typed host for fullscreen or inline applications;
- a piece-table editor with multi-selection undo, file services, controllers,
  highlighting hooks, and bounded OSC 52 copy support.

## Portable terminal colors

`AdaptiveColor` resolves light, dark, and unknown-appearance alternatives for
monochrome, ANSI-16, ANSI-256, or truecolor output. Resolution happens before
cells are written, so buffers and headless snapshots retain ordinary resolved
`Color` values:

```mojo
from mojotui import (
    AdaptiveColor,
    ProfiledColor,
    Style,
    detect_terminal_capabilities,
)


def main() raises:
    var capabilities = detect_terminal_capabilities()
    var accent = AdaptiveColor(
        ProfiledColor.from_rgb(80, 40, 160),   # light background
        ProfiledColor.from_rgb(80, 200, 255),  # dark background
    )
    var style = Style(foreground=accent.resolve(capabilities))
    print(String("accent resolves to index ", style.foreground.index()))
```

Pass the same capability value to `AnsiBackend` or `InlineBackend`. Headless
tests should pass an explicit value when exercising a particular theme.

Typed applications implement the `Application` trait and run under
`TerminalApplicationHost`; see [the dashboard source](examples/dashboard.mojo).
The first interactive rung is the [counter tutorial](examples/counter.mojo):
run it with `pixi run counter` to see the `run(app)` convenience API.
For a manual event loop without the typed application layer, see
[the manual-loop hello example](examples/hello_loop.mojo).

## Function syntax and strict types

Current Mojo uses `def` for all function declarations. The pinned compiler
still treats `fn` as deprecated; Mojotui's source policy and `--Werror` build
reject it. `def` is non-raising unless the signature says `raises`, so it has
the strict behavior that older Mojo releases attached to `fn`.

Mojotui compiles public calls and generic constraints at build time. The library
does not expose `AnyType`, `PythonObject`, runtime widget objects, or runtime
backend objects. [TYPE_SAFETY.md](TYPE_SAFETY.md) records the enforced rules.

## Project documents

- [PLAN.md](PLAN.md) contains scope, phases, gates, and risks.
- [ARCHITECTURE.md](ARCHITECTURE.md) explains package boundaries and data flow.
- [docs/reference-architecture.md](docs/reference-architecture.md) records the
  pinned reference research, current safety contracts, and honest v0.2 target.
- [EDITOR.md](EDITOR.md) covers the editor model and integration points.
- [RUNTIME.md](RUNTIME.md) defines the task-runtime adapter contract.
- [docs/dashboard.md](docs/dashboard.md) walks through the example application.
- [docs/editor-example.md](docs/editor-example.md) explains the interactive
  editor, typed file effects, and its tests.
- [docs/custom-widgets.md](docs/custom-widgets.md) shows both widget contracts.
- [docs/backends.md](docs/backends.md) covers terminal ownership and backends.
- [docs/api.md](docs/api.md) maps common tasks to public types.
- [docs/migration.md](docs/migration.md) records pre-1.0 API migrations.
- [docs/layout-compatibility.md](docs/layout-compatibility.md) records the
  Ratatui 0.30.2 fixture contract and deliberate differences.
- [docs/stability.md](docs/stability.md) defines supported and experimental
  API tiers.
- [docs/compatibility.md](docs/compatibility.md) records exact compiler,
  dependency, platform, and static-build constraints.
- [docs/releasing.md](docs/releasing.md) documents source and channel release
  gates.
- [docs/terminals.md](docs/terminals.md) lists platform and terminal assumptions.
- [docs/limitations.md](docs/limitations.md) records known gaps.

## Status

The APIs may change before 1.0. Version `0.1.1` is compiled for exact stable
Mojo `1.0.0`; the precompiled package is not a compiler-independent static
library. GitHub Actions runs the complete locked source and installed-package
checks on macOS ARM64, Linux ARM64, and Linux x86-64.
