# Editor

The editor package is usable without a terminal. `EditorEngine` owns a
`Document`, normalized selections, and bounded undo/redo history. `EditorState`
adds viewport and highlight state for the `Editor` widget.

## Document model

`Document` stores the original text and appended edit text in an implicit treap
of pieces. Each node caches subtree byte counts, newlines, and piece counts.
Insert and delete operations split and merge the tree without copying the whole
document. Source pieces are capped at 4096 bytes so line and range scans stay
bounded near an edit.

Positions use UTF-8 byte offsets. Public edits reject offsets inside a code
point. `TextPosition` supplies a line and byte column when a caller needs a
human-readable location. Persistent markers update after insertions and
deletions according to their left or right affinity.

## Selections and commands

`SelectionSet` stores ordered, non-overlapping selections and one primary
selection. Horizontal motion follows grapheme clusters. Vertical motion keeps a
desired display column across short lines and expands tabs at configured stops.

`execute_editor_command` applies semantic commands to every selection. Edits in
one command form one transaction and run from the highest byte offset down, so
earlier offsets remain valid. Undo and redo restore both text and selections.

```mojo
from mojotui import (
    EditorCommand,
    EditorEngine,
    MemoryClipboard,
    execute_editor_command,
)


def main() raises:
    var engine = EditorEngine("hello")
    var clipboard = MemoryClipboard()
    _ = execute_editor_command(
        engine,
        EditorCommand.insert(" Mojo"),
        clipboard,
    )
    print(engine.document.to_string())
```

The default, Emacs, and Vim controller modules map keys to these commands.
Applications can replace the maps without changing the editor engine.

## Rendering

`Editor` renders visible rows only. It supports no-wrap and soft-wrap modes,
line numbers, tabs, selections, cursors, and versioned highlight ranges.
`HighlightState.apply` rejects a snapshot produced for an older document
version.

Use `Editor.render` when the caller owns mutable widget state and wants
cursor-driven viewport changes persisted. Use `Editor.render_readonly` from an
`Application.view` implementation: it derives a cursor-visible viewport in a
small frame-local value, renders from the borrowed `EditorState`, and leaves
the application model unchanged. Neither path copies the document or editor
history.

`TextInput` uses the same engine but strips line breaks from insert and paste
commands. `TextArea` is a form wrapper around `Editor`.

## Files and clipboards

`LocalFileService` loads UTF-8 files, detects a BOM and LF or CRLF endings, and
preserves those choices on save. Atomic save writes a caller-supplied temporary
path and renames it over the target. Metadata checks let the application warn
about external changes before saving.

`MemoryClipboard` is deterministic and works in tests. `Osc52Clipboard` writes a
bounded base64 payload to a terminal descriptor. Its `read()` method returns the
last value written through that provider; it does not query the terminal for
external clipboard contents. Applications that need native paste should supply
another `Clipboard` implementation.

The checked-in [`examples/editor.mojo`](examples/editor.mojo) composes these
parts into a complete typed application. Its file adapter is synchronous, but
the effect and message boundary is compatible with a future task-backed
`RuntimeAdapter` without exposing runtime-specific types in the editor API.

## Measured baseline

`pixi run bench-editor` creates a document larger than 10 MiB and reports middle
edits, undo/redo, and 80x24 viewport rendering. The benchmark guards against
whole-document work on common editing paths; it is not a cross-machine score.
