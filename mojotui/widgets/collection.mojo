"""Stateful collection widgets with visible-range rendering."""

from std.collections import List as MojoList, Optional

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.layout import Constraint, Layout
from ..core.style import Style, StylePatch
from ..core.widget import StatefulWidget
from ..text.rich import Line, Text, render_line
from ..text.width import text_width


def _clamp_collection_state(
    mut selected: Optional[UInt],
    mut offset: Int,
    item_count: Int,
    viewport_height: Int,
):
    """Normalize selection and keep it inside the visible window."""
    var count = max(item_count, 0)
    var height = max(viewport_height, 0)
    if count == 0:
        selected = None
        offset = 0
        return

    if selected:
        var index = Int(selected.value())
        if index >= count:
            selected = UInt(count - 1)

    var maximum_offset = max(count - height, 0)
    offset = max(0, min(offset, maximum_offset))
    if height == 0 or not selected:
        return
    var index = Int(selected.value())
    if index < offset:
        offset = index
    elif index >= offset + height:
        offset = index - height + 1


def _render_selected_line(
    line: Line,
    area: Rect,
    mut buffer: Buffer,
    selected: Bool,
    base_style: Style,
    selected_style: StylePatch,
):
    var patch = selected_style.copy() if selected else StylePatch.plain()
    render_line(line, area, buffer, base_style=base_style, style_patch=patch)


