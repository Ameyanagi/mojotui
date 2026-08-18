"""Large-document edit, history, line-lookup, and viewport benchmarks."""

from std.benchmark import keep
from std.time import perf_counter_ns

from mojotui import (
    Buffer,
    Editor,
    EditorEngine,
    EditorState,
    Rect,
    Selection,
    SelectionSet,
)


def large_ascii_document() -> String:
    comptime TARGET_BYTES = 10 * 1024 * 1024
    var text = String()
    var line = String(
        "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdef\n"
    )
    while text.byte_length() < TARGET_BYTES:
        text += line
    return text^


def main() raises:
    var source = large_ascii_document()
    var editor = EditorEngine(
        source.copy(), max_transactions=3000, max_history_bytes=128 * 1024 * 1024
    )
    var middle = editor.document.byte_length() // 2

    var edit_start = perf_counter_ns()
    for _ in range(1000):
        _ = editor.insert(middle, "x")
        _ = editor.delete(middle, middle + 1)
    var edit_elapsed = perf_counter_ns() - edit_start
    keep(editor.document.byte_length())

    var history_start = perf_counter_ns()
    for _ in range(500):
        _ = editor.undo()
    for _ in range(500):
        _ = editor.redo()
    var history_elapsed = perf_counter_ns() - history_start
    keep(editor.document.version)

    var state = EditorState(source^)
    var widget = Editor(show_line_numbers=True)
    var viewport_start = perf_counter_ns()
    for index in range(500):
        var line = (index * 251) % state.engine.document.line_count()
        var offset = state.engine.document.line_start(line)
        state.engine.selections = SelectionSet([Selection.caret(offset)])
        state.top_line = line
        var buffer = Buffer(Rect(0, 0, 80, 24))
        var area = buffer.area.copy()
        widget.render(area, buffer, state)
        keep(buffer)
    var viewport_elapsed = perf_counter_ns() - viewport_start

    print("document bytes:", editor.document.byte_length())
    print("2000 middle edits total (ms):", Float64(edit_elapsed) / 1_000_000.0)
    print("middle edit mean (us):", Float64(edit_elapsed) / 2_000_000.0)
    print("1000 undo/redo total (ms):", Float64(history_elapsed) / 1_000_000.0)
    print("history operation mean (us):", Float64(history_elapsed) / 1_000_000.0)
    print("500 80x24 viewports total (ms):", Float64(viewport_elapsed) / 1_000_000.0)
    print("viewport mean (us):", Float64(viewport_elapsed) / 500_000.0)
