from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from mojotui import Buffer, Cell, Color, Point, Rect, Size, Style, StylePatch


def _assert_wide_cell_invariants(buffer: Buffer) raises:
    for y in range(buffer.area.y, buffer.area.bottom()):
        for x in range(buffer.area.x, buffer.area.right()):
            var cell = buffer.cell(Point(x, y))
            if cell.continuation:
                assert_true(x > buffer.area.x)
                assert_equal(buffer.cell(Point(x - 1, y)).width, 2)
            if cell.width == 2:
                assert_true(x + 1 < buffer.area.right())
                assert_true(buffer.cell(Point(x + 1, y)).continuation)


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


def test_buffer_cell_error_echoes_point_and_area() raises:
    var buffer = Buffer(Rect(3, 4, 2, 1))
    with assert_raises(contains="point (2, 4) is outside buffer area Rect(3, 4, 2, 1)"):
        _ = buffer.cell(Point(2, 4))


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


def test_rect_centered_places_exact_extents() raises:
    var centered = Rect(10, 20, 10, 8).centered(4, 2)
    assert_true(centered.equals(Rect(13, 23, 4, 2)))


def test_rect_centered_biases_odd_remainders_left_and_top() raises:
    var centered = Rect(10, 20, 9, 7).centered(4, 2)
    assert_true(centered.equals(Rect(12, 22, 4, 2)))


def test_rect_centered_clamps_oversized_extents() raises:
    var area = Rect(10, 20, 4, 3)
    assert_true(area.centered(20, 30).equals(area))


def test_rect_centered_returns_empty_at_empty_origin() raises:
    assert_true(Rect(10, 20, 0, 7).centered(4, 3).equals(Rect(10, 20, 0, 0)))


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


def test_buffer_fill_clears_wide_leader_across_left_boundary() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    _ = buffer.set_grapheme({0, 0}, "界")
    buffer.fill(Rect(1, 0, 1, 1), Cell("x"))
    assert_equal(buffer.cell({0, 0}).symbol, " ")
    assert_equal(buffer.cell({1, 0}).symbol, "x")
    _assert_wide_cell_invariants(buffer)


def test_buffer_fill_clears_wide_continuation_across_right_boundary() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    _ = buffer.set_grapheme({1, 0}, "界")
    buffer.fill(Rect(1, 0, 1, 1), Cell("x"))
    assert_equal(buffer.cell({1, 0}).symbol, "x")
    assert_equal(buffer.cell({2, 0}).symbol, " ")
    assert_false(buffer.cell({2, 0}).continuation)
    _assert_wide_cell_invariants(buffer)


def test_buffer_diff_counts_changed_cells() raises:
    var before = Buffer(Rect(0, 0, 2, 2))
    var after = Buffer(Rect(0, 0, 2, 2))
    _ = after.set_cell(Point(1, 1), Cell("x"))
    assert_equal(before.changed_cell_count(after), 1)


def test_buffer_differences_are_row_major_and_include_both_cells() raises:
    var before = Buffer(Rect(3, 4, 2, 2))
    var after = Buffer(Rect(3, 4, 2, 2))
    _ = after.set_grapheme({4, 4}, "x")
    _ = after.set_grapheme({3, 5}, "y")
    var changes = before.differences(after)
    assert_equal(len(changes), 2)
    assert_true(changes[0].point.equals(Point(4, 4)))
    assert_equal(changes[0].before.symbol, " ")
    assert_equal(changes[0].after.symbol, "x")
    assert_true(changes[1].point.equals(Point(3, 5)))


def test_buffer_differences_reject_mismatched_areas() raises:
    with assert_raises(
        contains=(
            "cannot compare buffers with different areas; got"
            " self=Rect(0, 0, 1, 1), other=Rect(0, 0, 2, 1)"
        )
    ):
        _ = Buffer(Rect(0, 0, 1, 1)).differences(Buffer(Rect(0, 0, 2, 1)))


def test_color_index_rejects_out_of_range_values() raises:
    with assert_raises(contains="color index must be within [0, 255]; got 300"):
        _ = Color.indexed(300)


def test_style_patches_preserve_unspecified_fields_and_compose() raises:
    var base = Style(
        foreground=Color.indexed(1),
        background=Color.indexed(2),
        modifiers=Style.BOLD | Style.ITALIC,
    )
    var first = StylePatch(
        background=Color.indexed(3),
        add_modifiers=Style.UNDERLINED,
        remove_modifiers=Style.BOLD,
    )
    var second = StylePatch(
        foreground=Color.default(),
        add_modifiers=Style.BOLD,
        remove_modifiers=Style.ITALIC,
    )
    var sequential = base.patched(first).patched(second)
    var composed = base.patched(first.then(second))
    assert_true(sequential.equals(composed))
    assert_true(composed.foreground.equals(Color.default()))
    assert_true(composed.background.equals(Color.indexed(3)))
    assert_true(composed.has(Style.BOLD))
    assert_true(composed.has(Style.UNDERLINED))
    assert_false(composed.has(Style.ITALIC))


