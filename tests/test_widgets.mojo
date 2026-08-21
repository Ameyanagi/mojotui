from std.collections import List as MojoList
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from mojotui import (
    BarChart,
    Block,
    BorderType,
    Buffer,
    Cell,
    Clear,
    Color,
    Fill,
    Gauge,
    HighlightSpacing,
    Line,
    LineGauge,
    List,
    ListItem,
    ListState,
    Paragraph,
    Padding,
    Rect,
    Ratio,
    Row,
    Scrollbar,
    ScrollbarState,
    ScrollbarSymbols,
    Sparkline,
    Style,
    StylePatch,
    Table,
    TableSelection,
    TableState,
    Tabs,
    Text,
    TitlePosition,
    Alignment,
    Constraint,
    render_stateful_widget,
)


def row(buffer: Buffer, y: Int) raises -> String:
    var result = String()
    for x in range(buffer.area.x, buffer.area.right()):
        var cell = buffer.cell({x, y})
        result += "" if cell.continuation else cell.symbol
    return result^


def test_block_border_title_and_inner_area() raises:
    var block = Block.bordered(Line.from_text("Title"), padding_x=1)
    var area = Rect(0, 0, 10, 4)
    var buffer = Buffer(area)
    block.render(area, buffer)
    assert_equal(row(buffer, 0), "┌Title───┐")
    assert_equal(row(buffer, 1), "│        │")
    assert_equal(row(buffer, 3), "└────────┘")
    var inner = block.inner(area)
    assert_equal(inner.x, 2)
    assert_equal(inner.y, 1)
    assert_equal(inner.width, 6)
    assert_equal(inner.height, 2)


def test_block_renders_top_and_bottom_titles_without_clipping_last_character() raises:
    var block = Block.bordered(Line.from_text("Top")).title_bottom(
        Line.from_text("Bottom!!")
    )
    var area = Rect(0, 0, 10, 3)
    var buffer = Buffer(area)
    block.render(area, buffer)
    assert_equal(row(buffer, 0), "┌Top─────┐")
    assert_equal(row(buffer, 2), "└Bottom!!┘")


def test_paragraph_wraps_inside_block() raises:
    var block = Block.bordered(padding_x=1)
    var paragraph = Paragraph.with_block(Text.from_line(Line.from_text("ab界c")), block)
    var area = Rect(0, 0, 7, 4)
    var buffer = Buffer(area)
    paragraph.render(area, buffer)
    assert_equal(row(buffer, 1), "│ ab  │")
    assert_equal(row(buffer, 2), "│ 界c │")


def test_paragraph_word_wrap_trim_scroll_and_alignment() raises:
    var trimmed = Buffer(Rect(0, 0, 7, 2))
    var trimmed_area = trimmed.area.copy()
    Paragraph(Text.raw("hello world")).render(trimmed_area, trimmed)
    assert_equal(row(trimmed, 0), "hello  ")
    assert_equal(row(trimmed, 1), "world  ")

    var preserved = Buffer(Rect(0, 0, 7, 2))
    var preserved_area = preserved.area.copy()
    Paragraph(Text.raw("hello world"), trim=False).render(preserved_area, preserved)
    assert_equal(row(preserved, 1), " world ")

    var scrolled = Buffer(Rect(0, 0, 4, 1))
    var scrolled_area = scrolled.area.copy()
    Paragraph(Text.raw("one\ntwo\nthree")).without_wrap().scroll(
        vertical=1, horizontal=1
    ).render(scrolled_area, scrolled)
    assert_equal(row(scrolled, 0), "wo  ")

    var aligned = Buffer(Rect(0, 0, 4, 1))
    var aligned_area = aligned.area.copy()
    Paragraph(Text.raw("ok")).alignment(Alignment.END).render(aligned_area, aligned)
    assert_equal(row(aligned, 0), "  ok")


