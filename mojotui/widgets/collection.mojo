"""Stateful collection widgets with visible-range rendering."""

from std.collections import List as MojoList

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.layout import Constraint, Layout
from ..core.style import Style
from ..core.widget import StatefulWidget
from ..text.rich import Line, render_line
from ..text.width import text_width


def _clamp_collection_state(
    mut selected: Int,
    mut offset: Int,
    item_count: Int,
    viewport_height: Int,
):
    """Normalize selection and keep it inside the visible window."""
    var count = max(item_count, 0)
    var height = max(viewport_height, 0)
    if count == 0:
        selected = -1
        offset = 0
        return

    if selected < -1:
        selected = -1
    elif selected >= count:
        selected = count - 1

    var maximum_offset = max(count - height, 0)
    offset = max(0, min(offset, maximum_offset))
    if height == 0 or selected < 0:
        return
    if selected < offset:
        offset = selected
    elif selected >= offset + height:
        offset = selected - height + 1


def _render_selected_line(
    line: Line,
    area: Rect,
    mut buffer: Buffer,
    selected: Bool,
    selected_style: Style,
):
    if not selected:
        render_line(line, area, buffer)
        return
    var highlighted = line.copy()
    for index in range(len(highlighted.spans)):
        highlighted.spans[index].style = selected_style.copy()
    render_line(highlighted, area, buffer)


struct ListItem(Copyable):
    """One logical row in a list."""

    var content: Line

    def __init__(out self, content: Line):
        self.content = content.copy()

    @staticmethod
    def from_text(var content: String, style: Style = Style.plain()) -> Self:
        return Self(Line.from_text(content^, style))


struct ListState(Copyable):
    """Selection and viewport position owned by the application."""

    var selected: Int
    var offset: Int

    def __init__(out self, selected: Int = -1, offset: Int = 0):
        self.selected = max(selected, -1)
        self.offset = max(offset, 0)

    def select(mut self, index: Int, item_count: Int):
        if item_count <= 0 or index < 0:
            self.selected = -1
        else:
            self.selected = min(index, item_count - 1)

    def next(mut self, item_count: Int):
        if item_count <= 0:
            self.selected = -1
        elif self.selected < 0:
            self.selected = 0
        else:
            self.selected = min(self.selected + 1, item_count - 1)

    def previous(mut self, item_count: Int):
        if item_count <= 0:
            self.selected = -1
        elif self.selected < 0:
            self.selected = item_count - 1
        else:
            self.selected = max(self.selected - 1, 0)

    def ensure_visible(mut self, item_count: Int, viewport_height: Int):
        _clamp_collection_state(self.selected, self.offset, item_count, viewport_height)


struct List(Copyable, StatefulWidget):
    """A selectable list that only visits rows in the current viewport."""

    comptime State = ListState

    var items: MojoList[ListItem]
    var style: Style
    var selected_style: Style
    var highlight_symbol: String

    def __init__(
        out self,
        var items: MojoList[ListItem],
        style: Style = Style.plain(),
        selected_style: Style = Style(modifiers=Style.REVERSED),
        var highlight_symbol: String = "> ",
    ):
        self.items = items^
        self.style = style.copy()
        self.selected_style = selected_style.copy()
        self.highlight_symbol = highlight_symbol^

    def render(self, area: Rect, mut buffer: Buffer, mut state: ListState):
        var visible_area = buffer.area.intersection(area)
        if visible_area.is_empty():
            state.ensure_visible(len(self.items), 0)
            return
        state.ensure_visible(len(self.items), visible_area.height)
        buffer.fill(visible_area, Cell(style=self.style))

        var marker_width = min(text_width(self.highlight_symbol), visible_area.width)
        var end = min(len(self.items), state.offset + visible_area.height)
        for item_index in range(state.offset, end):
            var y = visible_area.y + item_index - state.offset
            var is_selected = item_index == state.selected
            if is_selected and marker_width > 0:
                _render_selected_line(
                    Line.from_text(self.highlight_symbol),
                    Rect(visible_area.x, y, marker_width, 1),
                    buffer,
                    True,
                    self.selected_style,
                )
            var content_x = visible_area.x + marker_width
            var content_width = visible_area.width - marker_width
            if content_width > 0:
                _render_selected_line(
                    self.items[item_index].content,
                    Rect(content_x, y, content_width, 1),
                    buffer,
                    is_selected,
                    self.selected_style,
                )


