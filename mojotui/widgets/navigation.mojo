"""Navigation and viewport-position widgets."""

from std.collections import List as MojoList, Optional

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style, StylePatch
from ..core.widget import StatefulWidget, Widget
from ..text.rich import Line, Span, render_line
from ..text.width import text_width


struct Tabs(Copyable, Widget):
    """A single-row tab strip with one explicitly selected title."""

    var titles: MojoList[Line]
    var selected: Int
    var divider: String
    var style: Style
    var selected_style: StylePatch

    def __init__(
        out self,
        var titles: MojoList[Line],
        selected: Int = 0,
        var divider: String = "│",
        style: Style = Style.plain(),
        selected_style: StylePatch = StylePatch(add_modifiers=Style.REVERSED),
    ):
        self.titles = titles^
        self.selected = max(selected, 0)
        self.divider = divider^
        self.style = style.copy()
        self.selected_style = selected_style.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        var visible_area = buffer.area.intersection(area)
        if visible_area.is_empty():
            return
        var row_area = Rect(visible_area.x, visible_area.y, visible_area.width, 1)
        buffer.fill(row_area, Cell(style=self.style))
        var spans = MojoList[Span]()
        for title_index in range(len(self.titles)):
            if title_index > 0:
                spans.append(Span(self.divider))
            var tab_style = (
                self.selected_style.copy() if title_index
                == self.selected else StylePatch.plain()
            )
            spans.append(Span(" ", tab_style))
            var title = self.titles[title_index].copy()
            for span_index in range(len(title.spans)):
                var span = title.spans[span_index].copy()
                if title_index == self.selected:
                    span.style = span.style.then(self.selected_style)
                spans.append(span^)
            spans.append(Span(" ", tab_style))
        render_line(Line(spans^), row_area, buffer, base_style=self.style)


struct ScrollbarOrientation(Copyable, Equatable, ImplicitlyCopyable):
    """Axis occupied by a scrollbar."""

    comptime VERTICAL = ScrollbarOrientation(0, _validated=True)
    comptime HORIZONTAL = ScrollbarOrientation(1, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 1:
            raise Error(
                String("scrollbar orientation must be within [0, 1]; got ", value)
            )
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct ScrollbarState(Copyable):
    """Content extent, viewport extent, and leading visible position."""

    var content_length: Int
    var position: Int
    var viewport_length: Int

    def __init__(
        out self,
        content_length: Int = 0,
        position: Int = 0,
        viewport_length: Int = 0,
    ):
        self.content_length = max(content_length, 0)
        self.viewport_length = max(viewport_length, 0)
        self.position = max(position, 0)
        self.normalize()

    def maximum_position(self) -> Int:
        return max(self.content_length - self.viewport_length, 0)

    def normalize(mut self):
        self.content_length = max(self.content_length, 0)
        self.viewport_length = max(self.viewport_length, 0)
        self.position = max(0, min(self.position, self.maximum_position()))

    def next(mut self, amount: Int = 1):
        var step = max(amount, 0)
        var maximum = self.maximum_position()
        if step > maximum - self.position:
            self.position = maximum
        else:
            self.position += step

    def previous(mut self, amount: Int = 1):
        self.position = max(self.position - max(amount, 0), 0)


def _is_one_column_symbol(symbol: StringSlice) -> Bool:
    return symbol.count_graphemes() == 1 and text_width(symbol) == 1


struct ScrollbarSymbols(Copyable):
    """A validated one-column track and thumb glyph pair."""

    var track: String
    var thumb: String

    def __init__(
        out self,
        var track: String,
        var thumb: String,
        *,
        _validated: Bool,
    ):
        self.track = track^
        self.thumb = thumb^

    def __init__(out self, var track: String, var thumb: String) raises:
        if not _is_one_column_symbol(track):
            raise Error(
                String(
                    'scrollbar track symbol must be exactly one terminal column; got "',
                    track,
                    '"',
                )
            )
        if not _is_one_column_symbol(thumb):
            raise Error(
                String(
                    'scrollbar thumb symbol must be exactly one terminal column; got "',
                    thumb,
                    '"',
                )
            )
        self.track = track^
        self.thumb = thumb^

    @staticmethod
    def vertical() -> Self:
        return Self("│", "█", _validated=True)

    @staticmethod
    def horizontal() -> Self:
        return Self("─", "█", _validated=True)


struct Scrollbar(Copyable, StatefulWidget):
    """A vertical or horizontal scrollbar derived from viewport state."""

    comptime State = ScrollbarState

    var orientation: ScrollbarOrientation
    var symbols: ScrollbarSymbols
    var track_style: Style
    var thumb_style: Style

    def __init__(
        out self,
        orientation: ScrollbarOrientation = ScrollbarOrientation.VERTICAL,
        symbols: Optional[ScrollbarSymbols] = None,
        track_style: Style = Style.plain(),
        thumb_style: Style = Style.plain(),
    ):
        self.orientation = orientation
        self.symbols = (
            symbols.value().copy() if symbols else ScrollbarSymbols.vertical() if orientation
            == ScrollbarOrientation.VERTICAL else ScrollbarSymbols.horizontal()
        )
        self.track_style = track_style.copy()
        self.thumb_style = thumb_style.copy()

    @staticmethod
    def horizontal(
        track_style: Style = Style.plain(),
        thumb_style: Style = Style.plain(),
    ) -> Self:
        return Self(
            orientation=ScrollbarOrientation.HORIZONTAL,
            symbols=ScrollbarSymbols.horizontal(),
            track_style=track_style,
            thumb_style=thumb_style,
        )

    @staticmethod
    def _scaled(value: Int, extent: Int, denominator: Int) -> Int:
        if value <= 0 or extent <= 0 or denominator <= 0:
            return 0
        return min(
            extent,
            Int(Float64(value) * Float64(extent) / Float64(denominator)),
        )

    def render(self, area: Rect, mut buffer: Buffer, mut state: ScrollbarState):
        state.normalize()
        var visible_area = buffer.area.intersection(area)
        if visible_area.is_empty():
            return
        var track_length = (
            visible_area.height if self.orientation
            == ScrollbarOrientation.VERTICAL else visible_area.width
        )
        if track_length <= 0:
            return

        var thumb_length = track_length
        var maximum_position = state.maximum_position()
        if maximum_position > 0:
            thumb_length = max(
                1,
                Self._scaled(
                    state.viewport_length,
                    track_length,
                    state.content_length,
                ),
            )
        thumb_length = min(thumb_length, track_length)
        var travel = track_length - thumb_length
        var thumb_start = Self._scaled(state.position, travel, maximum_position)

        for index in range(track_length):
            var in_thumb = index >= thumb_start and index < thumb_start + thumb_length
            var point = Point(
                visible_area.right() - 1, visible_area.y + index
            ) if self.orientation == ScrollbarOrientation.VERTICAL else Point(
                visible_area.x + index, visible_area.bottom() - 1
            )
            _ = buffer.set_cell(
                point,
                Cell(
                    self.symbols.thumb if in_thumb else self.symbols.track,
                    style=self.thumb_style if in_thumb else self.track_style,
                ),
            )
