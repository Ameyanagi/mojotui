from std.testing import TestSuite, assert_equal, assert_true

from mojotui import (
    Buffer,
    Editor,
    EditorState,
    Rect,
    Selection,
    SelectionSet,
    Style,
    WrapMode,
)


def row(buffer: Buffer, y: Int) raises -> String:
    var result = String()
    for x in range(buffer.area.x, buffer.area.right()):
        var cell = buffer.cell({x, y})
        result += "" if cell.continuation else cell.symbol
    return result^


def test_no_wrap_editor_renders_unicode_tabs_and_visible_lines() raises:
    var state = EditorState("a界b\n\txy\nlast")
    var editor = Editor(tab_width=4)
    var buffer = Buffer(Rect(0, 0, 6, 2))
    var area = buffer.area.copy()
    editor.render(area, buffer, state)
    assert_equal(row(buffer, 0), "a界b  ")
    assert_equal(row(buffer, 1), "    xy")


def test_soft_wrap_editor_renders_only_visual_viewport_rows() raises:
    var state = EditorState("abcdef\n界xy")
    var editor = Editor(wrap_mode=WrapMode.SOFT)
    var buffer = Buffer(Rect(0, 0, 4, 3))
    var area = buffer.area.copy()
    editor.render(area, buffer, state)
    assert_equal(row(buffer, 0), "abcd")
    assert_equal(row(buffer, 1), "ef  ")
    assert_equal(row(buffer, 2), "界xy")


def test_editor_ensures_primary_cursor_is_visible_horizontally() raises:
    var state = EditorState("abcdefg")
    state.engine.selections = SelectionSet([Selection.caret(6)])
    var editor = Editor()
    var buffer = Buffer(Rect(0, 0, 4, 1))
    var area = buffer.area.copy()
    editor.render(area, buffer, state)
    assert_equal(state.horizontal_offset, 3)
    assert_equal(row(buffer, 0), "defg")
    assert_true(buffer.cell({3, 0}).style.has(Style.REVERSED))


def test_editor_selection_and_cursor_styles_are_explicit() raises:
    var state = EditorState("abcd")
    state.engine.selections = SelectionSet([Selection(1, 3)])
    var editor = Editor()
    var buffer = Buffer(Rect(0, 0, 5, 1))
    var area = buffer.area.copy()
    editor.render(area, buffer, state)
    assert_true(buffer.cell({1, 0}).style.has(Style.REVERSED))
    assert_true(buffer.cell({2, 0}).style.has(Style.REVERSED))
    assert_true(buffer.cell({3, 0}).style.has(Style.REVERSED))


def test_editor_line_numbers_and_vertical_scroll() raises:
    var state = EditorState("one\ntwo\nthree")
    state.engine.selections = SelectionSet([Selection.caret(8)])
    var editor = Editor(show_line_numbers=True)
    var buffer = Buffer(Rect(0, 0, 8, 2))
    var area = buffer.area.copy()
    editor.render(area, buffer, state)
    assert_equal(state.top_line, 1)
    assert_equal(row(buffer, 0), "2 two   ")
    assert_equal(row(buffer, 1), "3 three ")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
