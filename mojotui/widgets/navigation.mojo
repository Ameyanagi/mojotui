"""Navigation and viewport-position widgets."""

from std.collections import List as MojoList

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style
from ..core.widget import StatefulWidget, Widget
from ..text.rich import Line, Span, render_line
from ..text.width import text_width


struct Tabs(Copyable, Widget):
    """A single-row tab strip with one explicitly selected title."""

    var titles: MojoList[Line]
    var selected: Int
    var divider: String
    var style: Style
    var selected_style: Style

    def __init__(
        out self,
        var titles: MojoList[Line],
        selected: Int = 0,
        var divider: String = "│",
        style: Style = Style.plain(),
        selected_style: Style = Style(modifiers=Style.REVERSED),
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
                spans.append(Span(self.divider, self.style))
            var tab_style = (
                self.selected_style.copy() if title_index
                == self.selected else self.style.copy()
            )
            spans.append(Span(" ", tab_style))
            var title = self.titles[title_index].copy()
            for span_index in range(len(title.spans)):
                var span = title.spans[span_index].copy()
                if title_index == self.selected:
                    span.style = self.selected_style.copy()
                spans.append(span^)
            spans.append(Span(" ", tab_style))
        render_line(Line(spans^), row_area, buffer)


struct ScrollbarOrientation:
    """Axis occupied by a scrollbar."""

    comptime VERTICAL = 0
    comptime HORIZONTAL = 1


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


def _one_column_symbol(var symbol: String, var fallback: String) -> String:
    if StringSlice(symbol).count_graphemes() == 1 and text_width(symbol) == 1:
        return symbol^
    return fallback^


struct Scrollbar(Copyable, StatefulWidget):
    """A vertical or horizontal scrollbar derived from viewport state."""

    comptime State = ScrollbarState

    var orientation: Int
    var track_symbol: String
    var thumb_symbol: String
    var track_style: Style
    var thumb_style: Style

    def __init__(
        out self,
        orientation: Int = ScrollbarOrientation.VERTICAL,
        var track_symbol: String = "│",
        var thumb_symbol: String = "█",
        track_style: Style = Style.plain(),
        thumb_style: Style = Style.plain(),
    ):
        self.orientation = (
            orientation if orientation == ScrollbarOrientation.VERTICAL
            or orientation
            == ScrollbarOrientation.HORIZONTAL else ScrollbarOrientation.VERTICAL
        )
        var default_track = (
            "│" if self.orientation == ScrollbarOrientation.VERTICAL else "─"
        )
        self.track_symbol = _one_column_symbol(track_symbol^, default_track^)
        self.thumb_symbol = _one_column_symbol(thumb_symbol^, "█")
        self.track_style = track_style.copy()
        self.thumb_style = thumb_style.copy()

    @staticmethod
    def horizontal(
        track_style: Style = Style.plain(),
        thumb_style: Style = Style.plain(),
    ) -> Self:
        return Self(
            ScrollbarOrientation.HORIZONTAL,
            "─",
            "█",
            track_style,
            thumb_style,
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
                    self.thumb_symbol if in_thumb else self.track_symbol,
                    style=self.thumb_style if in_thumb else self.track_style,
                ),
            )
