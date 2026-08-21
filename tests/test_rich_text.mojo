from std.collections import List as MojoList
from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from mojotui import (
    Alignment,
    Buffer,
    Color,
    Line,
    Rect,
    Span,
    Style,
    StylePatch,
    Text,
    render_line,
    render_text,
    render_widget,
)


def test_span_and_line_widths_follow_terminal_columns() raises:
    var line = Line([Span("a"), Span("界"), Span("e\u0301")])
    assert_equal(line.width(), 4)


def test_highlighted_partitions_ascii_and_merges_adjacent_positions() raises:
    var patch = StylePatch(
        foreground=Color.indexed(3),
        add_modifiers=Style.BOLD,
    )
    var single: MojoList[Int] = [1]
    var line = Line.highlighted("abc", single, patch)
    assert_equal(len(line.spans), 3)
    assert_equal(line.spans[0].content, "a")
    assert_equal(line.spans[1].content, "b")
    assert_equal(line.spans[2].content, "c")
    assert_true(line.spans[1].resolved_style().equals(patch.resolved()))

    var adjacent: MojoList[Int] = [1, 2]
    var merged = Line.highlighted("abcd", adjacent, patch)
    assert_equal(len(merged.spans), 3)
    assert_equal(merged.spans[1].content, "bc")


def test_highlighted_propagates_moji_position_errors() raises:
    var unsorted: MojoList[Int] = [2, 1]
    with assert_raises(contains="code-point positions must be strictly increasing"):
        _ = Line.highlighted("abc", unsorted, StylePatch.plain())

    var out_of_range: MojoList[Int] = [3]
    with assert_raises(
        contains="code-point index 3 is outside text code-point count 3"
    ):
        _ = Line.highlighted("abc", out_of_range, StylePatch.plain())


def test_highlighted_empty_positions_use_base_style_for_whole_line() raises:
    var positions = MojoList[Int]()
    var base = StylePatch(
        background=Color.indexed(4),
        add_modifiers=Style.UNDERLINED,
    )
    var line = Line.highlighted(
        "whole", positions, StylePatch(add_modifiers=Style.BOLD), base=base
    )
    assert_equal(len(line.spans), 1)
    assert_equal(line.spans[0].content, "whole")
    assert_true(line.spans[0].resolved_style().equals(base.resolved()))


def test_highlighted_expands_matches_to_wide_grapheme_boundaries() raises:
    var patch = StylePatch(
        foreground=Color.indexed(5),
        add_modifiers=Style.BOLD,
    )
    var middle_of_zwj: MojoList[Int] = [3]
    var family = Line.highlighted("a👩‍👩‍👧b", middle_of_zwj, patch)
    assert_equal(len(family.spans), 3)
    assert_equal(family.spans[0].content, "a")
    assert_equal(family.spans[1].content, "👩‍👩‍👧")
    assert_equal(family.spans[2].content, "b")

    var buffer = Buffer(Rect(0, 0, 4, 1))
    var area = buffer.area.copy()
    render_line(family, area, buffer)
    assert_equal(buffer.cell({0, 0}).symbol, "a")
    assert_equal(buffer.cell({1, 0}).symbol, "👩‍👩‍👧")
    assert_true(buffer.cell({2, 0}).continuation)
    assert_equal(buffer.cell({3, 0}).symbol, "b")
    assert_true(buffer.cell({1, 0}).style.equals(patch.resolved()))

    var cjk_position: MojoList[Int] = [1]
    var cjk = Line.highlighted("a界b", cjk_position, patch)
    assert_equal(cjk.spans[1].content, "界")
    assert_equal(cjk.spans[1].width(), 2)


def test_highlighted_composes_base_and_match_styles() raises:
    var base = StylePatch(
        background=Color.indexed(1),
        add_modifiers=Style.UNDERLINED,
    )
    var patch = StylePatch(
        foreground=Color.indexed(6),
        add_modifiers=Style.BOLD,
    )
    var positions: MojoList[Int] = [1]
    var line = Line.highlighted("abc", positions, patch, base=base)
    assert_true(line.spans[0].resolved_style().equals(base.resolved()))
    assert_true(line.spans[1].resolved_style().equals(base.then(patch).resolved()))
    assert_true(line.spans[2].resolved_style().equals(base.resolved()))


def test_line_style_patch_preserves_individual_span_foregrounds() raises:
    var line = Line(
        [
            Span("left", Style(foreground=Color.indexed(1))),
            Span("right", Style(foreground=Color.indexed(2))),
        ]
    )
    var patched = line.patched_style(
        StylePatch(
            background=Color.indexed(7),
            add_modifiers=Style.UNDERLINED,
        )
    )
    assert_true(patched.spans[0].resolved_style().foreground.equals(Color.indexed(1)))
    assert_true(patched.spans[1].resolved_style().foreground.equals(Color.indexed(2)))
    assert_true(patched.spans[0].resolved_style().background.equals(Color.indexed(7)))
    assert_true(patched.spans[1].resolved_style().has(Style.UNDERLINED))


