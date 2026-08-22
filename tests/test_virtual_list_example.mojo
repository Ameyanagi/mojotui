from examples.virtual_list import LargeListApplication, LargeListMessage, ROW_COUNT
from mojotui import KeyEvent, Size
from std.testing import TestSuite, assert_equal


def send_key(
    mut application: LargeListApplication,
    mut model: LargeListApplication.Model,
    code: KeyEvent,
) raises:
    _ = application.update(model, LargeListMessage(code.copy()))


def test_page_navigation_uses_initial_and_resized_viewport_with_boundaries() raises:
    var application = LargeListApplication(5)
    var initialized = application.init()
    var model = initialized.take_model()

    send_key(application, model, KeyEvent(KeyEvent.PAGE_UP))
    assert_equal(Int(model.selection.selected.value()), 0)
    send_key(application, model, KeyEvent(KeyEvent.PAGE_DOWN))
    assert_equal(Int(model.selection.selected.value()), 5)

    var resized = application.on_resize(model, Size(80, 12))
    _ = application.update(model, resized.take())
    assert_equal(model.page_rows, 10)
    send_key(application, model, KeyEvent(KeyEvent.PAGE_DOWN))
    assert_equal(Int(model.selection.selected.value()), 15)
    send_key(application, model, KeyEvent(KeyEvent.PAGE_UP))
    assert_equal(Int(model.selection.selected.value()), 5)

    send_key(application, model, KeyEvent(KeyEvent.END))
    assert_equal(Int(model.selection.selected.value()), ROW_COUNT - 1)
    send_key(application, model, KeyEvent(KeyEvent.PAGE_DOWN))
    assert_equal(Int(model.selection.selected.value()), ROW_COUNT - 1)
    send_key(application, model, KeyEvent(KeyEvent.HOME))
    send_key(application, model, KeyEvent(KeyEvent.PAGE_UP))
    assert_equal(Int(model.selection.selected.value()), 0)

    resized = application.on_resize(model, Size(80, 2))
    _ = application.update(model, resized.take())
    assert_equal(model.page_rows, 1)
    send_key(application, model, KeyEvent(KeyEvent.PAGE_DOWN))
    assert_equal(Int(model.selection.selected.value()), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
