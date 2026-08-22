"""Dense, bounds-checked terminal cell buffers."""

from std.collections import List

from .cell import Cell
from .geometry import Point, Rect
from .style import Style, StylePatch


struct BufferWrite(Copyable):
    """Observable outcome of a clipped single-line buffer write."""

    var end: Point
    var graphemes_written: Int
    var columns_written: Int
    var truncated: Bool

    def __init__(
        out self,
        end: Point,
        graphemes_written: Int,
        columns_written: Int,
        truncated: Bool,
    ):
        self.end = end.copy()
        self.graphemes_written = graphemes_written
        self.columns_written = columns_written
        self.truncated = truncated


struct BufferDifference(Copyable):
    """One changed coordinate with resolved cells from both buffers."""

    var point: Point
    var before: Cell
    var after: Cell

    def __init__(out self, point: Point, before: Cell, after: Cell):
        self.point = point.copy()
        self.before = before.copy()
        self.after = after.copy()


struct Buffer(Copyable, Sized):
    """A dense row-major cell buffer anchored at a signed rectangle."""

    var area: Rect
    var cells: List[Cell]

    def __init__(out self, area: Rect) raises:
        self.area = area.copy()
        self.cells = List[Cell](length=area.area(), fill=Cell.blank())

    def __len__(self) -> Int:
        return len(self.cells)

    def contains(self, point: Point) -> Bool:
        return self.area.contains(point)

    def _index(self, point: Point) raises -> Int:
        if not self.contains(point):
            raise Error(
                String(
                    "point (",
                    point.x,
                    ", ",
                    point.y,
                    ") is outside buffer area Rect(",
                    self.area.x,
                    ", ",
                    self.area.y,
                    ", ",
                    self.area.width,
                    ", ",
                    self.area.height,
                    ")",
                )
            )
        return (point.y - self.area.y) * self.area.width + (point.x - self.area.x)

    def cell(self, point: Point) raises -> Cell:
        return self.cells[self._index(point)].copy()

    def _clear_footprint(mut self, point: Point):
        if not self.contains(point):
            return
        var index = (point.y - self.area.y) * self.area.width + (point.x - self.area.x)
        var was_continuation = self.cells[index].continuation
        var previous_width = self.cells[index].width
        self.cells[index] = Cell.blank()
        if was_continuation and point.x > self.area.x:
            var leader_index = index - 1
            if self.cells[leader_index].width == 2:
                self.cells[leader_index] = Cell.blank()
        elif previous_width == 2 and point.x + 1 < self.area.right():
            var trailing_index = index + 1
            if self.cells[trailing_index].continuation:
                self.cells[trailing_index] = Cell.blank()

    def set_cell(mut self, point: Point, cell: Cell) -> Bool:
        """Set a cell while maintaining wide-grapheme continuation state."""
        if not self.contains(point):
            return False
        if cell.width == 2 and point.x + 1 >= self.area.right():
            return False

        self._clear_footprint(point)
        if cell.width == 2:
            self._clear_footprint(Point(point.x + 1, point.y))

        var index = (point.y - self.area.y) * self.area.width + (point.x - self.area.x)
        self.cells[index] = cell.copy()
        if cell.width == 2:
            self.cells[index + 1] = Cell.trailing(cell.style)
        return True

    def set_grapheme(
        mut self,
        point: Point,
        var symbol: String,
        style: Style = Style.plain(),
        ambiguous_is_wide: Bool = False,
    ) raises -> Bool:
        """Validate, measure, and place one complete grapheme cluster."""
        var cell = Cell.from_grapheme(symbol^, ambiguous_is_wide, style)
        return self.set_cell(point, cell)

    def set_string(
        mut self,
        point: Point,
        content: String,
        style: Style = Style.plain(),
        ambiguous_is_wide: Bool = False,
    ) raises -> BufferWrite:
        """Write one logical line and report clipping without splitting glyphs."""
        var x = point.x
        var graphemes_written = 0
        var columns_written = 0
        var has_content = StringSlice(content).count_graphemes() > 0
        if point.y < self.area.y or point.y >= self.area.bottom():
            return BufferWrite(point, 0, 0, has_content)
        if point.x < self.area.x or point.x >= self.area.right():
            return BufferWrite(point, 0, 0, has_content)

        for grapheme in content.graphemes():
            var cell = Cell.from_grapheme(String(grapheme), ambiguous_is_wide, style)
            if cell.width == 0:
                continue
            if x >= self.area.right() or cell.width > self.area.right() - x:
                return BufferWrite(
                    Point(x, point.y),
                    graphemes_written,
                    columns_written,
                    True,
                )
            _ = self.set_cell(Point(x, point.y), cell)
            x += cell.width
            graphemes_written += 1
            columns_written += cell.width

        return BufferWrite(
            Point(x, point.y),
            graphemes_written,
            columns_written,
            False,
        )

    def fill(mut self, area: Rect, cell: Cell):
        """Fill the visible intersection of area and this buffer."""
        var clipped = self.area.intersection(area)
        if clipped.is_empty():
            return
        if cell.width == 1 and not cell.continuation:
            for y in range(clipped.y, clipped.bottom()):
                self._clear_footprint(Point(clipped.x, y))
                if clipped.width > 1:
                    self._clear_footprint(Point(clipped.right() - 1, y))
                var start = (y - self.area.y) * self.area.width + (
                    clipped.x - self.area.x
                )
                for index in range(start, start + clipped.width):
                    self.cells[index] = cell.copy()
            return
        for y in range(clipped.y, clipped.bottom()):
            for x in range(clipped.x, clipped.right()):
                _ = self.set_cell(Point(x, y), cell)

    def clear(mut self):
        var area = self.area.copy()
        self.fill(area, Cell.blank())

    def patch_style(mut self, area: Rect, patch: StylePatch):
        """Patch every visible cell while preserving wide-cell invariants."""
        var clipped = self.area.intersection(area)
        for y in range(clipped.y, clipped.bottom()):
            for x in range(clipped.x, clipped.right()):
                var index = (y - self.area.y) * self.area.width + (x - self.area.x)
                self.cells[index].apply_style_patch(patch)

    def resize(mut self, area: Rect) raises:
        """Resize while retaining only complete cells in the shared rectangle."""
        if self.area.equals(area):
            return
        var source = self.copy()
        var resized = Buffer(area)
        var overlap = source.area.intersection(area)
        for y in range(overlap.y, overlap.bottom()):
            for x in range(overlap.x, overlap.right()):
                var point = Point(x, y)
                var cell = source.cell(point)
                if cell.continuation:
                    continue
                if cell.width == 2 and x + 1 >= overlap.right():
                    continue
                _ = resized.set_cell(point, cell)
        self.area = resized.area.copy()
        self.cells = resized.cells.copy()

    def merge(mut self, other: Self) raises:
        """Grow to the union and overlay every complete cell from `other`."""
        var combined = self.area.union(other.area)
        self.resize(combined)
        for y in range(other.area.y, other.area.bottom()):
            for x in range(other.area.x, other.area.right()):
                var point = Point(x, y)
                var cell = other.cell(point)
                if cell.continuation:
                    continue
                _ = self.set_cell(point, cell)

    def differences(self, other: Self) raises -> List[BufferDifference]:
        """Return row-major changes from this buffer to an equal-area buffer."""
        if not self.area.equals(other.area):
            raise Error(
                String(
                    "cannot compare buffers with different areas; got self=Rect(",
                    self.area.x,
                    ", ",
                    self.area.y,
                    ", ",
                    self.area.width,
                    ", ",
                    self.area.height,
                    "), other=Rect(",
                    other.area.x,
                    ", ",
                    other.area.y,
                    ", ",
                    other.area.width,
                    ", ",
                    other.area.height,
                    ")",
                )
            )
        var changes = List[BufferDifference]()
        for index in range(len(self.cells)):
            if not self.cells[index].equals(other.cells[index]):
                var x = self.area.x + index % self.area.width
                var y = self.area.y + index // self.area.width
                changes.append(
                    BufferDifference(Point(x, y), self.cells[index], other.cells[index])
                )
        return changes^

    def changed_cell_count(self, other: Self) -> Int:
        """Count differences; unequal areas are entirely incompatible."""
        if not self.area.equals(other.area):
            return len(self.cells)
        var changed = 0
        for index in range(len(self.cells)):
            if not self.cells[index].equals(other.cells[index]):
                changed += 1
        return changed
