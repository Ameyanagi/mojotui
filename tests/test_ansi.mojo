from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from mojotui import (
    Buffer,
    Cell,
    Color,
    Rect,
    Style,
    diff_frame,
    encode_ansi_diff,
    encode_ansi_inline_diff,
    inline_clear_sequence,
    inline_reserve_sequence,
)


def test_unchanged_buffer_emits_nothing() raises:
    var before = Buffer(Rect(0, 0, 2, 1))
    var after = before.copy()
    assert_equal(encode_ansi_diff(before, after), "")


def test_contiguous_changes_share_one_cursor_move() raises:
    var before = Buffer(Rect(0, 0, 4, 1))
    var after = before.copy()
    _ = after.set_cell({1, 0}, Cell("a"))
    _ = after.set_cell({2, 0}, Cell("b"))
    assert_equal(encode_ansi_diff(before, after), "\x1b[0m\x1b[1;2Hab")


def test_disjoint_changes_reposition_the_cursor() raises:
    var before = Buffer(Rect(0, 0, 4, 2))
    var after = before.copy()
    _ = after.set_cell({0, 0}, Cell("a"))
    _ = after.set_cell({3, 1}, Cell("b"))
    assert_equal(
        encode_ansi_diff(before, after),
        "\x1b[0m\x1b[1;1Ha\x1b[2;4Hb",
    )


def test_style_transition_uses_indexed_and_rgb_colors() raises:
    var before = Buffer(Rect(0, 0, 2, 1))
    var after = before.copy()
    var first_style = Style(Color.indexed(196), modifiers=Style.BOLD)
    var second_style = Style(
        Color.rgb(1, 2, 3),
        Color.rgb(4, 5, 6),
        Style.UNDERLINED,
    )
    _ = after.set_cell({0, 0}, Cell("a", style=first_style))
    _ = after.set_cell({1, 0}, Cell("b", style=second_style))
    assert_equal(
        encode_ansi_diff(before, after),
        (
            "\x1b[0m\x1b[1;1H"
            "\x1b[0m\x1b[1m\x1b[38;5;196ma"
            "\x1b[0m\x1b[4m\x1b[38;2;1;2;3m\x1b[48;2;4;5;6mb"
            "\x1b[0m"
        ),
    )


def test_underline_color_uses_sgr_58() raises:
    var before = Buffer(Rect(0, 0, 1, 1))
    var after = before.copy()
    var style = Style(
        modifiers=Style.UNDERLINED,
        underline_color=Color.indexed(5),
    )
    _ = after.set_cell({0, 0}, Cell("u", style=style))
    assert_true("\x1b[58;5;5m" in encode_ansi_diff(before, after))


def test_ansi16_colors_use_portable_basic_sgr_codes() raises:
    var before = Buffer(Rect(0, 0, 1, 1))
    var after = before.copy()
    _ = after.set_cell(
        {0, 0},
        Cell(
            "x",
            style=Style(
                foreground=Color.indexed(1),
                background=Color.indexed(12),
            ),
        ),
    )
    var encoded = encode_ansi_diff(before, after)
    assert_true("\x1b[31m" in encoded)
    assert_true("\x1b[104m" in encoded)
    assert_true(";5;" not in encoded)


def test_wide_cell_skips_its_continuation() raises:
    var before = Buffer(Rect(0, 0, 3, 1))
    var after = before.copy()
    _ = after.set_grapheme({0, 0}, "界")
    _ = after.set_cell({2, 0}, Cell("x"))
    assert_equal(encode_ansi_diff(before, after), "\x1b[0m\x1b[1;1H界x")


def test_replacing_wide_cell_repaints_its_second_column() raises:
    var before = Buffer(Rect(0, 0, 3, 1))
    _ = before.set_grapheme({0, 0}, "界")
    var after = before.copy()
    _ = after.set_cell({0, 0}, Cell("x"))
    assert_equal(encode_ansi_diff(before, after), "\x1b[0m\x1b[1;1Hx ")


def test_full_redraw_patch_is_row_major_and_skips_blank_continuations() raises:
    var before = Buffer(Rect(4, 7, 3, 2))
    var after = before.copy()
    _ = after.set_cell({6, 7}, Cell("a"))
    _ = after.set_grapheme({4, 8}, "界")
    var patch = diff_frame(before, after, full_redraw=True)
    assert_equal(len(patch.changes), 2)
    assert_true(patch.changes[0].point.equals({6, 7}))
    assert_true(patch.changes[1].point.equals({4, 8}))
    assert_equal(patch.changes[1].cell.symbol, "界")


def test_mismatched_areas_are_rejected() raises:
    var before = Buffer(Rect(0, 0, 1, 1))
    var after = Buffer(Rect(0, 0, 2, 1))
    with assert_raises(
        contains=(
            "frame diff buffers must have equal areas; got"
            " before=Rect(0, 0, 1, 1), after=Rect(0, 0, 2, 1)"
        )
    ):
        _ = encode_ansi_diff(before, after)


def test_inline_diff_uses_relative_rows_from_bottom_anchor() raises:
    var before = Buffer(Rect(0, 0, 4, 2))
    var after = before.copy()
    _ = after.set_cell({0, 0}, Cell("a"))
    _ = after.set_cell({3, 1}, Cell("b"))
    assert_equal(
        encode_ansi_inline_diff(before, after),
        "\x1b[s\x1b[u\x1b[2A\r\x1b[0ma\x1b[u\x1b[1A\r\x1b[3C\x1b[0mb\x1b[u\x1b[0m",
    )


def test_inline_reservation_and_clear_are_fixed_height() raises:
    assert_equal(inline_reserve_sequence(2), "\x1b[2K\r\n\x1b[2K\r\n")
    assert_equal(
        inline_clear_sequence(2),
        "\x1b[s\x1b[u\x1b[2A\r\x1b[2K\x1b[u\x1b[1A\r\x1b[2K\x1b[u",
    )
    assert_equal(inline_reserve_sequence(-1), "")
    assert_equal(inline_clear_sequence(0), "")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
