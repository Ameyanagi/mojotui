from std.testing import TestSuite, assert_equal, assert_true

from mojotui import (
    Alignment,
    Buffer,
    Color,
    Line,
    Rect,
    Span,
    Style,
    Text,
    render_line,
    render_text,
)


def test_span_and_line_widths_follow_terminal_columns() raises:
    var line = Line([Span("a"), Span("界"), Span("e\u0301")])
    assert_equal(line.width(), 4)


def test_centered_line_renders_wide_continuation_and_style() raises:
    var style = Style(Color.indexed(2), modifiers=Style.BOLD)
    var line = Line.from_text("A界", style, Alignment.CENTER)
    var buffer = Buffer(Rect(0, 0, 5, 1))
    var area = buffer.area.copy()
    render_line(line, area, buffer)
    assert_equal(buffer.cell({0, 0}).symbol, " ")
    assert_equal(buffer.cell({1, 0}).symbol, "A")
    assert_equal(buffer.cell({2, 0}).symbol, "界")
    assert_true(buffer.cell({3, 0}).continuation)
    assert_true(buffer.cell({2, 0}).style.equals(style))


def test_wrapping_preserves_grapheme_boundaries_and_styles() raises:
    var first = Style(Color.indexed(1))
    var second = Style(Color.indexed(4))
    var line = Line([Span("ab", first), Span("界c", second)])
    var wrapped = line.wrapped(3)
    assert_equal(len(wrapped), 2)
    assert_equal(wrapped[0].width(), 2)
    assert_equal(wrapped[1].width(), 3)

    var buffer = Buffer(Rect(0, 0, 3, 2))
    var area = buffer.area.copy()
    render_text(Text.from_line(line), area, buffer)
    assert_equal(buffer.cell({0, 0}).symbol, "a")
    assert_equal(buffer.cell({1, 0}).symbol, "b")
    assert_equal(buffer.cell({0, 1}).symbol, "界")
    assert_true(buffer.cell({1, 1}).continuation)
    assert_equal(buffer.cell({2, 1}).symbol, "c")
    assert_true(buffer.cell({0, 0}).style.equals(first))
    assert_true(buffer.cell({0, 1}).style.equals(second))


def test_right_alignment_uses_display_width() raises:
    var line = Line.from_text("界", alignment=Alignment.END)
    var buffer = Buffer(Rect(4, 7, 5, 1))
    var area = buffer.area.copy()
    render_line(line, area, buffer)
    assert_equal(buffer.cell({7, 7}).symbol, "界")
    assert_true(buffer.cell({8, 7}).continuation)


def test_text_clips_rows_to_render_area() raises:
    var text = Text(
        [Line.from_text("first"), Line.from_text("second"), Line.from_text("third")]
    )
    var buffer = Buffer(Rect(0, 0, 6, 2))
    var area = buffer.area.copy()
    render_text(text, area, buffer, wrap=False)
    assert_equal(buffer.cell({0, 0}).symbol, "f")
    assert_equal(buffer.cell({0, 1}).symbol, "s")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
