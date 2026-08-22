from std.testing import TestSuite, assert_equal, assert_true

from mojotui import (
    Block,
    Buffer,
    Button,
    Checkbox,
    EditorCommand,
    EditorCommandKind,
    EditorState,
    Line,
    MemoryClipboard,
    Rect,
    Style,
    TextArea,
    TextInput,
    execute_text_input_command,
)


def row(buffer: Buffer, y: Int) raises -> String:
    var result = String()
    for x in range(buffer.area.x, buffer.area.right()):
        var cell = buffer.cell({x, y})
        result += "" if cell.continuation else cell.symbol
    return result^


def test_text_input_placeholder_and_focused_editor() raises:
    var state = EditorState()
    var buffer = Buffer(Rect(0, 0, 12, 3))
    var input = TextInput.with_block(
        Block.bordered(), Line.from_text("search…"), focused=False
    )
    var area = buffer.area.copy()
    input.render(area, buffer, state)
    assert_true("search" in row(buffer, 1))

    var clipboard = MemoryClipboard()
    _ = execute_text_input_command(state, EditorCommand.insert("hello"), clipboard)
    var focused = TextInput.with_block(Block.bordered(), focused=True)
    focused.render(area, buffer, state)
    assert_true("hello" in row(buffer, 1))


def test_text_input_strips_newlines_from_insert_and_paste() raises:
    var state = EditorState()
    var clipboard = MemoryClipboard("c\nd")
    _ = execute_text_input_command(state, EditorCommand.insert("a\nb"), clipboard)
    _ = execute_text_input_command(
        state, EditorCommand(EditorCommandKind.PASTE), clipboard
    )
    assert_equal(state.engine.document.to_string(), "abcd")


def test_text_area_checkbox_and_button_compose_existing_primitives() raises:
    var state = EditorState("one two three")
    var buffer = Buffer(Rect(0, 0, 12, 3))
    var area = buffer.area.copy()
    TextArea().render(area, buffer, state)
    assert_equal(row(buffer, 0), "one two thre")

    var controls = Buffer(Rect(0, 0, 12, 2))
    Checkbox(Line.from_text("safe"), checked=True).render(Rect(0, 0, 12, 1), controls)
    Button(Line.from_text("Save"), focused=True).render(Rect(0, 1, 12, 1), controls)
    assert_true(row(controls, 0).startswith("☑ safe"))
    assert_true(row(controls, 1).startswith("[ Save ]"))
    assert_true(controls.cell({0, 1}).style.has(Style.REVERSED))


def test_form_inputs_offer_effect_free_readonly_rendering() raises:
    var input_state = EditorState("query")
    input_state.top_line = 7
    input_state.horizontal_offset = 2
    var buffer = Buffer(Rect(0, 0, 12, 3))
    var area = buffer.area.copy()
    TextInput(focused=True).render_readonly(area, buffer, input_state)
    assert_equal(input_state.top_line, 7)
    assert_equal(input_state.horizontal_offset, 2)

    TextArea().render_readonly(area, buffer, input_state)
    assert_equal(input_state.top_line, 7)
    assert_equal(input_state.horizontal_offset, 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
