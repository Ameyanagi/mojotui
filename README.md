# Mojotui

[![CI](https://github.com/Ameyanagi/mojotui/actions/workflows/ci.yml/badge.svg)](https://github.com/Ameyanagi/mojotui/actions/workflows/ci.yml)

Mojotui is an experimental terminal UI library for Mojo. Its rendering model
borrows the useful parts of Ratatui: immediate-mode widgets draw into a cell
buffer, a terminal-owned frame transaction computes changes, and application
state stays outside widgets.
The API follows Mojo's ownership and static generic system instead of copying
Ratatui's Rust types.

The repository currently includes:

- clipped Unicode-aware buffers, composable style patches, portable adaptive
  colors, directly renderable rich text, layout, and ANSI diffs;
- full-screen, inline, headless, and POSIX terminal support;
- wrapped/scrolled paragraphs, configurable blocks, multiline lists and tables,
  fill, tabs, gauges, scrollbars, forms, and an editor widget;
- typed application state, effects, subscriptions, focus, and keymaps;
- a lifecycle-safe typed host for fullscreen or inline applications;
- a piece-table editor with multi-selection undo, file services, controllers,
  highlighting hooks, and bounded OSC 52 copy support.

The project targets macOS and Linux. The Mojo compiler version is pinned to
`1.1.0.dev2026081813`, so use Pixi rather than a globally installed compiler.

## Run it

Install [Pixi](https://pixi.sh/) and a system C compiler/linker. Xcode Command
Line Tools provide the linker on macOS; Ubuntu's `build-essential` package
provides it on Linux. Then run:

```sh
pixi install --locked
pixi run check
pixi run dashboard
pixi run editor -- notes.txt
```

The dashboard exits with `q` or Ctrl-C. Up and Down change the selected process;
Tab, Left, and Right change the active view.

The editor accepts an optional UTF-8 file path. Ctrl-S saves, Ctrl-Q exits,
Ctrl-Z/Ctrl-Y undo and redo, and terminal bracketed paste becomes one editor
transaction. Running `pixi run editor` without a path opens an in-memory
buffer. See [the editor example guide](docs/editor-example.md) for controls,
architecture, and headless testing.

`pixi run check` runs the Mojo tests, builds the executable fixtures, exercises
terminal restoration through a PTY, verifies formatting, compiles with
`--Werror`, checks the static type policy, and audits the unsafe boundary.

## A small renderer

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
```

Pass the same capability value to `AnsiBackend` or `InlineBackend`. Headless
tests should pass an explicit value when exercising a particular theme.

Use `TerminalSession`, `AnsiBackend`, `PosixReactor`, and `InputParser` for an
interactive full-screen program. [The dashboard source](examples/dashboard.mojo)
contains a complete event loop.

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
- [docs/terminals.md](docs/terminals.md) lists platform and terminal assumptions.
- [docs/limitations.md](docs/limitations.md) records known gaps.

## Status

The APIs may change before 1.0. Local macOS and Linux ARM64 validation passes.
GitHub Actions runs the complete locked check on macOS ARM64, Linux ARM64, and
Linux x86-64.