def test_span_and_line_style_shorthand_builders_chain() raises:
    var foreground = Color.rgb(255, 0, 0)
    var background = Color.indexed(4)
    var span = (
        Span.raw("hot")
        .bold()
        .italic()
        .dim()
        .underlined()
        .reversed()
        .crossed_out()
        .fg(foreground)
        .bg(background)
    )
    var span_style = span.resolved_style()
    assert_true(span_style.foreground.equals(foreground))
    assert_true(span_style.background.equals(background))
    assert_true(span_style.has(Style.BOLD))
    assert_true(span_style.has(Style.ITALIC))
    assert_true(span_style.has(Style.DIM))
    assert_true(span_style.has(Style.UNDERLINED))
    assert_true(span_style.has(Style.REVERSED))
    assert_true(span_style.has(Style.CROSSED_OUT))

    var line = (
        Line.raw("hot")
        .bold()
        .italic()
        .dim()
        .underlined()
        .reversed()
        .crossed_out()
        .fg(foreground)
        .bg(background)
    )
    assert_true(line.spans[0].resolved_style().equals(span_style))


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


def test_wrapping_preserves_grapheme_wider_than_available_width() raises:
    var style = Style(foreground=Color.indexed(5))
    var wrapped = Line.styled("界a", style).wrapped(1)
    assert_equal(len(wrapped), 2)
    assert_equal(wrapped[0].width(), 2)
    assert_equal(wrapped[0].spans[0].content, "界")
    assert_true(wrapped[0].spans[0].resolved_style().equals(style))
    assert_equal(wrapped[1].spans[0].content, "a")


def test_right_alignment_uses_display_width() raises:
    var line = Line.from_text("界", alignment=Alignment.END)
    var buffer = Buffer(Rect(4, 7, 5, 1))
    var area = buffer.area.copy()
    render_line(line, area, buffer)
    assert_equal(buffer.cell({7, 7}).symbol, "界")
    assert_true(buffer.cell({8, 7}).continuation)


def test_text_clips_rows_to_render_area() raises:
    var text = Text(
        [
            Line.from_text("first"),
            Line.from_text("second"),
            Line.from_text("third"),
        ]
    )
    var buffer = Buffer(Rect(0, 0, 6, 2))
    var area = buffer.area.copy()
    render_text(text, area, buffer, wrap=False)
    assert_equal(buffer.cell({0, 0}).symbol, "f")
    assert_equal(buffer.cell({0, 1}).symbol, "s")


def test_rich_text_conveniences_and_widget_rendering() raises:
    var first = Span.styled("hi", Style(foreground=Color.indexed(3)))
    var line = Line.raw("[")
    line.append(first)
    line.append(Span.raw("]"))
    var text = Text.from_line(line)
    text.append(Line.styled("ok", Style(modifiers=Style.BOLD)))
    assert_equal(text.width(), 4)
    assert_equal(text.height(), 2)

    var buffer = Buffer(Rect(0, 0, 4, 2))
    var area = buffer.area.copy()
    render_widget(text, area, buffer)
    assert_equal(buffer.cell({0, 0}).symbol, "[")
    assert_equal(buffer.cell({1, 0}).symbol, "h")
    assert_equal(buffer.cell({0, 1}).symbol, "o")
    assert_true(buffer.cell({0, 1}).style.has(Style.BOLD))


def test_text_raw_splits_lines_and_alignment_builder_applies_to_all() raises:
    var text = Text.raw("a\nbb").aligned(Alignment.END)
    assert_equal(text.height(), 2)
    assert_equal(text.width(), 2)
    assert_true(text.lines[0].alignment == Alignment.END)
    assert_true(text.lines[1].alignment == Alignment.END)

    var buffer = Buffer(Rect(0, 0, 3, 2))
    var area = buffer.area.copy()
    text.render(area, buffer)
    assert_equal(buffer.cell({2, 0}).symbol, "a")
    assert_equal(buffer.cell({1, 1}).symbol, "b")


def test_line_write_reports_clipping_across_styled_spans() raises:
    var line = Line(
        [
            Span.styled("ab", Style(foreground=Color.indexed(1))),
            Span.styled("界", Style(foreground=Color.indexed(2))),
        ]
    )
    var buffer = Buffer(Rect(0, 0, 3, 1))
    var outcome = line.write({0, 0}, buffer)
    assert_equal(outcome.graphemes_written, 2)
    assert_equal(outcome.columns_written, 2)
    assert_true(outcome.truncated)
    assert_true(buffer.cell({0, 0}).style.foreground.equals(Color.indexed(1)))
    assert_equal(buffer.cell({2, 0}).symbol, " ")


def test_word_wrap_uses_pinned_unicode_whitespace_property() raises:
    var wrapped = Line.raw("ab\u3000cd").wrapped_words(4)
    assert_equal(len(wrapped), 2)
    assert_equal(wrapped[0].spans[0].content, "a")
    assert_equal(wrapped[0].width(), 2)
    assert_equal(wrapped[1].width(), 2)
    assert_equal(wrapped[1].spans[0].content, "c")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
