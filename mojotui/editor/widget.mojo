"""A visible-range editor widget for no-wrap and soft-wrap viewports."""

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style
from ..core.widget import StatefulWidget
from ..text.width import grapheme_width
from ..widgets.basic import Block
from .history import EditorEngine
from .highlight import HighlightState
from .selection import SelectionSet, display_column


struct WrapMode(Copyable, Equatable, ImplicitlyCopyable):
    """Logical-line or viewport-width editor rendering."""

    comptime NONE = WrapMode(0, _validated=True)
    comptime SOFT = WrapMode(1, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 1:
            raise Error(String("editor wrap mode must be within [0, 1]; got ", value))
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct EditorState(Movable):
    """Document/editor state plus the leading logical and visual viewport."""

    var engine: EditorEngine
    var top_line: Int
    var top_visual_row: Int
    var horizontal_offset: Int
    var highlights: HighlightState

    def __init__(out self, var text: String = ""):
        self.engine = EditorEngine(text^)
        self.top_line = 0
        self.top_visual_row = 0
        self.horizontal_offset = 0
        self.highlights = HighlightState()

    def scroll_lines(mut self, delta: Int):
        self.top_line = max(
            0,
            min(
                self.top_line + delta,
                self.engine.document.line_count() - 1,
            ),
        )
        self.top_visual_row = 0


struct _EditorViewport(Copyable):
    """Small render-local viewport, separate from the document engine."""

    var top_line: Int
    var top_visual_row: Int
    var horizontal_offset: Int

    def __init__(
        out self,
        top_line: Int,
        top_visual_row: Int,
        horizontal_offset: Int,
    ):
        self.top_line = top_line
        self.top_visual_row = top_visual_row
        self.horizontal_offset = horizontal_offset


def _digits(value: Int) -> Int:
    var remaining = max(value, 1)
    var count = 1
    while remaining >= 10:
        remaining //= 10
        count += 1
    return count


def _line_display_width(
    var text: String, tab_width: Int, ambiguous_is_wide: Bool
) -> Int:
    var column = 0
    for grapheme in text.graphemes():
        var content = String(grapheme)
        if content == "\t":
            var width = max(tab_width, 1)
            column += width - column % width
        else:
            column += grapheme_width(content, ambiguous_is_wide)
    return column


def _is_selected(selections: SelectionSet, byte_start: Int, byte_end: Int) -> Bool:
    for index in range(len(selections.selections)):
        var selection = selections.selections[index].copy()
        if (
            not selection.is_empty()
            and byte_start < selection.end()
            and byte_end > selection.start()
        ):
            return True
    return False


def _is_caret(selections: SelectionSet, byte_offset: Int) -> Bool:
    for index in range(len(selections.selections)):
        if selections.selections[index].head == byte_offset:
            return True
    return False


def _render_line_window(
    var text: String,
    line_start: Int,
    column_start: Int,
    area: Rect,
    mut buffer: Buffer,
    selections: SelectionSet,
    style: Style,
    selection_style: Style,
    cursor_style: Style,
    highlights: HighlightState,
    document_version: Int,
    tab_width: Int,
    ambiguous_is_wide: Bool,
):
    if area.is_empty():
        return
    buffer.fill(area, Cell(style=style))
    var display_column = 0
    var byte_offset = line_start
    var window_end = column_start + area.width
    for grapheme in text.graphemes():
        var content = String(grapheme)
        var byte_end = byte_offset + content.byte_length()
        var width = grapheme_width(content, ambiguous_is_wide)
        var is_tab = content == "\t"
        if is_tab:
            var stop = max(tab_width, 1)
            width = stop - display_column % stop
        var next_column = display_column + width
        var selected = _is_selected(selections, byte_offset, byte_end)
        var caret = _is_caret(selections, byte_offset)
        var highlighted_style = highlights.style_for(
            document_version, byte_offset, byte_end, style
        )
        var cell_style = (
            cursor_style.copy() if caret else selection_style.copy() if selected else highlighted_style
            ^
        )

        if next_column > column_start and display_column < window_end:
            var visible_start = max(display_column, column_start)
            var visible_end = min(next_column, window_end)
            var x = area.x + visible_start - column_start
            if is_tab:
                for offset in range(visible_end - visible_start):
                    _ = buffer.set_cell(
                        Point(x + offset, area.y), Cell(" ", style=cell_style)
                    )
            elif (
                visible_start == display_column
                and visible_end == next_column
                and width > 0
            ):
                _ = buffer.set_cell(
                    Point(x, area.y), Cell(content^, width, style=cell_style)
                )
            else:
                for offset in range(visible_end - visible_start):
                    _ = buffer.set_cell(
                        Point(x + offset, area.y), Cell(" ", style=cell_style)
                    )
        display_column = next_column
        byte_offset = byte_end
        if display_column >= window_end:
            break

    if _is_caret(selections, byte_offset):
        var caret_column = display_column - column_start
        if caret_column >= 0 and caret_column < area.width:
            _ = buffer.set_cell(
                Point(area.x + caret_column, area.y),
                Cell(" ", style=cursor_style),
            )


struct Editor(Copyable, StatefulWidget):
    """Render an `EditorState` without scanning non-visible document lines."""

    comptime State = EditorState

    var wrap_mode: WrapMode
    var tab_width: Int
    var show_line_numbers: Bool
    var ambiguous_is_wide: Bool
    var style: Style
    var selection_style: Style
    var cursor_style: Style
    var line_number_style: Style
    var block: Block
    var draw_block: Bool

    def __init__(
        out self,
        wrap_mode: WrapMode = WrapMode.NONE,
        tab_width: Int = 4,
        show_line_numbers: Bool = False,
        ambiguous_is_wide: Bool = False,
        style: Style = Style.plain(),
        selection_style: Style = Style(modifiers=Style.REVERSED),
        cursor_style: Style = Style(modifiers=Style.REVERSED),
        line_number_style: Style = Style(modifiers=Style.DIM),
    ):
        self.wrap_mode = wrap_mode
        self.tab_width = max(tab_width, 1)
        self.show_line_numbers = show_line_numbers
        self.ambiguous_is_wide = ambiguous_is_wide
        self.style = style.copy()
        self.selection_style = selection_style.copy()
        self.cursor_style = cursor_style.copy()
        self.line_number_style = line_number_style.copy()
        self.block = Block()
        self.draw_block = False

    @staticmethod
    def with_block(
        block: Block,
        wrap_mode: WrapMode = WrapMode.NONE,
        tab_width: Int = 4,
        show_line_numbers: Bool = False,
        ambiguous_is_wide: Bool = False,
        style: Style = Style.plain(),
        selection_style: Style = Style(modifiers=Style.REVERSED),
        cursor_style: Style = Style(modifiers=Style.REVERSED),
        line_number_style: Style = Style(modifiers=Style.DIM),
    ) -> Self:
        var result = Self(
            wrap_mode,
            tab_width,
            show_line_numbers,
            ambiguous_is_wide,
            style,
            selection_style,
            cursor_style,
            line_number_style,
        )
        result.block = block.copy()
        result.draw_block = True
        return result^

    def _gutter_width(self, line_count: Int, area_width: Int) -> Int:
        if not self.show_line_numbers:
            return 0
        return min(_digits(line_count) + 1, max(area_width - 1, 0))

    def _wrap_rows(self, var text: String, content_width: Int) -> Int:
        if content_width <= 0:
            return 1
        var width = _line_display_width(text, self.tab_width, self.ambiguous_is_wide)
        return width // content_width + 1 if width % content_width == 0 else (
            width // content_width + 1
        )

    def _ensure_cursor_visible(
        self,
        content_width: Int,
        content_height: Int,
        engine: EditorEngine,
        mut viewport: _EditorViewport,
    ) raises:
        if content_width <= 0 or content_height <= 0:
            return
        var primary = engine.selections.primary_selection()
        var position = engine.document.position_at(primary.head)
        if self.wrap_mode == WrapMode.NONE:
            if position.line < viewport.top_line:
                viewport.top_line = position.line
            elif position.line >= viewport.top_line + content_height:
                viewport.top_line = position.line - content_height + 1
            var column = display_column(
                engine.document,
                primary.head,
                self.tab_width,
                self.ambiguous_is_wide,
            )
            if column < viewport.horizontal_offset:
                viewport.horizontal_offset = column
            elif column >= viewport.horizontal_offset + content_width:
                viewport.horizontal_offset = column - content_width + 1
            viewport.top_visual_row = 0
            return

        viewport.horizontal_offset = 0
        var column = display_column(
            engine.document,
            primary.head,
            self.tab_width,
            self.ambiguous_is_wide,
        )
        var cursor_row = column // content_width
        var before_top = position.line < viewport.top_line or (
            position.line == viewport.top_line and cursor_row < viewport.top_visual_row
        )
        if before_top:
            viewport.top_line = position.line
            viewport.top_visual_row = cursor_row
            return

        var distance = -viewport.top_visual_row
        for line in range(viewport.top_line, position.line):
            var text = engine.document.line_text(line)
            distance += self._wrap_rows(text^, content_width)
            if distance >= content_height:
                break
        if position.line == viewport.top_line:
            distance = cursor_row - viewport.top_visual_row
        else:
            distance += cursor_row
        if distance >= content_height:
            viewport.top_line = position.line
            viewport.top_visual_row = max(cursor_row - content_height + 1, 0)

    def _render_line_number(
        self,
        logical_line: Int,
        continuation: Bool,
        area: Rect,
        mut buffer: Buffer,
    ):
        if area.is_empty():
            return
        buffer.fill(area, Cell(style=self.line_number_style))
        if continuation:
            return
        var label = String(logical_line + 1)
        var start = max(area.right() - 1 - label.byte_length(), area.x)
        for index in range(min(label.byte_length(), area.width - 1)):
            _ = buffer.set_cell(
                Point(start + index, area.y),
                Cell(String(label[byte=index]), style=self.line_number_style),
            )

    def _render_with_viewport(
        self,
        area: Rect,
        mut buffer: Buffer,
        engine: EditorEngine,
        highlights: HighlightState,
        mut viewport: _EditorViewport,
    ) raises:
        var visible = buffer.area.intersection(area)
        if visible.is_empty():
            return
        buffer.fill(visible, Cell(style=self.style))
        var content = visible.copy()
        if self.draw_block:
            self.block.render(visible, buffer)
            content = self.block.inner(visible)
        if content.is_empty():
            return

        viewport.top_line = min(
            max(viewport.top_line, 0), engine.document.line_count() - 1
        )
        var gutter_width = self._gutter_width(
            engine.document.line_count(), content.width
        )
        var text_width = content.width - gutter_width
        self._ensure_cursor_visible(text_width, content.height, engine, viewport)
        if text_width <= 0:
            return

        var y = content.y
        var logical_line = viewport.top_line
        var initial_visual_row = viewport.top_visual_row
        while y < content.bottom() and logical_line < engine.document.line_count():
            var text = engine.document.line_text(logical_line)
            var line_start = engine.document.line_start(logical_line)
            var rows = 1
            if self.wrap_mode == WrapMode.SOFT:
                rows = self._wrap_rows(text, text_width)
            var first_row = min(initial_visual_row, rows - 1)
            for visual_row in range(first_row, rows):
                if y >= content.bottom():
                    break
                if gutter_width > 0:
                    self._render_line_number(
                        logical_line,
                        visual_row > 0,
                        Rect(content.x, y, gutter_width, 1),
                        buffer,
                    )
                var column_start = (
                    visual_row * text_width if self.wrap_mode
                    == WrapMode.SOFT else viewport.horizontal_offset
                )
                _render_line_window(
                    text,
                    line_start,
                    column_start,
                    Rect(content.x + gutter_width, y, text_width, 1),
                    buffer,
                    engine.selections,
                    self.style,
                    self.selection_style,
                    self.cursor_style,
                    highlights,
                    engine.document.version,
                    self.tab_width,
                    self.ambiguous_is_wide,
                )
                y += 1
            logical_line += 1
            initial_visual_row = 0

    def render(self, area: Rect, mut buffer: Buffer, mut state: EditorState) raises:
        """Render and persist any cursor-driven viewport adjustment."""
        var viewport = _EditorViewport(
            state.top_line,
            state.top_visual_row,
            state.horizontal_offset,
        )
        self._render_with_viewport(
            area,
            buffer,
            state.engine,
            state.highlights,
            viewport,
        )
        state.top_line = viewport.top_line
        state.top_visual_row = viewport.top_visual_row
        state.horizontal_offset = viewport.horizontal_offset

    def render_readonly(
        self,
        area: Rect,
        mut buffer: Buffer,
        state: EditorState,
    ) raises:
        """Render from borrowed application state without changing its viewport."""
        var viewport = _EditorViewport(
            state.top_line,
            state.top_visual_row,
            state.horizontal_offset,
        )
        self._render_with_viewport(
            area,
            buffer,
            state.engine,
            state.highlights,
            viewport,
        )