def test_paragraph_base_style_is_inherited_by_colored_spans() raises:
    var paragraph = Paragraph(
        Text.from_line(Line.styled("x", Style(foreground=Color.indexed(1)))),
        Style(background=Color.indexed(7)),
    )
    var buffer = Buffer(Rect(0, 0, 1, 1))
    var area = buffer.area.copy()
    paragraph.render(area, buffer)
    assert_true(buffer.cell({0, 0}).style.foreground.equals(Color.indexed(1)))
    assert_true(buffer.cell({0, 0}).style.background.equals(Color.indexed(7)))


def test_block_asymmetric_padding_border_set_and_bottom_title() raises:
    var block = Block.bordered(
        Line.raw("Bottom", Alignment.END),
        border_type=BorderType.ROUNDED,
        title_position=TitlePosition.BOTTOM,
    ).with_padding(Padding(left=1, right=2, top=1))
    var buffer = Buffer(Rect(0, 0, 10, 5))
    var area = buffer.area.copy()
    block.render(area, buffer)
    assert_equal(row(buffer, 0), "╭────────╮")
    assert_equal(row(buffer, 4), "╰──Bottom╯")
    var inner = block.inner(area)
    assert_equal(inner.x, 2)
    assert_equal(inner.y, 2)
    assert_equal(inner.width, 5)
    assert_equal(inner.height, 2)


def test_clear_removes_wide_cell_footprint() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    _ = buffer.set_grapheme({0, 0}, "界")
    _ = buffer.set_cell({2, 0}, Cell("x"))
    Clear().render(Rect(0, 0, 2, 1), buffer)
    assert_equal(row(buffer, 0), "  x")


def test_fill_clips_single_column_symbol_and_style() raises:
    var style = Style(modifiers=Style.BOLD)
    var buffer = Buffer(Rect(0, 0, 5, 2))
    Fill(".", style).render(Rect(1, 1, 3, 1), buffer)
    assert_equal(row(buffer, 0), "     ")
    assert_equal(row(buffer, 1), " ... ")
    assert_true(buffer.cell({1, 1}).style.has(Style.BOLD))

    with assert_raises(
        contains=(
            "fill symbol must be exactly one grapheme occupying one terminal"
            ' column; got "界"'
        )
    ):
        _ = Fill("界")
    with assert_raises(
        contains=(
            "fill symbol must be exactly one grapheme occupying one terminal"
            ' column; got "ab"'
        )
    ):
        _ = Fill("ab")


def test_gauge_and_line_gauge_snapshots() raises:
    var buffer = Buffer(Rect(0, 0, 8, 2))
    Gauge(Ratio(0.5)).render(Rect(0, 0, 8, 1), buffer)
    LineGauge(Ratio(0.25)).render(Rect(0, 1, 8, 1), buffer)
    assert_equal(row(buffer, 0), "████░░░░")
    assert_equal(row(buffer, 1), "━━──────")


def test_labeled_gauge_centers_text() raises:
    var buffer = Buffer(Rect(0, 0, 7, 1))
    var area = buffer.area.copy()
    Gauge.labeled(Ratio(1.0), Line.from_text("100%")).render(area, buffer)
    assert_equal(row(buffer, 0), "█100%██")


def test_sparkline_uses_newest_visible_samples() raises:
    var sparkline = Sparkline([0, 1, 2, 3, 4, 8], maximum=8)
    var buffer = Buffer(Rect(0, 0, 4, 1))
    var area = buffer.area.copy()
    sparkline.render(area, buffer)
    assert_equal(row(buffer, 0), "▂▃▄█")


def test_bar_chart_full_height_and_partial_eighth_bars() raises:
    var buffer = Buffer(Rect(0, 0, 3, 2))
    var area = buffer.area.copy()
    var values: MojoList[Float64] = [8.0, 4.0, 1.0]
    BarChart(values, gap=0, maximum=8.0).render(area, buffer)
    assert_equal(row(buffer, 0), "█  ")
    assert_equal(row(buffer, 1), "██▂")


