"""Bounded terminal charts with cell and braille rasterization."""

from std.collections import List, Optional
from std.math import round

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Color, Style
from ..core.widget import Widget
from ..text.rich import Alignment, Line, render_line
from ..text.width import text_width


struct Marker(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal raster marker and grid resolution."""

    comptime BRAILLE = Marker(_value=0)
    comptime DOT = Marker(_value=1)
    comptime BLOCK = Marker(_value=2)

    var _value: Int

    def __init__(out self, *, _value: Int):
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct GraphKind(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal choice between connected and independent data points."""

    comptime LINE = GraphKind(_value=0)
    comptime SCATTER = GraphKind(_value=1)

    var _value: Int

    def __init__(out self, *, _value: Int):
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct Axis(Copyable):
    """A validated numeric range with owned title and label copies.

    Direct mutation of underscore-prefixed storage is outside the public
    contract. Accessors trust construction, while ``validate()`` provides an
    explicit checkpoint after unusual direct mutation.
    """

    var _lower: Float64
    var _upper: Float64
    var _title: String
    var _labels: List[String]

    def __init__(
        out self,
        lower: Float64,
        upper: Float64,
        *,
        title: String = "",
        labels: Span[String, _] = Span[String, ImmStaticOrigin](),
    ) raises:
        self._lower = lower
        self._upper = upper
        self._title = title.copy()
        self._labels = List[String](capacity=len(labels))
        for index in range(len(labels)):
            self._labels.append(labels[index].copy())
        self.validate()

    def validate(self) raises:
        """Reject invalid state, including after unusual direct mutation."""
        if self._lower != self._lower:
            raise Error(String("lower must be non-NaN; got lower=", self._lower))
        if self._upper != self._upper:
            raise Error(String("upper must be non-NaN; got upper=", self._upper))
        if self._lower >= self._upper:
            raise Error(
                String(
                    "lower must be less than upper; got lower=",
                    self._lower,
                    ", upper=",
                    self._upper,
                )
            )

    def lower(self) -> Float64:
        return self._lower

    def upper(self) -> Float64:
        return self._upper

    def title(self) -> String:
        return self._title.copy()

    def labels(self) -> List[String]:
        return self._labels.copy()


struct Dataset(Copyable):
    """One owned series and its rendering choices.

    NaN values are valid stored data. Rendering skips a NaN point and breaks a
    line at it. Direct mutation of underscore-prefixed storage is outside the
    public contract; ``validate()`` checks the paired-series length invariant.
    """

    var _xs: List[Float64]
    var _ys: List[Float64]
    var _name: String
    var _kind: GraphKind
    var _marker: Marker
    var _style: Style

    def __init__(
        out self,
        xs: Span[Float64, _],
        ys: Span[Float64, _],
        *,
        name: String = "",
        kind: GraphKind = GraphKind.LINE,
        marker: Marker = Marker.BRAILLE,
        style: Style = Style.plain(),
    ) raises:
        self._xs = List[Float64](capacity=len(xs))
        for index in range(len(xs)):
            self._xs.append(xs[index])
        self._ys = List[Float64](capacity=len(ys))
        for index in range(len(ys)):
            self._ys.append(ys[index])
        self._name = name.copy()
        self._kind = kind
        self._marker = marker
        self._style = style.copy()
        self.validate()

    def validate(self) raises:
        """Reject invalid state, including after unusual direct mutation."""
        if len(self._xs) != len(self._ys):
            raise Error(
                String(
                    "xs and ys must have equal lengths; got len(xs)=",
                    len(self._xs),
                    ", len(ys)=",
                    len(self._ys),
                )
            )

    def xs(self) -> List[Float64]:
        return self._xs.copy()

    def ys(self) -> List[Float64]:
        return self._ys.copy()

    def name(self) -> String:
        return self._name.copy()

    def kind(self) -> GraphKind:
        return self._kind

    def marker(self) -> Marker:
        return self._marker

    def style(self) -> Style:
        return self._style.copy()


struct _GridPoint(Copyable, ImplicitlyCopyable):
    var x: Int
    var y: Int

    def __init__(out self, x: Int = 0, y: Int = 0):
        self.x = x
        self.y = y


def _default_dataset_style(index: Int, style: Style) -> Style:
    """Apply the fixed six-color cycle only to an entirely plain style."""
    if not style.equals(Style.plain()):
        return style.copy()
    var cycle_index = index % 6
    var color = 6
    if cycle_index == 1:
        color = 3
    elif cycle_index == 2:
        color = 2
    elif cycle_index == 3:
        color = 5
    elif cycle_index == 4:
        color = 4
    elif cycle_index == 5:
        color = 1
    return Style(foreground=Color(Color.INDEXED, color))


def _braille_bit(dot_x: Int, dot_y: Int) -> Int:
    if dot_x == 0:
        if dot_y == 0:
            return 0x01
        if dot_y == 1:
            return 0x02
        if dot_y == 2:
            return 0x04
        return 0x40
    if dot_y == 0:
        return 0x08
    if dot_y == 1:
        return 0x10
    if dot_y == 2:
        return 0x20
    return 0x80


def _braille_symbol(bits: Int) -> String:
    var codepoint = 0x2800 + bits
    var bytes = List[UInt8](capacity=3)
    bytes.append(UInt8(0xE0 | ((codepoint >> 12) & 0x0F)))
    bytes.append(UInt8(0x80 | ((codepoint >> 6) & 0x3F)))
    bytes.append(UInt8(0x80 | (codepoint & 0x3F)))
    return String(from_utf8_lossy=bytes)


def _right_clipped_line(content: String, width: Int) -> Line:
    var line = Line.from_text(content.copy(), alignment=Alignment.END)
    var line_width = line.width()
    if line_width > width:
        return line.scrolled(line_width - width).aligned(Alignment.END)
    return line^


def _mapped_point(
    x: Float64,
    y: Float64,
    x_axis: Axis,
    y_axis: Axis,
    grid_width: Int,
    grid_height: Int,
) -> Optional[_GridPoint]:
    if x != x or y != y:
        return None
    if x < x_axis._lower or x > x_axis._upper or y < y_axis._lower or y > y_axis._upper:
        return None

    var normalized_x = (x - x_axis._lower) / (x_axis._upper - x_axis._lower)
    var normalized_y = (y - y_axis._lower) / (y_axis._upper - y_axis._lower)
    if (
        normalized_x != normalized_x
        or normalized_y != normalized_y
        or normalized_x < 0.0
        or normalized_x > 1.0
        or normalized_y < 0.0
        or normalized_y > 1.0
    ):
        return None

    var grid_x = 0
    var grid_y = 0
    if grid_width > 1:
        grid_x = Int(round(normalized_x * Float64(grid_width - 1)))
    if grid_height > 1:
        grid_y = Int(round((1.0 - normalized_y) * Float64(grid_height - 1)))
    return _GridPoint(
        max(0, min(grid_x, grid_width - 1)),
        max(0, min(grid_y, grid_height - 1)),
    )


def _plot_grid_point(
    mut cells: List[Int],
    marker: Marker,
    graph_width: Int,
    point: _GridPoint,
):
    if marker == Marker.BRAILLE:
        var cell_x = point.x // 2
        var cell_y = point.y // 4
        var index = cell_y * graph_width + cell_x
        cells[index] = cells[index] | _braille_bit(point.x % 2, point.y % 4)
    else:
        cells[point.y * graph_width + point.x] = 1


def _raster_line(
    mut cells: List[Int],
    marker: Marker,
    graph_width: Int,
    start: _GridPoint,
    end: _GridPoint,
):
    """Draw one integer Bresenham segment, including both endpoints."""
    var x = start.x
    var y = start.y
    var delta_x = end.x - start.x
    if delta_x < 0:
        delta_x = -delta_x
    var step_x = 1 if start.x < end.x else -1
    var delta_y = end.y - start.y
    if delta_y < 0:
        delta_y = -delta_y
    delta_y = -delta_y
    var step_y = 1 if start.y < end.y else -1
    var error = delta_x + delta_y
    while True:
        _plot_grid_point(cells, marker, graph_width, _GridPoint(x, y))
        if x == end.x and y == end.y:
            return
        var doubled_error = 2 * error
        if doubled_error >= delta_y:
            error += delta_y
            x += step_x
        if doubled_error <= delta_x:
            error += delta_x
            y += step_y


def _render_dataset(
    dataset: Dataset,
    dataset_index: Int,
    x_axis: Axis,
    y_axis: Axis,
    graph: Rect,
    mut buffer: Buffer,
):
    if graph.is_empty() or len(dataset._xs) == 0:
        return
    var grid_width = graph.width
    var grid_height = graph.height
    if dataset._marker == Marker.BRAILLE:
        if graph.width > Int.MAX // 2 or graph.height > Int.MAX // 4:
            return
        grid_width *= 2
        grid_height *= 4
    if graph.width > Int.MAX // graph.height:
        return
    var cells = List[Int](length=graph.width * graph.height, fill=0)

    if dataset._kind == GraphKind.SCATTER:
        for index in range(len(dataset._xs)):
            var point = _mapped_point(
                dataset._xs[index],
                dataset._ys[index],
                x_axis,
                y_axis,
                grid_width,
                grid_height,
            )
            if point:
                _plot_grid_point(cells, dataset._marker, graph.width, point.value())
    else:
        var previous: Optional[_GridPoint] = None
        for index in range(len(dataset._xs)):
            var point = _mapped_point(
                dataset._xs[index],
                dataset._ys[index],
                x_axis,
                y_axis,
                grid_width,
                grid_height,
            )
            if previous and point:
                _raster_line(
                    cells,
                    dataset._marker,
                    graph.width,
                    previous.value(),
                    point.value(),
                )
            previous = point.copy()

    var style = _default_dataset_style(dataset_index, dataset._style)
    for y_offset in range(graph.height):
        for x_offset in range(graph.width):
            var bits = cells[y_offset * graph.width + x_offset]
            if bits == 0:
                continue
            var symbol = "•" if dataset._marker == Marker.DOT else "█"
            if dataset._marker == Marker.BRAILLE:
                symbol = _braille_symbol(bits)
            _ = buffer.set_cell(
                Point(graph.x + x_offset, graph.y + y_offset),
                Cell(symbol, style=style),
            )


def _render_y_labels(axis: Axis, gutter: Rect, graph: Rect, mut buffer: Buffer):
    if gutter.width == 0 or graph.height == 0 or len(axis._labels) == 0:
        return
    var last = len(axis._labels) - 1
    for index in range(len(axis._labels)):
        var offset = 0
        if last > 0 and graph.height > 1:
            offset = Int(
                round(Float64(index) * Float64(graph.height - 1) / Float64(last))
            )
        var row = graph.bottom() - 1 - offset
        render_line(
            _right_clipped_line(axis._labels[index], gutter.width),
            Rect(gutter.x, row, gutter.width, 1),
            buffer,
        )


def _render_x_labels(axis: Axis, row: Int, graph: Rect, mut buffer: Buffer):
    if graph.width == 0 or len(axis._labels) == 0:
        return
    var count = len(axis._labels)
    var previous_end = 0
    for index in range(count):
        var label_width = text_width(axis._labels[index])
        var start_offset = 0
        if count > 1 and index == count - 1:
            start_offset = max(0, graph.width - label_width)
        elif count > 1 and index > 0:
            var position = Int(
                round(Float64(index) * Float64(graph.width - 1) / Float64(count - 1))
            )
            start_offset = position - label_width // 2
            start_offset = max(0, min(start_offset, max(graph.width - label_width, 0)))
        if index > 0 and start_offset < previous_end:
            continue
        var visible_width = max(0, min(label_width, graph.width - start_offset))
        var line = Line.from_text(axis._labels[index].copy())
        if index == count - 1:
            line = _right_clipped_line(axis._labels[index], visible_width)
        render_line(
            line,
            Rect(graph.x + start_offset, row, visible_width, 1),
            buffer,
        )
        previous_end = start_offset + visible_width


struct Chart(Copyable, Widget):
    """A bounded, tick-free terminal plot with deterministic layout.

    One bottom row is reserved when the x axis has labels or a title. Y labels
    reserve a left gutter as wide as their widest display width; a y title alone
    does not widen it. In the remaining rectangle, the left column and bottom
    row are always the axis lines, and data occupies the cells above and right.
    Y labels run bottom-to-top and x labels run left-to-right. X labels that
    would overlap the preceding rendered label are skipped deterministically.
    The x title overwrites the right end of the horizontal axis line; the y
    title overwrites the top graph row in the gutter plus y-axis column.

    LINE segments require both endpoints to be mappable and in bounds. Segments
    crossing into the range from an out-of-bounds or NaN endpoint are not
    clipped; they are skipped. Datasets paint in order. Braille dots merge only
    within one dataset, so a later dataset replaces an earlier occupied cell.
    """

    var _datasets: List[Dataset]
    var _x_axis: Axis
    var _y_axis: Axis

    def __init__(out self, var datasets: List[Dataset], x_axis: Axis, y_axis: Axis):
        self._datasets = datasets^
        self._x_axis = x_axis.copy()
        self._y_axis = y_axis.copy()

    def datasets(self) -> List[Dataset]:
        return self._datasets.copy()

    def x_axis(self) -> Axis:
        return self._x_axis.copy()

    def y_axis(self) -> Axis:
        return self._y_axis.copy()

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return

        var reserve_x_row = len(self._x_axis._labels) > 0 or self._x_axis._title != ""
        var axis_height = area.height - (1 if reserve_x_row else 0)
        var gutter_width = 0
        for index in range(len(self._y_axis._labels)):
            gutter_width = max(gutter_width, text_width(self._y_axis._labels[index]))
        gutter_width = min(gutter_width, area.width)

        var gutter = Rect(area.x, area.y, gutter_width, max(axis_height - 1, 0))
        var axis = Rect(
            area.x + gutter_width,
            area.y,
            area.width - gutter_width,
            axis_height,
        )
        if not axis.is_empty():
            var bottom = axis.bottom() - 1
            for y in range(axis.y, axis.bottom()):
                _ = buffer.set_cell(Point(axis.x, y), Cell("│"))
            for x in range(axis.x, axis.right()):
                _ = buffer.set_cell(Point(x, bottom), Cell("─"))
            _ = buffer.set_cell(Point(axis.x, bottom), Cell("└"))

        var graph = Rect(
            axis.x + (1 if axis.width > 0 else 0),
            axis.y,
            max(axis.width - 1, 0),
            max(axis.height - 1, 0),
        )

        _render_y_labels(self._y_axis, gutter, graph, buffer)
        if reserve_x_row:
            _render_x_labels(self._x_axis, area.bottom() - 1, graph, buffer)

        if self._x_axis._title != "" and not axis.is_empty():
            render_line(
                _right_clipped_line(self._x_axis._title, axis.width),
                Rect(axis.x, axis.bottom() - 1, axis.width, 1),
                buffer,
            )
        if self._y_axis._title != "" and graph.height > 0:
            var title_width = gutter_width
            if title_width < area.width:
                title_width += 1
            render_line(
                Line.from_text(self._y_axis._title.copy()),
                Rect(area.x, graph.y, title_width, 1),
                buffer,
            )

        for index in range(len(self._datasets)):
            _render_dataset(
                self._datasets[index],
                index,
                self._x_axis,
                self._y_axis,
                graph,
                buffer,
            )
