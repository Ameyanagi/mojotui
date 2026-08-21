"""Compact data-display widgets."""

from std.collections import List
from std.math import round

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style
from ..core.widget import Widget
from ..text.rich import Alignment, Line, render_line


struct Ratio(Copyable, ImplicitlyCopyable):
    """A validated finite proportion in the inclusive range zero through one."""

    var _value: Float64

    def __init__(out self, value: Float64) raises:
        if value != value or value < 0.0 or value > 1.0:
            raise Error("ratio must be finite and between zero and one")
        self._value = value

    @staticmethod
    def percent(value: Int) raises -> Self:
        if value < 0 or value > 100:
            raise Error("percentage must be between zero and one hundred")
        return Self(Float64(value) / 100.0)

    def value(self) -> Float64:
        return self._value


struct Gauge(Copyable, Widget):
    """A horizontal filled-cell gauge with an optional centered label."""

    var ratio: Ratio
    var filled_style: Style
    var unfilled_style: Style
    var label: Line
    var show_label: Bool

    def __init__(
        out self,
        ratio: Ratio,
        filled_style: Style = Style.plain(),
        unfilled_style: Style = Style.plain(),
    ):
        self.ratio = ratio
        self.filled_style = filled_style.copy()
        self.unfilled_style = unfilled_style.copy()
        self.label = Line()
        self.show_label = False

    @staticmethod
    def labeled(
        ratio: Ratio,
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
        var ratio = self.ratio.value()
        var filled = Int(Float64(area.width) * ratio)
        if ratio == 1.0:
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

    var ratio: Ratio
    var filled_style: Style
    var unfilled_style: Style

    def __init__(
        out self,
        ratio: Ratio,
        filled_style: Style = Style.plain(),
        unfilled_style: Style = Style.plain(),
    ):
        self.ratio = ratio
        self.filled_style = filled_style.copy()
        self.unfilled_style = unfilled_style.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        var ratio = self.ratio.value()
        var filled = Int(Float64(area.width) * ratio)
        if ratio == 1.0:
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


struct BarChart(Copyable, Widget):
    """A single-series vertical bar chart with optional labels.

    Construction owns copies of both input spans. Direct mutation of the
    underscore-prefixed storage is outside the public contract; ``render()``
    trusts that storage, while ``validate()`` provides an explicit checkpoint.
    """

    var _values: List[Float64]
    var _labels: List[String]
    var _bar_width: Int
    var _gap: Int
    var _style: Style
    var _maximum: Float64

    def __init__(
        out self,
        values: Span[Float64, _],
        *,
        labels: Span[String, _] = Span[String, ImmStaticOrigin](),
        bar_width: Int = 1,
        gap: Int = 1,
        style: Style = Style.plain(),
        maximum: Optional[Float64] = None,
    ) raises:
        self._values = List[Float64](capacity=len(values))
        for index in range(len(values)):
            self._values.append(values[index])

        self._labels = List[String](capacity=len(labels))
        for index in range(len(labels)):
            self._labels.append(labels[index].copy())

        self._bar_width = bar_width
        self._gap = gap
        self._style = style.copy()
        self._maximum = maximum.value() if maximum else 0.0
        self.validate()

        if not maximum:
            for index in range(len(self._values)):
                self._maximum = max(self._maximum, self._values[index])

    def validate(self) raises:
        """Reject invalid state, including after unusual direct mutation."""
        for index in range(len(self._values)):
            var value = self._values[index]
            if value != value or value < 0.0:
                raise Error(
                    String(
                        "values[",
                        index,
                        "] must be non-NaN and within [0, inf]; got ",
                        value,
                    )
                )
        if self._bar_width < 1:
            raise Error(
                String("bar_width must be within [1, Int.MAX]; got ", self._bar_width)
            )
        if self._gap < 0:
            raise Error(String("gap must be within [0, Int.MAX]; got ", self._gap))
        if len(self._labels) != 0 and len(self._labels) != len(self._values):
            raise Error(
                String(
                    "labels must be empty or match len(values); got len(labels)=",
                    len(self._labels),
                    ", len(values)=",
                    len(self._values),
                )
            )
        if self._maximum != self._maximum or self._maximum < 0.0:
            raise Error(
                String(
                    "maximum must be non-NaN and within [0, inf]; got ",
                    self._maximum,
                )
            )

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        var has_labels = len(self._labels) != 0
        var bar_rows = area.height - (1 if has_labels else 0)
        if bar_rows == 0:
            return

        var maximum_eighths = bar_rows * 8
        var bar_x = area.x
        for index in range(len(self._values)):
            if self._bar_width > area.right() - bar_x:
                break

            var eighths = 0
            if self._maximum > 0.0:
                if self._values[index] >= self._maximum:
                    eighths = maximum_eighths
                else:
                    eighths = Int(
                        round(
                            self._values[index]
                            / self._maximum
                            * Float64(maximum_eighths)
                        )
                    )
                    eighths = max(0, min(eighths, maximum_eighths))

            var full_cells = eighths // 8
            var remainder = eighths % 8
            for x_offset in range(self._bar_width):
                var x = bar_x + x_offset
                for y_offset in range(bar_rows):
                    _ = buffer.set_cell(
                        Point(x, area.y + y_offset),
                        Cell(" ", style=self._style),
                    )
                for cell_offset in range(full_cells):
                    _ = buffer.set_cell(
                        Point(x, area.y + bar_rows - cell_offset - 1),
                        Cell("█", style=self._style),
                    )
                if remainder != 0 and full_cells < bar_rows:
                    _ = buffer.set_cell(
                        Point(x, area.y + bar_rows - full_cells - 1),
                        Cell(_spark_glyph(remainder), style=self._style),
                    )

            if has_labels:
                var label = Line.from_text(
                    self._labels[index].copy(),
                    self._style,
                    Alignment.CENTER,
                )
                render_line(
                    label,
                    Rect(bar_x, area.bottom() - 1, self._bar_width, 1),
                    buffer,
                )

            var after_bar = bar_x + self._bar_width
            if self._gap > area.right() - after_bar:
                break
            bar_x = after_bar + self._gap