struct HighlightSpacing(Copyable, Equatable, ImplicitlyCopyable):
    """Policy controlling space reserved for a list highlight symbol."""

    comptime ALWAYS = HighlightSpacing(0, _validated=True)
    comptime WHEN_SELECTED = HighlightSpacing(1, _validated=True)
    comptime NEVER = HighlightSpacing(2, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 2:
            raise Error(
                String("list highlight spacing must be within [0, 2]; got ", value)
            )
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct ListItem(Copyable):
    """One multiline rich-text item in a list."""

    var content: Text

    def __init__(out self, content: Text):
        self.content = content.copy()

    @staticmethod
    def from_line(content: Line) -> Self:
        return Self(Text.from_line(content))

    @staticmethod
    def from_text(var content: String, style: Style = Style.plain()) -> Self:
        return Self(Text.from_text(content^, style))

    def height(self) -> Int:
        return max(self.content.height(), 1)


struct ListState(Copyable):
    """Selection and viewport position owned by the application."""

    var selected: Optional[UInt]
    var offset: Int

    def __init__(out self, selected: Optional[UInt] = None, offset: Int = 0):
        self.selected = selected.copy()
        self.offset = max(offset, 0)

    def select(mut self, index: Optional[UInt], item_count: Int):
        if item_count <= 0 or not index:
            self.selected = None
        else:
            self.selected = UInt(min(Int(index.value()), item_count - 1))

    def next(mut self, item_count: Int):
        if item_count <= 0:
            self.selected = None
        elif not self.selected:
            self.selected = UInt(0)
        else:
            self.selected = UInt(min(Int(self.selected.value()) + 1, item_count - 1))

    def previous(mut self, item_count: Int):
        if item_count <= 0:
            self.selected = None
        elif not self.selected:
            self.selected = UInt(item_count - 1)
        else:
            self.selected = UInt(max(Int(self.selected.value()) - 1, 0))

    def ensure_visible(mut self, item_count: Int, viewport_height: Int):
        _clamp_collection_state(self.selected, self.offset, item_count, viewport_height)


struct ListRenderContext(Copyable):
    """Visible-row state passed to a lazy list provider.

    `index` addresses the provider's complete logical collection, while
    `viewport_row`, `viewport_offset`, and `viewport_height` describe the
    current clipped window. `selection` exposes the logical cursor without
    requiring the provider to own application state.
    """

    var index: Int
    var item_count: Int
    var viewport_row: Int
    var viewport_offset: Int
    var viewport_height: Int
    var selection: Optional[UInt]
    var selected: Bool

    def __init__(
        out self,
        index: Int,
        item_count: Int,
        viewport_row: Int,
        viewport_offset: Int,
        viewport_height: Int,
        selection: Optional[UInt],
    ) raises:
        if item_count < 0:
            raise Error("list render context item count must be non-negative")
        if index < 0 or index >= item_count:
            raise Error("list render context index is outside the collection")
        if viewport_row < 0 or viewport_height < 0:
            raise Error("list render context viewport values must be non-negative")
        if viewport_offset < 0 or index != viewport_offset + viewport_row:
            raise Error("list render context row does not match its viewport")
        if viewport_height == 0 or viewport_row >= viewport_height:
            raise Error("list render context row is outside its viewport height")
        if selection and selection.value() >= UInt(item_count):
            raise Error("list render context selection is outside the collection")
        self.index = index
        self.item_count = item_count
        self.viewport_row = viewport_row
        self.viewport_offset = viewport_offset
        self.viewport_height = viewport_height
        self.selection = selection.copy()
        self.selected = selection and index == Int(selection.value())


trait ListLineProvider(Copyable, Deinitable, Movable):
    """Random-access source whose rich lines are requested only when visible."""

    def item_count(self) -> Int:
        ...

    def line(self, context: ListRenderContext) raises -> Line:
        ...


struct VirtualList[Provider: ListLineProvider](Copyable, StatefulWidget):
    """A uniform one-row list that never materializes the complete collection.

    The statically dispatched provider is called at most once for each visible
    logical row. Existing `List` applications remain source compatible; use
    `VirtualList` when the backing collection is large or rows are expensive to
    highlight and format. Construction move-owns the provider so large backing
    collections are not copied on entry.
    """

    comptime State = ListState

    var provider: Self.Provider
    var style: Style
    var selected_style: StylePatch
    var highlight_symbol: String
    var highlight_spacing: HighlightSpacing
    var scroll_padding: Int

    def __init__(
        out self,
        var provider: Self.Provider,
        style: Style = Style.plain(),
        selected_style: StylePatch = StylePatch(add_modifiers=Style.REVERSED),
        var highlight_symbol: String = "> ",
        highlight_spacing: HighlightSpacing = HighlightSpacing.ALWAYS,
        scroll_padding: Int = 0,
    ):
        self.provider = provider^
        self.style = style.copy()
        self.selected_style = selected_style.copy()
        self.highlight_symbol = highlight_symbol^
        self.highlight_spacing = highlight_spacing
        self.scroll_padding = max(scroll_padding, 0)

    def _ensure_visible(self, mut state: ListState, viewport_height: Int, count: Int):
        _clamp_collection_state(state.selected, state.offset, count, viewport_height)
        if count == 0 or viewport_height <= 0 or not state.selected:
            return
        var selected = Int(state.selected.value())
        var desired_start = max(selected - self.scroll_padding, 0)
        var desired_end = min(selected + self.scroll_padding + 1, count)
        if desired_start < state.offset:
            state.offset = desired_start
        state.offset = min(
            selected,
            max(state.offset, desired_end - viewport_height),
        )

    def _marker_width(self, state: ListState, width: Int) -> Int:
        if self.highlight_spacing == HighlightSpacing.NEVER:
            return 0
        if (
            self.highlight_spacing == HighlightSpacing.WHEN_SELECTED
            and not state.selected
        ):
            return 0
        return min(text_width(self.highlight_symbol), width)

    def render(
        self,
        area: Rect,
        mut buffer: Buffer,
        mut state: ListState,
    ) raises:
        var visible_area = buffer.area.intersection(area)
        var count = self.provider.item_count()
        if count < 0:
            raise Error("list line provider item count must be non-negative")
        if visible_area.is_empty():
            self._ensure_visible(state, 0, count)
            return
        self._ensure_visible(state, visible_area.height, count)
        buffer.fill(visible_area, Cell(style=self.style))

        var marker_width = self._marker_width(state, visible_area.width)
        var content_x = visible_area.x + marker_width
        var content_width = visible_area.width - marker_width
        var visible_count = min(visible_area.height, count - state.offset)
        for viewport_row in range(visible_count):
            var item_index = state.offset + viewport_row
            var y = visible_area.y + viewport_row
            var context = ListRenderContext(
                item_index,
                count,
                viewport_row,
                state.offset,
                visible_area.height,
                state.selected,
            )
            if context.selected:
                buffer.fill(
                    Rect(visible_area.x, y, visible_area.width, 1),
                    Cell(style=self.style.patched(self.selected_style)),
                )
                if marker_width > 0:
                    _render_selected_line(
                        Line.from_text(self.highlight_symbol),
                        Rect(visible_area.x, y, marker_width, 1),
                        buffer,
                        True,
                        self.style,
                        self.selected_style,
                    )
            if content_width > 0:
                _render_selected_line(
                    self.provider.line(context),
                    Rect(content_x, y, content_width, 1),
                    buffer,
                    context.selected,
                    self.style,
                    self.selected_style,
                )


struct List(Copyable, StatefulWidget):
    """A selectable list that only visits rows in the current viewport."""

    comptime State = ListState

    var items: MojoList[ListItem]
    var style: Style
    var selected_style: StylePatch
    var highlight_symbol: String
    var highlight_spacing: HighlightSpacing
    var repeat_highlight_symbol: Bool
    var scroll_padding: Int

    def __init__(
        out self,
        var items: MojoList[ListItem],
        style: Style = Style.plain(),
        selected_style: StylePatch = StylePatch(add_modifiers=Style.REVERSED),
        var highlight_symbol: String = "> ",
        highlight_spacing: HighlightSpacing = HighlightSpacing.ALWAYS,
        repeat_highlight_symbol: Bool = False,
        scroll_padding: Int = 0,
    ):
        self.items = items^
        self.style = style.copy()
        self.selected_style = selected_style.copy()
        self.highlight_symbol = highlight_symbol^
        self.highlight_spacing = highlight_spacing
        self.repeat_highlight_symbol = repeat_highlight_symbol
        self.scroll_padding = max(scroll_padding, 0)

    def _item_height(self, index: Int) -> Int:
        return self.items[index].height()

    def _ensure_visible(self, mut state: ListState, viewport_height: Int):
        var count = len(self.items)
        if count == 0:
            state.selected = None
            state.offset = 0
            return
        state.offset = min(max(state.offset, 0), count - 1)
        if state.selected and Int(state.selected.value()) >= count:
            state.selected = UInt(count - 1)
        if viewport_height <= 0 or not state.selected:
            return

        var selected = Int(state.selected.value())
        var desired_start = max(selected - self.scroll_padding, 0)
        var desired_end = min(selected + self.scroll_padding + 1, count)
        if desired_start < state.offset or selected < state.offset:
            state.offset = desired_start

        # Work backwards only across rows that can fit in this viewport. This
        # remains bounded by visible content and stays correct when callers
        # replace or mutate public items after widget construction.
        var remaining_height = viewport_height
        var fits_selected_tail = True
        for index in range(selected, desired_end):
            var height = self._item_height(index)
            if height > remaining_height:
                fits_selected_tail = False
                break
            remaining_height -= height
        var earliest = selected
        if fits_selected_tail:
            while earliest > state.offset:
                var candidate = earliest - 1
                var height = self._item_height(candidate)
                if height > remaining_height:
                    break
                remaining_height -= height
                earliest = candidate
        state.offset = max(state.offset, earliest)

    def _marker_width(self, state: ListState, width: Int) -> Int:
        if self.highlight_spacing == HighlightSpacing.NEVER:
            return 0
        if (
            self.highlight_spacing == HighlightSpacing.WHEN_SELECTED
            and not state.selected
        ):
            return 0
        return min(text_width(self.highlight_symbol), width)

    def render(self, area: Rect, mut buffer: Buffer, mut state: ListState):
        var visible_area = buffer.area.intersection(area)
        if visible_area.is_empty():
            self._ensure_visible(state, 0)
            return
        self._ensure_visible(state, visible_area.height)
        buffer.fill(visible_area, Cell(style=self.style))

        var marker_width = self._marker_width(state, visible_area.width)
        var y = visible_area.y
        for item_index in range(state.offset, len(self.items)):
            if y >= visible_area.bottom():
                break
            var is_selected = state.selected and item_index == Int(
                state.selected.value()
            )
            var item_height = self._item_height(item_index)
            for line_index in range(item_height):
                if y >= visible_area.bottom():
                    break
                if is_selected:
                    buffer.fill(
                        Rect(visible_area.x, y, visible_area.width, 1),
                        Cell(style=self.style.patched(self.selected_style)),
                    )
                if (
                    is_selected
                    and marker_width > 0
                    and (line_index == 0 or self.repeat_highlight_symbol)
                ):
                    _render_selected_line(
                        Line.from_text(self.highlight_symbol),
                        Rect(visible_area.x, y, marker_width, 1),
                        buffer,
                        True,
                        self.style,
                        self.selected_style,
                    )
                var content_x = visible_area.x + marker_width
                var content_width = visible_area.width - marker_width
                if content_width > 0 and line_index < len(
                    self.items[item_index].content.lines
                ):
                    _render_selected_line(
                        self.items[item_index].content.lines[line_index],
                        Rect(content_x, y, content_width, 1),
                        buffer,
                        is_selected,
                        self.style,
                        self.selected_style,
                    )
                y += 1


struct Row(Copyable):
    """One table row containing multiline rich-text cells.

    Construction and every render-time read normalize `height` to at least one,
    including after unusual direct public-field mutation.
    """

    var cells: MojoList[Text]
    var height: Int

    def __init__(
        out self,
        var cells: MojoList[Text] = MojoList[Text](),
        height: Int = 1,
    ):
        self.cells = cells^
        self.height = max(height, 1)

    @staticmethod
    def from_lines(
        var cells: MojoList[Line] = MojoList[Line](),
        height: Int = 1,
    ) -> Self:
        var text_cells = MojoList[Text]()
        for index in range(len(cells)):
            text_cells.append(Text.from_line(cells[index]))
        return Self(text_cells^, height)


def _row_height(row: Row) -> Int:
    """Return the rendering invariant for publicly mutable row height."""
    return max(row.height, 1)


struct TableSelection(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal table highlight target."""

    comptime NONE = TableSelection(0, _validated=True)
    comptime ROW = TableSelection(1, _validated=True)
    comptime COLUMN = TableSelection(2, _validated=True)
    comptime CELL = TableSelection(3, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 3:
            raise Error(
                String("table selection mode must be within [0, 3]; got ", value)
            )
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct TableState(Copyable):
    """Selected body row and body viewport position."""

    var selected: Optional[UInt]
    var selected_column: Optional[UInt]
    var offset: Int

    def __init__(
        out self,
        selected: Optional[UInt] = None,
        selected_column: Optional[UInt] = None,
        offset: Int = 0,
    ):
        self.selected = selected.copy()
        self.selected_column = selected_column.copy()
        self.offset = max(offset, 0)

    def select(mut self, index: Optional[UInt], row_count: Int):
        if row_count <= 0 or not index:
            self.selected = None
        else:
            self.selected = UInt(min(Int(index.value()), row_count - 1))

    def next(mut self, row_count: Int):
        if row_count <= 0:
            self.selected = None
        elif not self.selected:
            self.selected = UInt(0)
        else:
            self.selected = UInt(min(Int(self.selected.value()) + 1, row_count - 1))

    def previous(mut self, row_count: Int):
        if row_count <= 0:
            self.selected = None
        elif not self.selected:
            self.selected = UInt(row_count - 1)
        else:
            self.selected = UInt(max(Int(self.selected.value()) - 1, 0))

    def ensure_visible(mut self, row_count: Int, viewport_height: Int):
        _clamp_collection_state(self.selected, self.offset, row_count, viewport_height)

    def select_column(mut self, index: Optional[UInt], column_count: Int):
        if column_count <= 0 or not index:
            self.selected_column = None
        else:
            self.selected_column = UInt(min(Int(index.value()), column_count - 1))

    def next_column(mut self, column_count: Int):
        if column_count <= 0:
            self.selected_column = None
        elif not self.selected_column:
            self.selected_column = UInt(0)
        else:
            self.selected_column = UInt(
                min(Int(self.selected_column.value()) + 1, column_count - 1)
            )

    def previous_column(mut self, column_count: Int):
        if column_count <= 0:
            self.selected_column = None
        elif not self.selected_column:
            self.selected_column = UInt(column_count - 1)
        else:
            self.selected_column = UInt(max(Int(self.selected_column.value()) - 1, 0))


struct Table(Copyable, StatefulWidget):
    """A clipped table with fixed-layout columns and a scrollable body."""

    comptime State = TableState

    var rows: MojoList[Row]
    var widths: MojoList[Constraint]
    var header: Row
    var show_header: Bool
    var footer: Row
    var show_footer: Bool
    var spacing: Int
    var scroll_padding: Int
    var selection: TableSelection
    var style: Style
    var header_style: StylePatch
    var footer_style: StylePatch
    var selected_style: StylePatch

    def __init__(
        out self,
        var rows: MojoList[Row],
        var widths: MojoList[Constraint],
        spacing: Int = 1,
        style: Style = Style.plain(),
        selected_style: StylePatch = StylePatch(add_modifiers=Style.REVERSED),
        scroll_padding: Int = 0,
        selection: TableSelection = TableSelection.ROW,
    ):
        self.rows = rows^
        self.widths = widths^
        self.header = Row()
        self.show_header = False
        self.footer = Row()
        self.show_footer = False
        self.spacing = max(spacing, 0)
        self.scroll_padding = max(scroll_padding, 0)
        self.selection = selection
        self.style = style.copy()
        self.header_style = StylePatch.plain()
        self.footer_style = StylePatch.plain()
        self.selected_style = selected_style.copy()

    @staticmethod
    def with_header(
        var rows: MojoList[Row],
        var widths: MojoList[Constraint],
        header: Row,
        spacing: Int = 1,
        style: Style = Style.plain(),
        header_style: StylePatch = StylePatch(add_modifiers=Style.BOLD),
        selected_style: StylePatch = StylePatch(add_modifiers=Style.REVERSED),
        scroll_padding: Int = 0,
        selection: TableSelection = TableSelection.ROW,
    ) -> Self:
        var result = Self(
            rows^,
            widths^,
            spacing,
            style,
            selected_style,
            scroll_padding,
            selection,
        )
        result.header = header.copy()
        result.header_style = header_style.copy()
        result.show_header = True
        return result^

    def with_footer(self, footer: Row, style: StylePatch = StylePatch.plain()) -> Self:
        var result = self.copy()
        result.footer = footer.copy()
        result.footer_style = style.copy()
        result.show_footer = True
        return result^

    def _columns(self, area: Rect) -> MojoList[Rect]:
        var widths = self.widths.copy()
        return Layout.horizontal(widths^, self.spacing).split(area)

    def _render_row(
        self,
        row: Row,
        area: Rect,
        mut buffer: Buffer,
        force_style: Bool,
        row_selected: Bool,
        selected_column: Optional[UInt],
        selection: TableSelection,
        row_style: StylePatch,
    ):
        var base_style = self.style.patched(row_style)
        buffer.fill(area, Cell(style=base_style))
        var columns = self._columns(area)
        var visible_cells = min(len(row.cells), len(columns))
        for line_index in range(area.height):
            for index in range(visible_cells):
                var column_selected = selected_column and index == Int(
                    selected_column.value()
                )
                var highlighted = not force_style and (
                    (selection == TableSelection.ROW and row_selected)
                    or (selection == TableSelection.COLUMN and column_selected)
                    or (
                        selection == TableSelection.CELL
                        and row_selected
                        and column_selected
                    )
                )
                var cell_area = Rect(
                    columns[index].x,
                    area.y + line_index,
                    columns[index].width,
                    1,
                )
                if highlighted:
                    buffer.fill(
                        cell_area,
                        Cell(style=base_style.patched(self.selected_style)),
                    )
                if line_index < len(row.cells[index].lines):
                    _render_selected_line(
                        row.cells[index].lines[line_index],
                        cell_area,
                        buffer,
                        highlighted,
                        base_style,
                        self.selected_style,
                    )

    def _ensure_visible(self, mut state: TableState, viewport_height: Int):
        var count = len(self.rows)
        if count == 0:
            state.selected = None
            state.offset = 0
            return
        state.offset = min(max(state.offset, 0), count - 1)
        if state.selected and Int(state.selected.value()) >= count:
            state.selected = UInt(count - 1)
        var selected_column = state.selected_column.copy()
        state.select_column(selected_column, len(self.widths))
        if viewport_height <= 0 or not state.selected:
            return
        var selected = Int(state.selected.value())
        var desired_start = max(selected - self.scroll_padding, 0)
        var desired_end = min(selected + self.scroll_padding + 1, count)
        if desired_start < state.offset or selected < state.offset:
            state.offset = desired_start

        var remaining_height = viewport_height
        var fits_selected_tail = True
        for index in range(selected, desired_end):
            var height = _row_height(self.rows[index])
            if height > remaining_height:
                fits_selected_tail = False
                break
            remaining_height -= height
        var earliest = selected
        if fits_selected_tail:
            while earliest > state.offset:
                var candidate = earliest - 1
                var height = _row_height(self.rows[candidate])
                if height > remaining_height:
                    break
                remaining_height -= height
                earliest = candidate
        state.offset = max(state.offset, earliest)

    def render(self, area: Rect, mut buffer: Buffer, mut state: TableState):
        var visible_area = buffer.area.intersection(area)
        if visible_area.is_empty():
            self._ensure_visible(state, 0)
            return
        buffer.fill(visible_area, Cell(style=self.style))

        var body_y = visible_area.y
        if self.show_header:
            var header_height = min(_row_height(self.header), visible_area.height)
            self._render_row(
                self.header,
                Rect(visible_area.x, body_y, visible_area.width, header_height),
                buffer,
                True,
                False,
                None,
                TableSelection.NONE,
                self.header_style,
            )
            body_y += header_height
        var body_bottom = visible_area.bottom()
        if self.show_footer and body_bottom > body_y:
            var footer_height = min(_row_height(self.footer), body_bottom - body_y)
            body_bottom -= footer_height
            self._render_row(
                self.footer,
                Rect(
                    visible_area.x,
                    body_bottom,
                    visible_area.width,
                    footer_height,
                ),
                buffer,
                True,
                False,
                None,
                TableSelection.NONE,
                self.footer_style,
            )
        var body_height = max(body_bottom - body_y, 0)
        self._ensure_visible(state, body_height)
        var y = body_y
        for row_index in range(state.offset, len(self.rows)):
            if y >= body_bottom:
                break
            var row_height = min(_row_height(self.rows[row_index]), body_bottom - y)
            var selected = state.selected and row_index == Int(state.selected.value())
            self._render_row(
                self.rows[row_index],
                Rect(visible_area.x, y, visible_area.width, row_height),
                buffer,
                False,
                selected,
                state.selected_column,
                self.selection,
                StylePatch.plain(),
            )
            y += row_height
