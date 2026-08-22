from std.testing import TestSuite, assert_equal, assert_false, assert_true

from examples.form import FormApplication, handle_form_key, render_form
from mojotui import Buffer, ControlFlow, InputEvent, KeyEvent, PasteEvent, Rect


def test_form_focus_validation_toggle_submit_and_cancel() raises:
    var application = FormApplication()
    var initialized = application.init()
    var model = initialized.take_model()
    assert_true(model.focus.current().value().value == "name")

    _ = handle_form_key(model, KeyEvent.named(KeyEvent.TAB))
    assert_true(model.focus.current().value().value == "updates")
    _ = handle_form_key(model, KeyEvent.character(" "))
    assert_true(model.receive_updates)
    _ = handle_form_key(model, KeyEvent.named(KeyEvent.TAB))
    assert_true(model.focus.current().value().value == "submit")
    assert_true(
        handle_form_key(model, KeyEvent.named(KeyEvent.ENTER)) == ControlFlow.CONTINUE
    )
    assert_true(model.focus.current().value().value == "name")
    assert_true("required" in model.status)

    _ = handle_form_key(model, KeyEvent.character("界"))
    _ = handle_form_key(model, KeyEvent.named(KeyEvent.TAB))
    _ = handle_form_key(model, KeyEvent.named(KeyEvent.TAB))
    assert_true(
        handle_form_key(model, KeyEvent.named(KeyEvent.ENTER)) == ControlFlow.EXIT
    )
    assert_true(model.submitted)
    assert_false(model.cancelled)

    var cancelled_init = application.init()
    var cancelled = cancelled_init.take_model()
    assert_true(
        handle_form_key(cancelled, KeyEvent.named(KeyEvent.ESCAPE)) == ControlFlow.EXIT
    )
    assert_true(cancelled.cancelled)


def test_form_borrowed_render_preserves_input_viewport() raises:
    var application = FormApplication()
    var initialized = application.init()
    var model = initialized.take_model()
    model.name.top_line = 5
    var buffer = Buffer(Rect(0, 0, 60, 10))
    var area = buffer.area.copy()
    render_form(model, area, buffer)
    assert_equal(model.name.top_line, 5)


def test_form_maps_terminal_paste_to_one_text_input_command() raises:
    var application = FormApplication()
    var initialized = application.init()
    var model = initialized.take_model()
    var pasted = application.on_input(model, InputEvent(PasteEvent("東京\n")))
    assert_true(pasted)
    _ = application.update(model, pasted.take())
    assert_equal(model.name.engine.document.to_string(), "東京")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
