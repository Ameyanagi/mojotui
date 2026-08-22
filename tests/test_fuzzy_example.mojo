from std.testing import TestSuite, assert_false, assert_true

from examples.fuzzy import FuzzyApplication
from mojotui import InputEvent, KeyEvent


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
    assert_true(model.query == "x")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
