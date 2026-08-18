"""Compact data-display widgets."""

from std.collections import List

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style
from ..core.widget import Widget
from ..text.rich import Alignment, Line, render_line


def _safe_ratio(value: Float64) -> Float64:
    if value != value or value < 0.0:
        return 0.0
    if value > 1.0:
        return 1.0
    return value


struct Gauge(Copyable, Widget):
    """A horizontal filled-cell gauge with an optional centered label."""

    var ratio: Float64
    var filled_style: Style
    var unfilled_style: Style
    var label: Line
    var show_label: Bool

    def __init__(
        out self,
        ratio: Float64,
        filled_style: Style = Style.plain(),
        unfilled_style: Style = Style.plain(),
    ):
        self.ratio = _safe_ratio(ratio)
        self.filled_style = filled_style.copy()
        self.unfilled_style = unfilled_style.copy()
        self.label = Line()
        self.show_label = False

    @staticmethod
    def labeled(
        ratio: Float64,
        label: Line,
        filled_style: Style = Style.plain(),
        unfilled_style: Style = Style.plain(),
    ) -> Self:
        var result = Self(ratio, filled_style, unfilled_style)
        result.label = label.copy()
        result.label.alignment = Alignment.CENTER
        result.show_label = True
        return result^

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        var filled = Int(Float64(area.width) * self.ratio)
        if self.ratio == 1.0:
            filled = area.width
        for y in range(area.y, area.bottom()):
            for offset in range(area.width):
                var is_filled = offset < filled
                _ = buffer.set_cell(
                    Point(area.x + offset, y),
                    Cell(
                        "█" if is_filled else "░",
                        style=self.filled_style if is_filled else self.unfilled_style,
                    ),
                )
        if self.show_label:
            render_line(self.label, Rect(area.x, area.y, area.width, 1), buffer)


struct LineGauge(Copyable, Widget):
    """A single-row gauge rendered with heavy and light line glyphs."""

    var ratio: Float64
    var filled_style: Style
    var unfilled_style: Style

    def __init__(
        out self,
        ratio: Float64,
        filled_style: Style = Style.plain(),
        unfilled_style: Style = Style.plain(),
    ):
        self.ratio = _safe_ratio(ratio)
        self.filled_style = filled_style.copy()
        self.unfilled_style = unfilled_style.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        var filled = Int(Float64(area.width) * self.ratio)
        if self.ratio == 1.0:
            filled = area.width
        for offset in range(area.width):
            var is_filled = offset < filled
            _ = buffer.set_cell(
                Point(area.x + offset, area.y),
                Cell(
                    "━" if is_filled else "─",
                    style=self.filled_style if is_filled else self.unfilled_style,
                ),
            )


def _spark_glyph(level: Int) -> String:
    if level <= 1:
        return "▁"
    if level == 2:
        return "▂"
    if level == 3:
        return "▃"
    if level == 4:
        return "▄"
    if level == 5:
        return "▅"
    if level == 6:
        return "▆"
    if level == 7:
        return "▇"
    return "█"


struct Sparkline(Copyable, Widget):
    """A one-row view of the newest integer samples."""

    var values: List[Int]
    var maximum: Int
    var style: Style

    def __init__(
        out self,
        var values: List[Int],
        maximum: Int = 0,
        style: Style = Style.plain(),
    ):
        self.values = values^
        self.maximum = max(maximum, 0)
        self.style = style.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty() or len(self.values) == 0:
            return
        var maximum = self.maximum
        if maximum == 0:
            for index in range(len(self.values)):
                maximum = max(maximum, self.values[index])
        if maximum <= 0:
            maximum = 1
        var visible = min(area.width, len(self.values))
        var start = len(self.values) - visible
        for offset in range(visible):
            var value = max(0, min(self.values[start + offset], maximum))
            var level = Int(Float64(value) * 8.0 / Float64(maximum))
            if value > 0:
                level = max(level, 1)
            _ = buffer.set_cell(
                Point(area.x + offset, area.y),
                Cell(_spark_glyph(level), style=self.style),
            )
