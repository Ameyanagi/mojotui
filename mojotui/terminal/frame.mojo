"""One stable render transaction and its backend-facing changed cells."""

from std.collections import List, Optional
from std.memory import ArcPointer

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.widget import StatefulWidget, Widget


struct _FrameOwnerToken(Movable):
    """Identity-only allocation shared by one terminal and its frames."""

    def __init__(out self):
        pass


struct CellChange(Copyable):
    """One row-major cell update produced by a completed frame."""

    var point: Point
    var cell: Cell

    def __init__(out self, point: Point, cell: Cell):
        self.point = point.copy()
        self.cell = cell.copy()


struct FramePatch(Copyable):
    """Changed cells and presentation intent passed to a terminal backend."""

    var area: Rect
    var changes: List[CellChange]
    var full_redraw: Bool
    var cursor: Optional[Point]

    def __init__(
        out self,
        area: Rect,
        var changes: List[CellChange],
        full_redraw: Bool = False,
        cursor: Optional[Point] = None,
    ):
        self.area = area.copy()
        self.changes = changes^
        self.full_redraw = full_redraw
        self.cursor = cursor.copy()

    def validate(self) raises:
        """Reject malformed, unordered, or overlapping backend updates."""
        var previous_index = -1
        var previous_width = 0
        for change_index in range(len(self.changes)):
            var change = self.changes[change_index].copy()
            if not self.area.contains(change.point):
                raise Error("frame patch contains an out-of-area cell change")
            if not change.cell.is_valid() or change.cell.continuation:
                raise Error("frame patch contains an invalid cell change")
            if change.cell.width == 2 and change.point.x + 1 >= self.area.right():
                raise Error("frame patch contains a clipped wide-cell leader")
            var index = (change.point.y - self.area.y) * self.area.width + (
                change.point.x - self.area.x
            )
            if index <= previous_index:
                raise Error("frame patch changes must be unique and row-major")
            if previous_width == 2 and index == previous_index + 1:
                raise Error("frame patch change overlaps a preceding wide cell")
            previous_index = index
            previous_width = change.cell.width
        if self.cursor and not self.area.contains(self.cursor.value()):
            raise Error("frame patch cursor is outside its area")


struct Frame(Movable):
    """A complete frame prepared against one stable terminal viewport."""

    var buffer: Buffer
    var cursor: Optional[Point]
    var base_frame_count: Int
    var _owner: ArcPointer[_FrameOwnerToken]

    def __init__(
        out self,
        area: Rect,
        base_frame_count: Int = 0,
    ) raises:
        self.buffer = Buffer(area)
        self.cursor = None
        self.base_frame_count = max(base_frame_count, 0)
        self._owner = ArcPointer(_FrameOwnerToken())

    def __init__(
        out self,
        var buffer: Buffer,
        base_frame_count: Int = 0,
    ):
        self.buffer = buffer^
        self.cursor = None
        self.base_frame_count = max(base_frame_count, 0)
        self._owner = ArcPointer(_FrameOwnerToken())

    def __init__(
        out self,
        var buffer: Buffer,
        var owner: ArcPointer[_FrameOwnerToken],
        base_frame_count: Int,
    ):
        self.buffer = buffer^
        self.cursor = None
        self.base_frame_count = max(base_frame_count, 0)
        self._owner = owner^

    def area(self) -> Rect:
        return self.buffer.area.copy()

    def render_widget[W: Widget](mut self, widget: W, area: Rect):
        """Render a stateless concrete widget into this frame."""
        widget.render(area, self.buffer)

    def render_stateful_widget[
        W: StatefulWidget
    ](mut self, widget: W, area: Rect, mut state: W.State) raises:
        """Render a concrete widget with caller-owned mutable state."""
        widget.render(area, self.buffer, state)

    def set_cursor_position(mut self, point: Point):
        """Request a visible hardware cursor after this frame is presented."""
        self.cursor = point.copy()

    def hide_cursor(mut self):
        """Request a hidden hardware cursor after this frame is presented."""
        self.cursor = None

    def take_buffer(deinit self) -> Buffer:
        """Consume this completed transaction and return its owned buffer."""
        return self.buffer^


struct CompletedFrame(Copyable):
    """Stable metadata describing one successfully presented frame."""

    var area: Rect
    var frame_count: Int
    var changed_cell_count: Int
    var full_redraw: Bool
    var cursor: Optional[Point]

    def __init__(
        out self,
        area: Rect,
        frame_count: Int,
        changed_cell_count: Int,
        full_redraw: Bool,
        cursor: Optional[Point] = None,
    ):
        self.area = area.copy()
        self.frame_count = max(frame_count, 0)
        self.changed_cell_count = max(changed_cell_count, 0)
        self.full_redraw = full_redraw
        self.cursor = cursor.copy()


def diff_frame(
    before: Buffer,
    after: Buffer,
    full_redraw: Bool = False,
    cursor: Optional[Point] = None,
) raises -> FramePatch:
    """Collect safe row-major changes without emitting wide continuations."""
    before.validate_topology()
    after.validate_topology()
    if not before.area.equals(after.area):
        raise Error(
            String(
                "frame diff buffers must have equal areas; got before=Rect(",
                before.area.x,
                ", ",
                before.area.y,
                ", ",
                before.area.width,
                ", ",
                before.area.height,
                "), after=Rect(",
                after.area.x,
                ", ",
                after.area.y,
                ", ",
                after.area.width,
                ", ",
                after.area.height,
                ")",
            )
        )

    var changes = List[CellChange]()
    var blank = Cell.blank()
    for index in range(len(after.cells)):
        if after.cells[index].continuation:
            continue
        if full_redraw and after.cells[index].equals(blank):
            continue
        if not full_redraw and before.cells[index].equals(after.cells[index]):
            continue
        var x = after.area.x + index % after.area.width
        var y = after.area.y + index // after.area.width
        changes.append(CellChange(Point(x, y), after.cells[index]))
    return FramePatch(after.area, changes^, full_redraw, cursor)