def test_bar_chart_wide_bars_gaps_and_labels() raises:
    var buffer = Buffer(Rect(0, 0, 5, 3))
    var area = buffer.area.copy()
    var values: MojoList[Float64] = [8.0, 4.0]
    var labels: MojoList[String] = ["A", "B"]
    BarChart(
        values,
        labels=labels,
        bar_width=2,
        gap=1,
        maximum=8.0,
    ).render(area, buffer)
    assert_equal(row(buffer, 0), "██   ")
    assert_equal(row(buffer, 1), "██ ██")
    assert_equal(row(buffer, 2), "A  B ")


def test_bar_chart_skips_a_partially_clipped_bar() raises:
    var buffer = Buffer(Rect(0, 0, 4, 1))
    var area = buffer.area.copy()
    var values: MojoList[Float64] = [1.0, 1.0]
    BarChart(values, bar_width=2, gap=1, maximum=1.0).render(area, buffer)
    assert_equal(row(buffer, 0), "██  ")


def test_bar_chart_defaults_maximum_and_handles_all_zero_values() raises:
    var scaled = Buffer(Rect(0, 0, 2, 1))
    var scaled_area = scaled.area.copy()
    var scaled_values: MojoList[Float64] = [2.0, 1.0]
    BarChart(scaled_values, gap=0).render(scaled_area, scaled)
    assert_equal(row(scaled, 0), "█▄")

    var zero = Buffer(Rect(0, 0, 2, 1))
    var zero_area = zero.area.copy()
    var zero_values: MojoList[Float64] = [0.0, 0.0]
    BarChart(zero_values, gap=0).render(zero_area, zero)
    assert_equal(row(zero, 0), "  ")


def test_bar_chart_rejects_invalid_configuration() raises:
    var nan_values: MojoList[Float64] = [Float64("nan")]
    with assert_raises(
        contains="values[0] must be non-NaN and within [0, inf]; got nan"
    ):
        _ = BarChart(nan_values)
    var negative_values: MojoList[Float64] = [-1.0]
    with assert_raises(
        contains="values[0] must be non-NaN and within [0, inf]; got -1.0"
    ):
        _ = BarChart(negative_values)
    var single_value: MojoList[Float64] = [1.0]
    with assert_raises(contains="bar_width must be within [1, Int.MAX]; got 0"):
        _ = BarChart(single_value, bar_width=0)
    var mismatched_labels: MojoList[String] = ["A", "B"]
    with assert_raises(
        contains=(
            "labels must be empty or match len(values); got len(labels)=2,"
            " len(values)=1"
        )
    ):
        _ = BarChart(single_value, labels=mismatched_labels)


def test_widget_styles_are_written_to_cells() raises:
    var style = Style(modifiers=Style.BOLD)
    var buffer = Buffer(Rect(0, 0, 1, 1))
    var area = buffer.area.copy()
    Gauge(Ratio(1.0), filled_style=style).render(area, buffer)
    assert_true(buffer.cell({0, 0}).style.equals(style))


def test_list_scrolls_selection_into_visible_range() raises:
    var widget = List(
        [
            ListItem.from_text("zero"),
            ListItem.from_text("one"),
            ListItem.from_text("two"),
        ]
    )
    var state = ListState(selected=UInt(2))
    var buffer = Buffer(Rect(0, 0, 8, 2))
    var area = buffer.area.copy()
    render_stateful_widget(widget, area, buffer, state)
    assert_equal(state.offset, 1)
    assert_equal(row(buffer, 0), "  one   ")
    assert_equal(row(buffer, 1), "> two   ")
    assert_true(buffer.cell({0, 1}).style.has(Style.REVERSED))


