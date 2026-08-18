from std.testing import TestSuite, assert_equal, assert_true

from mojotui import (
    Block,
    Buffer,
    Cell,
    Clear,
    Gauge,
    Line,
    LineGauge,
    List,
    ListItem,
    ListState,
    Paragraph,
    Rect,
    Row,
    Scrollbar,
    ScrollbarState,
    Sparkline,
    Style,
    Table,
    TableState,
    Tabs,
    Text,
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


def test_paragraph_wraps_inside_block() raises:
    var block = Block.bordered(padding_x=1)
    var paragraph = Paragraph.with_block(Text.from_line(Line.from_text("ab界c")), block)
    var area = Rect(0, 0, 7, 4)
    var buffer = Buffer(area)
    paragraph.render(area, buffer)
    assert_equal(row(buffer, 1), "│ ab  │")
    assert_equal(row(buffer, 2), "│ 界c │")


def test_clear_removes_wide_cell_footprint() raises:
    var buffer = Buffer(Rect(0, 0, 3, 1))
    _ = buffer.set_grapheme({0, 0}, "界")
    _ = buffer.set_cell({2, 0}, Cell("x"))
    Clear().render(Rect(0, 0, 2, 1), buffer)
    assert_equal(row(buffer, 0), "  x")


def test_gauge_and_line_gauge_snapshots() raises:
    var buffer = Buffer(Rect(0, 0, 8, 2))
    Gauge(0.5).render(Rect(0, 0, 8, 1), buffer)
    LineGauge(0.25).render(Rect(0, 1, 8, 1), buffer)
    assert_equal(row(buffer, 0), "████░░░░")
    assert_equal(row(buffer, 1), "━━──────")


def test_labeled_gauge_centers_text() raises:
    var buffer = Buffer(Rect(0, 0, 7, 1))
    var area = buffer.area.copy()
    Gauge.labeled(1.0, Line.from_text("100%")).render(area, buffer)
    assert_equal(row(buffer, 0), "█100%██")


def test_sparkline_uses_newest_visible_samples() raises:
    var sparkline = Sparkline([0, 1, 2, 3, 4, 8], maximum=8)
    var buffer = Buffer(Rect(0, 0, 4, 1))
    var area = buffer.area.copy()
    sparkline.render(area, buffer)
    assert_equal(row(buffer, 0), "▂▃▄█")


def test_widget_styles_are_written_to_cells() raises:
    var style = Style(modifiers=Style.BOLD)
    var buffer = Buffer(Rect(0, 0, 1, 1))
    var area = buffer.area.copy()
    Gauge(1.0, filled_style=style).render(area, buffer)
    assert_true(buffer.cell({0, 0}).style.equals(style))


def test_list_scrolls_selection_into_visible_range() raises:
    var widget = List(
        [
            ListItem.from_text("zero"),
            ListItem.from_text("one"),
            ListItem.from_text("two"),
        ]
    )
    var state = ListState(selected=2)
    var buffer = Buffer(Rect(0, 0, 8, 2))
    var area = buffer.area.copy()
    render_stateful_widget(widget, area, buffer, state)
    assert_equal(state.offset, 1)
    assert_equal(row(buffer, 0), "  one   ")
    assert_equal(row(buffer, 1), "> two   ")
    assert_true(buffer.cell({0, 1}).style.has(Style.REVERSED))


def test_list_navigation_clamps_at_collection_edges() raises:
    var state = ListState()
    state.next(2)
    state.next(2)
    state.next(2)
    assert_equal(state.selected, 1)
    state.previous(2)
    state.previous(2)
    assert_equal(state.selected, 0)
    state.select(-1, 2)
    assert_equal(state.selected, -1)


def test_table_header_columns_and_body_scroll_snapshot() raises:
    var table = Table.with_header(
        [
            Row([Line.from_text("alpha"), Line.from_text("10")]),
            Row([Line.from_text("beta"), Line.from_text("20")]),
            Row([Line.from_text("gamma"), Line.from_text("30")]),
        ],
        [Constraint.length(4), Constraint.fill()],
        Row([Line.from_text("NAME"), Line.from_text("CPU")]),
    )
    var state = TableState(selected=2)
    var buffer = Buffer(Rect(0, 0, 9, 3))
    var area = buffer.area.copy()
    table.render(area, buffer, state)
    assert_equal(state.offset, 1)
    assert_equal(row(buffer, 0), "NAME CPU ")
    assert_equal(row(buffer, 1), "beta 20  ")
    assert_equal(row(buffer, 2), "gamm 30  ")
    assert_true(buffer.cell({0, 2}).style.has(Style.REVERSED))


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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