struct Row(Copyable):
    """One table row containing independently styled cells."""

    var cells: MojoList[Line]

    def __init__(out self, var cells: MojoList[Line] = MojoList[Line]()):
        self.cells = cells^


struct TableState(Copyable):
    """Selected body row and body viewport position."""

    var selected: Int
    var offset: Int

    def __init__(out self, selected: Int = -1, offset: Int = 0):
        self.selected = max(selected, -1)
        self.offset = max(offset, 0)

    def select(mut self, index: Int, row_count: Int):
        if row_count <= 0 or index < 0:
            self.selected = -1
        else:
            self.selected = min(index, row_count - 1)

    def next(mut self, row_count: Int):
        if row_count <= 0:
            self.selected = -1
        elif self.selected < 0:
            self.selected = 0
        else:
            self.selected = min(self.selected + 1, row_count - 1)

    def previous(mut self, row_count: Int):
        if row_count <= 0:
            self.selected = -1
        elif self.selected < 0:
            self.selected = row_count - 1
        else:
            self.selected = max(self.selected - 1, 0)

    def ensure_visible(mut self, row_count: Int, viewport_height: Int):
        _clamp_collection_state(self.selected, self.offset, row_count, viewport_height)


struct Table(Copyable, StatefulWidget):
    """A clipped table with fixed-layout columns and a scrollable body."""

    comptime State = TableState

    var rows: MojoList[Row]
    var widths: MojoList[Constraint]
    var header: Row
    var show_header: Bool
    var spacing: Int
    var style: Style
    var header_style: Style
    var selected_style: Style

    def __init__(
        out self,
        var rows: MojoList[Row],
        var widths: MojoList[Constraint],
        spacing: Int = 1,
        style: Style = Style.plain(),
        selected_style: Style = Style(modifiers=Style.REVERSED),
    ):
        self.rows = rows^
        self.widths = widths^
        self.header = Row()
        self.show_header = False
        self.spacing = max(spacing, 0)
        self.style = style.copy()
        self.header_style = style.copy()
        self.selected_style = selected_style.copy()

    @staticmethod
    def with_header(
        var rows: MojoList[Row],
        var widths: MojoList[Constraint],
        header: Row,
        spacing: Int = 1,
        style: Style = Style.plain(),
        header_style: Style = Style(modifiers=Style.BOLD),
        selected_style: Style = Style(modifiers=Style.REVERSED),
    ) -> Self:
        var result = Self(rows^, widths^, spacing, style, selected_style)
        result.header = header.copy()
        result.header_style = header_style.copy()
        result.show_header = True
        return result^

    def _columns(self, area: Rect) -> MojoList[Rect]:
        var widths = self.widths.copy()
        return Layout.horizontal(widths^, self.spacing).split(area)

    def _render_row(
        self,
        row: Row,
        area: Rect,
        mut buffer: Buffer,
        override_style: Bool,
        row_style: Style,
    ):
        buffer.fill(area, Cell(style=row_style))
        var columns = self._columns(area)
        var visible_cells = min(len(row.cells), len(columns))
        for index in range(visible_cells):
            _render_selected_line(
                row.cells[index],
                columns[index],
                buffer,
                override_style,
                row_style,
            )

    def render(self, area: Rect, mut buffer: Buffer, mut state: TableState):
        var visible_area = buffer.area.intersection(area)
        if visible_area.is_empty():
            state.ensure_visible(len(self.rows), 0)
            return
        buffer.fill(visible_area, Cell(style=self.style))

        var body_y = visible_area.y
        if self.show_header:
            self._render_row(
                self.header,
                Rect(visible_area.x, body_y, visible_area.width, 1),
                buffer,
                True,
                self.header_style,
            )
            body_y += 1
        var body_height = max(visible_area.bottom() - body_y, 0)
        state.ensure_visible(len(self.rows), body_height)
        var end = min(len(self.rows), state.offset + body_height)
        for row_index in range(state.offset, end):
            var y = body_y + row_index - state.offset
            var selected = row_index == state.selected
            self._render_row(
                self.rows[row_index],
                Rect(visible_area.x, y, visible_area.width, 1),
                buffer,
                selected,
                self.selected_style if selected else self.style,
            )
