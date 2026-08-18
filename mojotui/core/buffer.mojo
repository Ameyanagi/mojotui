"""Dense, bounds-checked terminal cell buffers."""

from std.collections import List

from .cell import Cell
from .geometry import Point, Rect
from .style import Style


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
            raise Error("point is outside buffer area")
        return (point.y - self.area.y) * self.area.width + (point.x - self.area.x)

    def cell(self, point: Point) raises -> Cell:
        return self.cells[self._index(point)].copy()

    def _clear_footprint(mut self, point: Point):
        if not self.contains(point):
            return
        var index = (point.y - self.area.y) * self.area.width + (point.x - self.area.x)
        var current = self.cells[index].copy()
        self.cells[index] = Cell.blank()
        if current.continuation and point.x > self.area.x:
            var leader_index = index - 1
            if self.cells[leader_index].width == 2:
                self.cells[leader_index] = Cell.blank()
        elif current.width == 2 and point.x + 1 < self.area.right():
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

    def fill(mut self, area: Rect, cell: Cell):
        """Fill the visible intersection of area and this buffer."""
        var clipped = self.area.intersection(area)
        for y in range(clipped.y, clipped.bottom()):
            for x in range(clipped.x, clipped.right()):
                _ = self.set_cell(Point(x, y), cell)

    def clear(mut self):
        var area = self.area.copy()
        self.fill(area, Cell.blank())

    def changed_cell_count(self, other: Self) -> Int:
        """Count differences; unequal areas are entirely incompatible."""
        if not self.area.equals(other.area):
            return len(self.cells)
        var changed = 0
        for index in range(len(self.cells)):
            if not self.cells[index].equals(other.cells[index]):
                changed += 1
        return changed