def test_list_selection_patch_preserves_span_foreground() raises:
    var widget = List(
        [ListItem.from_line(Line.styled("item", Style(foreground=Color.indexed(2))))],
        selected_style=StylePatch(
            background=Color.indexed(4),
            add_modifiers=Style.REVERSED,
        ),
    )
    var state = ListState(selected=UInt(0))
    var buffer = Buffer(Rect(0, 0, 8, 1))
    var area = buffer.area.copy()
    widget.render(area, buffer, state)
    var style = buffer.cell({2, 0}).style.copy()
    assert_true(style.foreground.equals(Color.indexed(2)))
    assert_true(style.background.equals(Color.indexed(4)))
    assert_true(style.has(Style.REVERSED))


def test_list_navigation_clamps_at_collection_edges() raises:
    var state = ListState()
    state.next(2)
    state.next(2)
    state.next(2)
    assert_true(state.selected)
    assert_equal(Int(state.selected.value()), 1)
    state.previous(2)
    state.previous(2)
    assert_true(state.selected)
    assert_equal(Int(state.selected.value()), 0)
    state.select(None, 2)
    assert_false(state.selected)


def test_multiline_list_scroll_padding_and_highlight_spacing() raises:
    var widget = List(
        [
            ListItem.from_text("zero"),
            ListItem.from_text("one-a\none-b"),
            ListItem.from_text("two"),
            ListItem.from_text("three"),
        ],
        highlight_spacing=HighlightSpacing.WHEN_SELECTED,
        repeat_highlight_symbol=True,
        scroll_padding=1,
    )
    var state = ListState(selected=UInt(1))
    var buffer = Buffer(Rect(0, 0, 8, 3))
    var area = buffer.area.copy()
    widget.render(area, buffer, state)
    assert_equal(state.offset, 1)
    assert_equal(row(buffer, 0), "> one-a ")
    assert_equal(row(buffer, 1), "> one-b ")
    assert_equal(row(buffer, 2), "  two   ")

    var unselected = ListState()
    var compact = Buffer(Rect(0, 0, 4, 1))
    var compact_area = compact.area.copy()
    widget.render(compact_area, compact, unselected)
    assert_equal(row(compact, 0), "zero")


def test_table_header_columns_and_body_scroll_snapshot() raises:
    var table = Table.with_header(
        [
            Row.from_lines([Line.from_text("alpha"), Line.from_text("10")]),
            Row.from_lines([Line.from_text("beta"), Line.from_text("20")]),
            Row.from_lines([Line.from_text("gamma"), Line.from_text("30")]),
        ],
        [Constraint.length(4), Constraint.fill()],
        Row.from_lines([Line.from_text("NAME"), Line.from_text("CPU")]),
    )
    var state = TableState(selected=UInt(2))
    var buffer = Buffer(Rect(0, 0, 9, 3))
    var area = buffer.area.copy()
    table.render(area, buffer, state)
    assert_equal(state.offset, 1)
    assert_equal(row(buffer, 0), "NAME CPU ")
    assert_equal(row(buffer, 1), "beta 20  ")
    assert_equal(row(buffer, 2), "gamm 30  ")
    assert_true(buffer.cell({0, 2}).style.has(Style.REVERSED))


