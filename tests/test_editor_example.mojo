from std.os import makedirs
from std.pathlib import Path
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from examples.editor import EditorApplication, EditorAdapter, render_editor_example
from mojotui import (
    Buffer,
    InputEvent,
    KeyEvent,
    PasteEvent,
    Rect,
)


def row(buffer: Buffer, y: Int) raises -> String:
    var result = String()
    for x in range(buffer.area.x, buffer.area.right()):
        var cell = buffer.cell({x, y})
        result += "" if cell.continuation else cell.symbol
    return result^


def test_editor_application_handles_text_paste_history_and_readonly_view() raises:
    var application = EditorApplication()
    var initialized = application.init()
    var model = initialized.take_model()
    var initial = model.editor.engine.document.to_string()

    var typed = application.on_input(model, InputEvent(KeyEvent.character("x")))
    assert_true(typed)
    _ = application.update(model, typed.take())
    assert_true(model.editor.engine.document.to_string().startswith("x"))

    var undo = application.on_input(
        model,
        InputEvent(KeyEvent.character("z", KeyEvent.CONTROL)),
    )
    assert_true(undo)
    _ = application.update(model, undo.take())
    assert_equal(model.editor.engine.document.to_string(), initial)

    var paste = application.on_input(model, InputEvent(PasteEvent("界\n")))
    assert_true(paste)
    _ = application.update(model, paste.take())
    assert_true(model.editor.engine.document.to_string().startswith("界\n"))

    var buffer = Buffer(Rect(0, 0, 64, 10))
    var area = buffer.area.copy()
    render_editor_example(model, area, buffer)
    assert_true("[untitled] *" in row(buffer, 0))
    assert_true("Ctrl-S" in row(buffer, 9))
    assert_equal(model.editor.top_line, 0)
    assert_equal(model.editor.top_visual_row, 0)


def test_editor_adapter_loads_edits_and_saves_with_typed_messages() raises:
    makedirs(".pixi/test-files", exist_ok=True)
    var target = String(".pixi/test-files/editor-example.txt")
    Path(target).write_text("alpha\n")
    var application = EditorApplication(target)
    var initialized = application.init()
    var model = initialized.take_model()
    var adapter = EditorAdapter()

    var startup = initialized.take_commands()
    assert_equal(len(startup), 1)
    adapter.execute(startup.pop(0))
    var loaded = adapter.take_messages()
    assert_equal(len(loaded), 1)
    _ = application.update(model, loaded.pop(0))
    assert_equal(model.editor.engine.document.to_string(), "alpha\n")

    var typed = application.on_input(model, InputEvent(KeyEvent.character("X")))
    assert_true(typed)
    _ = application.update(model, typed.take())
    assert_equal(model.editor.engine.document.to_string(), "Xalpha\n")
    assert_true(model.is_modified())

    var save = application.on_input(
        model,
        InputEvent(KeyEvent.character("s", KeyEvent.CONTROL)),
    )
    assert_true(save)
    var save_result = application.update(model, save.take())
    var save_commands = save_result.take_commands()
    assert_equal(len(save_commands), 1)
    adapter.execute(save_commands.pop(0))
    var saved = adapter.take_messages()
    assert_equal(len(saved), 1)
    _ = application.update(model, saved.pop(0))

    assert_equal(Path(target).read_text(), "Xalpha\n")
    assert_equal(model.status, "saved")
    assert_false(model.is_modified())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
