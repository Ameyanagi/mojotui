from std.pathlib import Path
from std.tempfile import TemporaryDirectory
from std.testing import assert_equal, assert_false, assert_true

from mojotui import Point
from mojotui.app import FocusId, FocusManager
from mojotui.core import Buffer, Cell, Rect
from mojotui.editor import (
    EditorCommand,
    EditorEngine,
    LocalFileService,
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


def check_installed_file_save() raises:
    # Own the directory directly: Mojo 1.0's error-context exit can suppress
    # assertion errors when cleanup succeeds. Destruction still cleans it up.
    var directory = TemporaryDirectory(prefix="mojotui-package-save-")
    var target = directory.name + "/document.txt"
    var sibling = directory.name + "/document.tmp"
    var service = LocalFileService()
    _ = service.save_atomic(target.copy(), sibling.copy(), "東京\n")
    var before = Path(target).stat()
    assert_equal(Int(before.st_mode) & 0o777, 0o600)
    assert_equal(service.load(target).content, "東京\n")
    assert_false(Path(sibling).exists())

    _ = service.save_atomic(target.copy(), sibling.copy(), "更新: 界🌱\n")
    var after = Path(target).stat()
    assert_equal(Int(after.st_mode) & 0o777, Int(before.st_mode) & 0o777)
    assert_equal(after.st_uid, before.st_uid)
    assert_equal(after.st_gid, before.st_gid)
    assert_equal(service.load(target).content, "更新: 界🌱\n")
    assert_false(Path(sibling).exists())


def main() raises:
    check_installed_file_save()
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
    assert_true(execute_editor_command(editor, EditorCommand.insert("界"), clipboard))
    assert_equal(editor.document.to_string(), "界")

    var focus = FocusManager()
    focus.set_order([FocusId("field"), FocusId("submit")])
    focus.next()
    assert_equal(focus.current().value().value, "submit")
    assert_true(session_enter_sequence(SessionOptions()).byte_length() > 0)
