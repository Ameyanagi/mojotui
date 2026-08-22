from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from mojotui import Edit, EditorEngine, Selection, SelectionSet


def test_single_edit_undo_redo_restores_text_and_selection() raises:
    var editor = EditorEngine("hello")
    var initial_state = editor.document.revision()
    editor.selections = SelectionSet([Selection.caret(5)])
    assert_true(editor.insert(5, "!"))
    var edited_state = editor.document.revision()
    assert_true(edited_state != initial_state)
    assert_equal(editor.document.to_string(), "hello!")
    assert_equal(editor.selections.primary_selection().head, 6)
    assert_true(editor.undo())
    assert_true(editor.document.revision() == initial_state)
    assert_equal(editor.document.to_string(), "hello")
    assert_equal(editor.selections.primary_selection().head, 5)
    assert_true(editor.redo())
    assert_true(editor.document.revision() == edited_state)
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
    var abandoned_state = editor.document.revision()
    _ = editor.undo()
    var branch_point = editor.document.revision()
    assert_true(editor.can_redo())
    _ = editor.insert(1, "b")
    assert_true(editor.document.revision() != abandoned_state)
    assert_true(editor.document.revision() != branch_point)
    assert_false(editor.can_redo())
    assert_equal(editor.document.to_string(), "ab")


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


def test_direct_document_mutation_rejects_stale_undo_and_redo() raises:
    var undo_editor = EditorEngine("a")
    var saved = undo_editor.document.revision()
    _ = undo_editor.insert(1, "b")
    undo_editor.document.insert(0, "x")
    var directly_mutated = undo_editor.document.revision()
    with assert_raises(contains="history is stale"):
        _ = undo_editor.undo()
    assert_equal(undo_editor.document.to_string(), "xab")
    assert_true(undo_editor.document.revision() == directly_mutated)
    assert_true(undo_editor.document.revision() != saved)
    assert_true(undo_editor.can_undo())
    assert_false(undo_editor.can_redo())

    var redo_editor = EditorEngine("a")
    _ = redo_editor.insert(1, "b")
    _ = redo_editor.undo()
    redo_editor.document.insert(0, "x")
    directly_mutated = redo_editor.document.revision()
    with assert_raises(contains="history is stale"):
        _ = redo_editor.redo()
    assert_equal(redo_editor.document.to_string(), "xa")
    assert_true(redo_editor.document.revision() == directly_mutated)
    assert_false(redo_editor.can_undo())
    assert_true(redo_editor.can_redo())


def test_new_edit_rejects_stale_selection_before_clearing_history() raises:
    var editor = EditorEngine("abcd")
    editor.selections = SelectionSet([Selection.caret(4)])
    _ = editor.insert(4, "e")
    _ = editor.document.delete(0, 5)
    var directly_mutated = editor.document.revision()
    with assert_raises(contains="set selections to valid document boundaries"):
        _ = editor.insert(0, "x")
    assert_equal(editor.document.to_string(), "")
    assert_true(editor.document.revision() == directly_mutated)
    assert_true(editor.can_undo())
    assert_false(editor.can_redo())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
