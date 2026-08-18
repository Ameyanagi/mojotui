from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import Edit, EditorEngine, Selection, SelectionSet


def test_single_edit_undo_redo_restores_text_and_selection() raises:
    var editor = EditorEngine("hello")
    editor.selections = SelectionSet([Selection.caret(5)])
    assert_true(editor.insert(5, "!"))
    assert_equal(editor.document.to_string(), "hello!")
    assert_equal(editor.selections.primary_selection().head, 6)
    assert_true(editor.undo())
    assert_equal(editor.document.to_string(), "hello")
    assert_equal(editor.selections.primary_selection().head, 5)
    assert_true(editor.redo())
    assert_equal(editor.document.to_string(), "hello!")
    assert_equal(editor.selections.primary_selection().head, 6)


def test_multi_range_transaction_applies_descending_and_undoes_in_reverse() raises:
    var editor = EditorEngine("one two three")
    assert_true(
        editor.apply(
            [
                Edit(0, 3, "1"),
                Edit(4, 7, "2"),
                Edit(8, 13, "3"),
            ]
        )
    )
    assert_equal(editor.document.to_string(), "1 2 3")
    assert_equal(len(editor.selections.selections), 3)
    assert_true(editor.undo())
    assert_equal(editor.document.to_string(), "one two three")
    assert_true(editor.redo())
    assert_equal(editor.document.to_string(), "1 2 3")
    editor.document.validate()


def test_new_edit_clears_redo_branch() raises:
    var editor = EditorEngine("a")
    _ = editor.insert(1, "b")
    _ = editor.undo()
    assert_true(editor.can_redo())
    _ = editor.insert(1, "c")
    assert_false(editor.can_redo())
    assert_equal(editor.document.to_string(), "ac")


def test_history_limits_truncate_oldest_transactions() raises:
    var editor = EditorEngine("", max_transactions=2, max_history_bytes=1024)
    _ = editor.insert(0, "a")
    _ = editor.insert(1, "b")
    _ = editor.insert(2, "c")
    assert_true(editor.undo())
    assert_true(editor.undo())
    assert_false(editor.undo())
    assert_equal(editor.document.to_string(), "a")


def test_overlapping_edits_are_rejected_before_mutation() raises:
    var editor = EditorEngine("abcdef")
    try:
        _ = editor.apply([Edit(1, 4, "x"), Edit(3, 5, "y")])
    except:
        assert_equal(editor.document.to_string(), "abcdef")
        return
    raise Error("expected overlapping transaction rejection")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
