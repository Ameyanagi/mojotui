from std.testing import TestSuite, assert_equal, assert_true

from mojotui import (
    Document,
    Selection,
    SelectionSet,
    display_column,
    move_selection_left,
    move_selection_right,
    move_selection_vertical,
    next_grapheme_offset,
    previous_grapheme_offset,
)


def test_grapheme_motion_treats_combining_and_emoji_sequences_as_units() raises:
    var combining = String("á")
    var emoji = String("👨‍👩‍👧‍👦")
    var text = combining + "界" + emoji
    var document = Document(text^)
    var after_combining = combining.byte_length()
    var after_cjk = after_combining + String("界").byte_length()
    assert_equal(next_grapheme_offset(document, 0), after_combining)
    assert_equal(next_grapheme_offset(document, after_combining), after_cjk)
    assert_equal(next_grapheme_offset(document, after_cjk), document.byte_length())
    assert_equal(previous_grapheme_offset(document, document.byte_length()), after_cjk)
    assert_equal(previous_grapheme_offset(document, after_cjk), after_combining)


def test_display_columns_include_wide_graphemes_and_tab_stops() raises:
    var document = Document("a界\n\tb")
    assert_equal(display_column(document, 1), 1)
    assert_equal(display_column(document, 4), 3)
    var second_line = document.line_start(1)
    assert_equal(display_column(document, second_line + 1), 4)
    assert_equal(display_column(document, second_line + 2), 5)


def test_vertical_motion_preserves_desired_column_across_short_line() raises:
    var document = Document("abcd\nx\nwxyz")
    var selection = Selection.caret(3)
    move_selection_vertical(document, selection, 1)
    assert_equal(selection.head, document.line_end(1))
    assert_true(selection.desired_column)
    assert_equal(Int(selection.desired_column.value()), 3)
    move_selection_vertical(document, selection, 1)
    assert_equal(selection.head, document.line_start(2) + 3)
    assert_true(selection.desired_column)
    assert_equal(Int(selection.desired_column.value()), 3)


def test_horizontal_motion_collapses_or_extends_selection() raises:
    var document = Document("a界b")
    var selection = Selection(1, 4)
    move_selection_left(document, selection)
    assert_equal(selection.anchor, 1)
    assert_equal(selection.head, 1)
    move_selection_right(document, selection, extend=True)
    assert_equal(selection.anchor, 1)
    assert_equal(selection.head, 4)


def test_selection_set_sorts_and_merges_overlaps() raises:
    var document = Document("0123456789ab")
    var selections = SelectionSet(
        [Selection(10, 10), Selection(5, 2), Selection(4, 8)], primary=2
    )
    selections.normalize(document)
    assert_equal(len(selections.selections), 2)
    assert_equal(selections.selections[0].start(), 2)
    assert_equal(selections.selections[0].end(), 8)
    assert_equal(selections.selections[1].start(), 10)
    assert_equal(selections.primary, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
