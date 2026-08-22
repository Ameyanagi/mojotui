from std.testing import assert_equal, assert_true

from mojotui import Point
from mojotui.app import FocusId, FocusManager
from mojotui.core import Buffer, Cell, Rect
from mojotui.editor import (
    EditorCommand,
    EditorEngine,
    MemoryClipboard,
    execute_editor_command,
)
from mojotui.event import InputParser, KeyEvent
from mojotui.forms import Checkbox
from mojotui.terminal import (
    HeadlessBackend,
    SessionOptions,
    Terminal,
    session_enter_sequence,
)
from mojotui.text import Line, text_width
from mojotui.widgets import Fill


def main() raises:
    assert_true(Rect(2, 3, 4, 2).contains(Point(5, 4)))
    assert_equal(text_width("東京"), 4)

    var buffer = Buffer(Rect(0, 0, 3, 1))
    var buffer_area = buffer.area.copy()
    Fill("x").render(buffer_area, buffer)
    Checkbox(Line.from_text("ok"), checked=True).render(buffer_area, buffer)

    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 2, 1)))
    var frame = terminal.begin_frame()
    _ = frame.buffer.set_cell({0, 0}, Cell("T"))
    var completed = terminal.finish_frame(frame^)
    assert_true(completed.full_redraw)

    var parser = InputParser()
    var events = parser.feed([UInt8(0x61)])
    assert_equal(events[0][KeyEvent].text, "a")

    var editor = EditorEngine()
    var clipboard = MemoryClipboard()
    assert_true(
        execute_editor_command(editor, EditorCommand.insert("界"), clipboard)
    )
    assert_equal(editor.document.to_string(), "界")

    var focus = FocusManager()
    focus.set_order([FocusId("field"), FocusId("submit")])
    focus.next()
    assert_equal(focus.current().value().value, "submit")
    assert_true(session_enter_sequence(SessionOptions()).byte_length() > 0)