def test_table_multiline_rows_footer_and_cell_column_selection() raises:
    var table = Table.with_header(
        [
            Row([Text.raw("a\nb"), Text.raw("10\n11")], height=2),
            Row([Text.raw("c"), Text.raw("20")]),
        ],
        [Constraint.length(4), Constraint.fill()],
        Row([Text.raw("H1"), Text.raw("H2")]),
        selection=TableSelection.CELL,
    ).with_footer(
        Row([Text.raw("SUM"), Text.raw("30")]),
        StylePatch(add_modifiers=Style.BOLD),
    )
    var state = TableState(selected=UInt(1), selected_column=UInt(1))
    var buffer = Buffer(Rect(0, 0, 9, 5))
    var area = buffer.area.copy()
    table.render(area, buffer, state)
    assert_equal(row(buffer, 0), "H1   H2  ")
    assert_equal(row(buffer, 1), "a    10  ")
    assert_equal(row(buffer, 2), "b    11  ")
    assert_equal(row(buffer, 3), "c    20  ")
    assert_equal(row(buffer, 4), "SUM  30  ")
    assert_false(buffer.cell({0, 3}).style.has(Style.REVERSED))
    assert_true(buffer.cell({5, 3}).style.has(Style.REVERSED))
    assert_true(buffer.cell({0, 4}).style.has(Style.BOLD))

    var column_table = table.copy()
    column_table.selection = TableSelection.COLUMN
    var column_state = TableState(selected_column=UInt(1))
    var columns = Buffer(Rect(0, 0, 9, 5))
    var columns_area = columns.area.copy()
    column_table.render(columns_area, columns, column_state)
    assert_true(columns.cell({5, 1}).style.has(Style.REVERSED))
    assert_true(columns.cell({5, 3}).style.has(Style.REVERSED))
    assert_false(columns.cell({0, 1}).style.has(Style.REVERSED))


def test_tabs_snapshot_and_selected_style() raises:
    var tabs = Tabs([Line.from_text("Home"), Line.from_text("Logs")], selected=1)
    var buffer = Buffer(Rect(0, 0, 13, 1))
    var area = buffer.area.copy()
    tabs.render(area, buffer)
    assert_equal(row(buffer, 0), " Home │ Logs ")
    assert_true(buffer.cell({8, 0}).style.has(Style.REVERSED))


def test_vertical_scrollbar_tracks_viewport_position() raises:
    var scrollbar = Scrollbar()
    var state = ScrollbarState(content_length=10, position=4, viewport_length=2)
    var buffer = Buffer(Rect(0, 0, 3, 5))
    var area = buffer.area.copy()
    scrollbar.render(area, buffer, state)
    assert_equal(row(buffer, 0), "  │")
    assert_equal(row(buffer, 1), "  │")
    assert_equal(row(buffer, 2), "  █")
    assert_equal(row(buffer, 3), "  │")
    assert_equal(row(buffer, 4), "  │")


def test_horizontal_scrollbar_reaches_end_and_clamps_state() raises:
    var scrollbar = Scrollbar.horizontal()
    var state = ScrollbarState(content_length=10, position=99, viewport_length=4)
    var buffer = Buffer(Rect(0, 0, 5, 2))
    var area = buffer.area.copy()
    scrollbar.render(area, buffer, state)
    assert_equal(state.position, 6)
    assert_equal(row(buffer, 1), "───██")


def test_scrollbar_fills_track_when_content_fits() raises:
    var scrollbar = Scrollbar()
    var state = ScrollbarState(content_length=2, viewport_length=4)
    var buffer = Buffer(Rect(0, 0, 1, 3))
    var area = buffer.area.copy()
    scrollbar.render(area, buffer, state)
    assert_equal(row(buffer, 0), "█")
    assert_equal(row(buffer, 1), "█")
    assert_equal(row(buffer, 2), "█")


def test_ratio_and_scrollbar_symbols_reject_invalid_configuration() raises:
    with assert_raises(contains="ratio must be finite and within [0, 1]; got -0.1"):
        _ = Ratio(-0.1)
    with assert_raises(contains="ratio must be finite and within [0, 1]; got nan"):
        _ = Ratio(Float64("nan"))
    with assert_raises(contains="percent must be within [0, 100]; got 101"):
        _ = Ratio.percent(101)
    with assert_raises(
        contains='scrollbar track symbol must be exactly one terminal column; got "界"'
    ):
        _ = ScrollbarSymbols("界", "█")
    with assert_raises(
        contains='scrollbar thumb symbol must be exactly one terminal column; got "界"'
    ):
        _ = ScrollbarSymbols("│", "界")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
