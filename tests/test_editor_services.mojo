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


from mojotui.editor.file_service import FileMetadata, _FileReader, _load_with_reader
from mojotui.platform import atomic_replace_file


struct ReplacingFileReader(_FileReader):
    var replace_before_read: Bool
    var replace_in_place: Bool

    def __init__(out self, replace_before_read: Bool, replace_in_place: Bool = False):
        self.replace_before_read = replace_before_read
        self.replace_in_place = replace_in_place

    def metadata(mut self, path: StringSlice) raises -> FileMetadata:
        return LocalFileService().metadata(path)

    def replace(self, path: StringSlice) raises:
        if self.replace_in_place:
            Path(path).write_text("external update with a different size")
        else:
            var sibling = String(path, ".replacement")
            Path(sibling).write_text("external update")
            atomic_replace_file(sibling^, String(path))

    def read_text(mut self, path: StringSlice) raises -> String:
        if self.replace_before_read:
            self.replace(path)
        var content = Path(path).read_text()
        if not self.replace_before_read:
            self.replace(path)
        return content^


def test_load_rejects_replacement_before_and_after_read() raises:
    makedirs(".pixi/test-files", exist_ok=True)
    var target = String(".pixi/test-files/load-race.txt")
    for index in range(2):
        var before_read = index == 0
        Path(target).write_text("original version")
        var reader = ReplacingFileReader(before_read)
        var rejected = False
        try:
            _ = _load_with_reader(reader, target)
        except error:
            rejected = "changed while loading" in String(error)
        assert_true(rejected)
        assert_equal(Path(target).read_text(), "external update")


def test_load_rejects_in_place_edit_during_read() raises:
    makedirs(".pixi/test-files", exist_ok=True)
    var target = String(".pixi/test-files/load-in-place.txt")
    Path(target).write_text("original")
    var reader = ReplacingFileReader(False, replace_in_place=True)
    var rejected = False
    try:
        _ = _load_with_reader(reader, target)
    except error:
        rejected = "changed while loading" in String(error)
    assert_true(rejected)


def test_loaded_metadata_rejects_later_replacement_on_save() raises:
    makedirs(".pixi/test-files", exist_ok=True)
    var target = String(".pixi/test-files/load-then-save.txt")
    var temporary = String(".pixi/test-files/load-then-save.txt.tmp")
    Path(target).write_text("original")
    var service = LocalFileService()
    var loaded = service.load(target)
    var replacer = ReplacingFileReader(False)
    replacer.replace(target)
    var rejected = False
    try:
        _ = service.save_atomic(
            target.copy(),
            temporary.copy(),
            "stale edit",
            SaveOptions(expected=loaded.metadata.copy()),
        )
    except error:
        rejected = "file changed externally" in String(error)
    assert_true(rejected)
    assert_false(Path(temporary).exists())
    assert_equal(Path(target).read_text(), "external update")


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
