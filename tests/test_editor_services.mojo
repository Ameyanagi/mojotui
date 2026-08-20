from std.os import makedirs
from std.pathlib import Path
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import (
    Buffer,
    Color,
    Editor,
    EditorState,
    HighlightRange,
    HighlightSnapshot,
    HighlightState,
    LineEnding,
    LocalFileService,
    MemoryClipboard,
    Osc52Clipboard,
    Rect,
    SaveOptions,
    Style,
    clipboard_round_trip,
    encode_base64,
    osc52_copy_sequence,
)


def test_stale_highlight_snapshot_is_rejected() raises:
    var state = EditorState("let value")
    var highlights = HighlightState()
    var request = highlights.request(state.engine.document, 0, 3)
    _ = state.engine.insert(0, "x")
    assert_false(
        highlights.apply(
            state.engine.document,
            HighlightSnapshot(
                request.document_version,
                [HighlightRange(0, 3, Style(modifiers=Style.BOLD))],
            ),
        )
    )


def test_current_highlights_render_below_selection_and_cursor() raises:
    var state = EditorState("let value")
    var accent = Style(foreground=Color.rgb(10, 20, 30))
    assert_true(
        state.highlights.apply(
            state.engine.document,
            HighlightSnapshot(
                state.engine.document.version,
                [HighlightRange(0, 3, accent)],
            ),
        )
    )
    var editor = Editor()
    var buffer = Buffer(Rect(0, 0, 9, 1))
    var area = buffer.area.copy()
    editor.render(area, buffer, state)
    assert_true(buffer.cell({1, 0}).style.equals(accent))
    assert_true(buffer.cell({0, 0}).style.has(Style.REVERSED))


def test_memory_clipboard_uses_static_generic_contract() raises:
    var clipboard = MemoryClipboard()
    assert_equal(clipboard_round_trip(clipboard, "界 text"), "界 text")


def test_base64_and_osc52_encoding_are_utf8_safe_and_bounded() raises:
    assert_equal(encode_base64(""), "")
    assert_equal(encode_base64("f"), "Zg==")
    assert_equal(encode_base64("fo"), "Zm8=")
    assert_equal(encode_base64("foo"), "Zm9v")
    assert_equal(encode_base64("界"), "55WM")
    assert_equal(osc52_copy_sequence("foo", 3), "\x1b]52;c;Zm9v\x1b\\")
    try:
        _ = osc52_copy_sequence("界", 2)
    except:
        return
    raise Error("OSC 52 must reject payloads above its UTF-8 byte limit")


def test_osc52_constructor_rejects_invalid_configuration() raises:
    try:
        _ = Osc52Clipboard(max_bytes=-1)
    except:
        return
    raise Error("OSC 52 must reject a negative byte limit")


def test_file_service_preserves_bom_and_crlf_with_atomic_replace() raises:
    makedirs(".pixi/test-files", exist_ok=True)
    var target = String(".pixi/test-files/editor-service.txt")
    var temporary = String(".pixi/test-files/editor-service.txt.tmp")
    Path(target).write_text("﻿a\r\nb\r\n")
    var service = LocalFileService()
    var loaded = service.load(target)
    assert_equal(loaded.content, "a\nb\n")
    assert_true(loaded.line_ending == LineEnding.CRLF)
    assert_true(loaded.had_bom)
    var saved = service.save_atomic(
        target.copy(),
        temporary^,
        "changed\n",
        SaveOptions(
            line_ending=loaded.line_ending,
            write_bom=loaded.had_bom,
            expected=loaded.metadata.copy(),
        ),
    )
    assert_false(Path(".pixi/test-files/editor-service.txt.tmp").exists())
    assert_equal(Path(target).read_text(), "﻿changed\r\n")
    assert_false(service.has_external_change(target, saved))
    Path(target).write_text("external change")
    assert_true(service.has_external_change(target, saved))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
