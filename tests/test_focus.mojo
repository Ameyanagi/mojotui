from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import FocusId, FocusManager


def current(manager: FocusManager) raises -> String:
    var focused = manager.current()
    if not focused:
        raise Error("expected a focused target")
    return focused.value().value


def test_root_traversal_wraps_in_declared_order() raises:
    var manager = FocusManager()
    manager.set_order([FocusId("search"), FocusId("list"), FocusId("details")])
    assert_equal(current(manager), "search")
    manager.next()
    manager.next()
    manager.next()
    assert_equal(current(manager), "search")
    manager.previous()
    assert_equal(current(manager), "details")


def test_modal_scope_restricts_focus_and_restores_prior_target() raises:
    var manager = FocusManager()
    manager.set_order([FocusId("search"), FocusId("list")])
    assert_true(manager.focus(FocusId("list")))
    manager.push_scope("confirm", [FocusId("cancel"), FocusId("accept")])
    assert_equal(current(manager), "cancel")
    assert_false(manager.focus(FocusId("search")))
    manager.next()
    assert_equal(current(manager), "accept")
    assert_true(manager.pop_scope())
    assert_equal(current(manager), "list")


def test_nested_modal_scopes_restore_in_stack_order() raises:
    var manager = FocusManager()
    manager.set_order([FocusId("root")])
    manager.push_scope("dialog", [FocusId("dialog-a"), FocusId("dialog-b")])
    _ = manager.focus(FocusId("dialog-b"))
    manager.push_scope("picker", [FocusId("choice")])
    assert_equal(manager.scope_depth(), 2)
    assert_true(manager.pop_scope())
    assert_equal(current(manager), "dialog-b")
    assert_true(manager.pop_scope())
    assert_equal(current(manager), "root")


def test_invalid_or_duplicate_ids_are_rejected() raises:
    var manager = FocusManager()
    try:
        manager.set_order([FocusId("same"), FocusId("same")])
    except:
        return
    raise Error("expected duplicate focus ID rejection")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
