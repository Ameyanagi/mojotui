from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from mojotui import Buffer, Cell, Point, Rect, Size, Style


def test_size_normalizes_negative_dimensions() raises:
    var size = Size(-4, 3)
    assert_equal(size.width, 0)
    assert_equal(size.height, 3)
    assert_true(size.is_empty())


def test_size_area() raises:
    assert_equal(Size(12, 5).area(), 60)


def test_rect_uses_half_open_bounds() raises:
    var area = Rect(2, 3, 4, 2)
    assert_true(area.contains(Point(2, 3)))
    assert_true(area.contains(Point(5, 4)))
    assert_false(area.contains(Point(6, 4)))
    assert_false(area.contains(Point(5, 5)))


def test_rect_intersection() raises:
    var overlap = Rect(0, 0, 5, 4).intersection(Rect(3, 2, 5, 5))
    assert_equal(overlap.x, 3)
    assert_equal(overlap.y, 2)
    assert_equal(overlap.width, 2)
    assert_equal(overlap.height, 2)


def test_rect_disjoint_intersection_is_empty() raises:
    var overlap = Rect(0, 0, 2, 2).intersection(Rect(5, 5, 2, 2))
    assert_true(overlap.is_empty())


def test_rect_inset_clamps_to_empty() raises:
    var inset = Rect(10, 20, 3, 3).inset(10, 10)
    assert_equal(inset.x, 11)
    assert_equal(inset.y, 21)
    assert_equal(inset.width, 1)
    assert_equal(inset.height, 1)


def test_geometry_translation_saturates_at_integer_boundaries() raises:
    var point = Point(Int.MAX, Int.MIN).translated(1, -1)
    assert_equal(point.x, Int.MAX)
    assert_equal(point.y, Int.MIN)
    var area = Rect(Int.MAX - 1, 0, 10, 1)
    assert_equal(area.width, 1)
    assert_equal(area.translated(5, 0).width, 0)


def test_rect_union_covers_both_rectangles() raises:
    var combined = Rect(-2, 3, 4, 2).union(Rect(1, 1, 5, 4))
    assert_equal(combined.x, -2)
    assert_equal(combined.y, 1)
    assert_equal(combined.width, 8)
    assert_equal(combined.height, 4)


def test_buffer_starts_blank() raises:
    var buffer = Buffer(Rect(4, 7, 3, 2))
    assert_equal(len(buffer), 6)
    assert_equal(buffer.cell(Point(4, 7)).symbol, " ")


def test_buffer_rejects_out_of_bounds_write() raises:
    var buffer = Buffer(Rect(0, 0, 2, 2))
    assert_false(buffer.set_cell(Point(2, 0), Cell("x")))
    assert_equal(buffer.cell(Point(1, 0)).symbol, " ")


def test_buffer_fill_clips() raises:
    var buffer = Buffer(Rect(0, 0, 3, 2))
    buffer.fill(Rect(2, -1, 3, 3), Cell("x"))
    assert_equal(buffer.cell(Point(0, 0)).symbol, " ")
    assert_equal(buffer.cell(Point(2, 0)).symbol, "x")
    assert_equal(buffer.cell(Point(2, 1)).symbol, "x")


def test_buffer_diff_counts_changed_cells() raises:
    var before = Buffer(Rect(0, 0, 2, 2))
    var after = Buffer(Rect(0, 0, 2, 2))
    _ = after.set_cell(Point(1, 1), Cell("x"))
    assert_equal(before.changed_cell_count(after), 1)


def test_cell_from_grapheme_uses_unicode_width() raises:
    assert_equal(Cell.from_grapheme("界").width, 2)
    assert_equal(Cell.from_grapheme("e\u0301").width, 1)


def test_cell_from_grapheme_rejects_multiple_graphemes() raises:
    with assert_raises(contains="exactly one grapheme"):
        _ = Cell.from_grapheme("ab")


def test_buffer_places_wide_grapheme_and_continuation() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    assert_true(buffer.set_grapheme({0, 0}, "界", Style.plain()))
    assert_equal(buffer.cell({0, 0}).width, 2)
    assert_true(buffer.cell({1, 0}).continuation)


def test_overwriting_wide_leader_clears_continuation() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    assert_true(buffer.set_grapheme({0, 0}, "界"))
    assert_true(buffer.set_cell({0, 0}, Cell("x")))
    assert_equal(buffer.cell({0, 0}).symbol, "x")
    assert_equal(buffer.cell({1, 0}).symbol, " ")
    assert_false(buffer.cell({1, 0}).continuation)


def test_overwriting_wide_continuation_clears_leader() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    assert_true(buffer.set_grapheme({0, 0}, "界"))
    assert_true(buffer.set_cell({1, 0}, Cell("x")))
    assert_equal(buffer.cell({0, 0}).symbol, " ")
    assert_equal(buffer.cell({1, 0}).symbol, "x")


def test_wide_grapheme_does_not_partially_write_at_right_edge() raises:
    var buffer = Buffer(Rect(0, 0, 2, 1))
    assert_false(buffer.set_grapheme({1, 0}, "界"))
    assert_equal(buffer.cell({1, 0}).symbol, " ")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