def test_style_shorthand_builders_chain_without_erasing_fields() raises:
    var foreground = Color.rgb(255, 0, 0)
    var background = Color.indexed(4)
    var patch = (
        StylePatch.plain()
        .bold()
        .italic()
        .dim()
        .underlined()
        .reversed()
        .crossed_out()
        .fg(foreground)
        .bg(background)
    )
    var resolved_patch = patch.resolved()
    assert_true(resolved_patch.foreground.equals(foreground))
    assert_true(resolved_patch.background.equals(background))
    assert_true(resolved_patch.has(Style.BOLD))
    assert_true(resolved_patch.has(Style.ITALIC))
    assert_true(resolved_patch.has(Style.DIM))
    assert_true(resolved_patch.has(Style.UNDERLINED))
    assert_true(resolved_patch.has(Style.REVERSED))
    assert_true(resolved_patch.has(Style.CROSSED_OUT))

    var resolved = (
        Style.plain()
        .bold()
        .italic()
        .dim()
        .underlined()
        .reversed()
        .crossed_out()
        .fg(foreground)
        .bg(background)
    )
    assert_true(resolved.equals(resolved_patch))


def test_buffer_style_patch_preserves_wide_cell_footprint() raises:
    var buffer = Buffer(Rect(0, 0, 2, 1))
    _ = buffer.set_grapheme({0, 0}, "界")
    var area = buffer.area.copy()
    buffer.patch_style(
        area,
        StylePatch(
            foreground=Color.indexed(4),
            add_modifiers=Style.BOLD,
        ),
    )
    assert_equal(buffer.cell({0, 0}).symbol, "界")
    assert_true(buffer.cell({1, 0}).continuation)
    assert_true(buffer.cell({0, 0}).style.has(Style.BOLD))
    assert_true(buffer.cell({1, 0}).style.has(Style.BOLD))


def test_buffer_string_write_reports_wide_grapheme_overflow() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    var result = buffer.set_string({0, 0}, "ab界")
    assert_equal(result.graphemes_written, 2)
    assert_equal(result.columns_written, 2)
    assert_equal(result.end.x, 2)
    assert_true(result.truncated)
    assert_equal(buffer.cell({0, 0}).symbol, "a")
    assert_equal(buffer.cell({1, 0}).symbol, "b")
    assert_equal(buffer.cell({2, 0}).symbol, " ")
    assert_false(buffer.cell({2, 0}).continuation)


def test_buffer_resize_drops_partial_wide_cells() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    _ = buffer.set_grapheme({1, 0}, "界")
    buffer.resize(Rect(0, 0, 2, 1))
    assert_equal(buffer.cell({1, 0}).symbol, " ")
    assert_false(buffer.cell({1, 0}).continuation)


def test_buffer_merge_expands_and_overlays_complete_cells() raises:
    var base = Buffer(Rect(0, 0, 2, 1))
    _ = base.set_grapheme({0, 0}, "a")
    var overlay = Buffer(Rect(1, 0, 2, 1))
    _ = overlay.set_grapheme({1, 0}, "界")
    base.merge(overlay)
    assert_equal(base.area.width, 3)
    assert_equal(base.cell({0, 0}).symbol, "a")
    assert_equal(base.cell({1, 0}).symbol, "界")
    assert_true(base.cell({2, 0}).continuation)


def test_buffer_conveniences_preserve_wide_invariants_across_widths() raises:
    for target_width in range(7):
        var buffer = Buffer(Rect(-2, 3, 6, 1))
        _ = buffer.set_string({-2, 3}, "a界bc")
        buffer.patch_style(
            Rect(-1, 3, 4, 1),
            StylePatch(add_modifiers=Style.UNDERLINED),
        )
        buffer.resize(Rect(-2, 3, target_width, 1))
        _assert_wide_cell_invariants(buffer)

        var overlay = Buffer(Rect(-1, 3, 3, 1))
        _ = overlay.set_string({-1, 3}, "界x")
        buffer.merge(overlay)
        _assert_wide_cell_invariants(buffer)
        assert_equal(len(buffer.differences(buffer.copy())), 0)


def test_cell_from_grapheme_uses_unicode_width() raises:
    assert_equal(Cell.from_grapheme("界").width, 2)
    assert_equal(Cell.from_grapheme("e\u0301").width, 1)


def test_cell_from_grapheme_rejects_multiple_graphemes() raises:
    with assert_raises(contains='cell symbol must be exactly one grapheme; got "ab"'):
        _ = Cell.from_grapheme("ab")


def test_set_cell_rejects_unmeasured_or_structurally_invalid_cells() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    assert_false(buffer.set_cell({0, 0}, Cell("A", width=2)))
    assert_false(buffer.set_cell({0, 0}, Cell("界")))
    assert_false(buffer.set_cell({0, 0}, Cell("", width=0, continuation=True)))
    assert_true(buffer.cell({0, 0}).equals(Cell.blank()))


def test_frame_topology_validation_detects_public_field_corruption() raises:
    var buffer = Buffer(Rect(0, 0, 2, 1))
    _ = buffer.set_grapheme({0, 0}, "界")
    buffer.cells[1].continuation = False
    with assert_raises(contains="wide-cell leader has no continuation"):
        buffer.validate_topology()


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
