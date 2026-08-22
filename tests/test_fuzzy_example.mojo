from std.testing import TestSuite, assert_equal, assert_false, assert_true

from examples.fuzzy import FuzzyApplication
from mojotui import Buffer, InputEvent, KeyEvent, PasteEvent, Rect


def test_fuzzy_input_ignores_release_and_accepts_repeat() raises:
    var application = FuzzyApplication()
    var initialized = application.init()
    var model = initialized.take_model()

    var released = application.on_input(
        model,
        InputEvent(KeyEvent.character("x", kind=KeyEvent.RELEASE)),
    )
    assert_false(released)

    var repeated = application.on_input(
        model,
        InputEvent(KeyEvent.character("x", kind=KeyEvent.REPEAT)),
    )
    assert_true(repeated)
    var result = application.update(model, repeated.take())
    assert_true(result.redraw)
    assert_equal(model.input.engine.document.to_string(), "x")


def test_fuzzy_uses_editor_commands_and_shows_empty_result_state() raises:
    var application = FuzzyApplication()
    var initialized = application.init()
    var model = initialized.take_model()
    for character in "qqqq".codepoints():
        var text = String()
        text.append(character)
        var message = application.on_input(model, InputEvent(KeyEvent.character(text^)))
        _ = application.update(model, message.take())
    assert_equal(model.input.engine.document.to_string(), "qqqq")
    assert_equal(len(model.matches), 0)

    var buffer = Buffer(Rect(0, 0, 60, 8))
    var area = buffer.area.copy()
    application.view(model, area, buffer)
    var rendered = String()
    for y in range(buffer.area.y, buffer.area.bottom()):
        for x in range(buffer.area.x, buffer.area.right()):
            var cell = buffer.cell({x, y})
            if not cell.continuation:
                rendered += cell.symbol
    assert_true("No matches" in rendered)
    assert_true("0 matches" in rendered)

    var backspace = application.on_input(
        model, InputEvent(KeyEvent.named(KeyEvent.BACKSPACE))
    )
    _ = application.update(model, backspace.take())
    assert_equal(model.input.engine.document.to_string(), "qqq")


def test_fuzzy_maps_terminal_paste_to_one_text_input_command() raises:
    var application = FuzzyApplication()
    var initialized = application.init()
    var model = initialized.take_model()
    var pasted = application.on_input(model, InputEvent(PasteEvent("東京\n")))
    assert_true(pasted)
    _ = application.update(model, pasted.take())
    assert_equal(model.input.engine.document.to_string(), "東京")
    assert_equal(len(model.matches), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
