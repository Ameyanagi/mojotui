from std.testing import TestSuite, assert_equal, assert_raises

from mojotui import (
    Buffer,
    Cell,
    Color,
    Rect,
    Style,
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


def test_mismatched_areas_are_rejected() raises:
    var before = Buffer(Rect(0, 0, 1, 1))
    var after = Buffer(Rect(0, 0, 2, 1))
    with assert_raises(contains="equal areas"):
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
