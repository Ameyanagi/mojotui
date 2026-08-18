"""Statically dispatched terminal backends."""

from std.io import FileDescriptor

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..platform import terminal_size
from .ansi import (
    encode_ansi_diff,
    encode_ansi_inline_diff,
    inline_clear_sequence,
    inline_reserve_sequence,
)


trait Backend(Deinitable, Movable):
    """A destination for complete terminal cell buffers."""

    def viewport(self) -> Rect:
        ...

    def present(mut self, buffer: Buffer) raises:
        ...


struct Terminal[B: Backend](Movable):
    """A terminal parameterized by one concrete backend type."""

    var backend: Self.B

    def __init__(out self, var backend: Self.B):
        self.backend = backend^

    def viewport(self) -> Rect:
        return self.backend.viewport()

    def present(mut self, buffer: Buffer) raises:
        self.backend.present(buffer)


struct HeadlessBackend(Backend):
    """A deterministic in-memory backend for tests and snapshots."""

    var current: Buffer
    var presentation_count: Int

    def __init__(out self, area: Rect) raises:
        self.current = Buffer(area)
        self.presentation_count = 0

    def viewport(self) -> Rect:
        return self.current.area.copy()

    def present(mut self, buffer: Buffer) raises:
        if not buffer.area.equals(self.current.area):
            raise Error("presented buffer does not match backend viewport")
        self.current = buffer.copy()
        self.presentation_count += 1

    def cell(self, point: Point) raises -> Cell:
        return self.current.cell(point)


struct AnsiBackend(Backend):
    """A stateful ANSI backend that emits only changed cells after startup."""

    var current: Buffer
    var output_descriptor: Int
    var first_frame: Bool

    def __init__(
        out self,
        area: Rect,
        output_descriptor: Int = 1,
    ) raises:
        self.current = Buffer(area)
        self.output_descriptor = output_descriptor
        self.first_frame = True

    @staticmethod
    def from_terminal(output_descriptor: Int = 1) raises -> Self:
        var observed = terminal_size(output_descriptor)
        return Self(
            Rect(0, 0, observed.columns, observed.rows),
            output_descriptor,
        )

    def viewport(self) -> Rect:
        return self.current.area.copy()

    def refresh_viewport(mut self) raises -> Bool:
        """Recreate the previous-frame buffer after a terminal resize."""
        var observed = terminal_size(self.output_descriptor)
        if (
            observed.columns == self.current.area.width
            and observed.rows == self.current.area.height
        ):
            return False
        self.current = Buffer(Rect(0, 0, observed.columns, observed.rows))
        self.first_frame = True
        return True

    def present(mut self, buffer: Buffer) raises:
        if not buffer.area.equals(self.current.area):
            raise Error("presented buffer does not match ANSI backend viewport")
        var encoded = encode_ansi_diff(self.current, buffer)
        var output = FileDescriptor(self.output_descriptor)
        if self.first_frame:
            output.write_string("\x1b[2J\x1b[H")
            self.first_frame = False
        if encoded:
            output.write_string(encoded)
        self.current = buffer.copy()


struct InlineBackend(Backend):
    """A fixed-height ANSI viewport embedded in ordinary terminal output.

    The cursor is kept immediately below the viewport between presentations.
    Applications must not write unrelated output through the same descriptor
    while this backend is active.
    """

    var current: Buffer
    var output_descriptor: Int
    var first_frame: Bool

    def __init__(
        out self,
        width: Int,
        height: Int,
        output_descriptor: Int = 1,
    ) raises:
        if output_descriptor < 0:
            raise Error("inline output descriptor must be non-negative")
        self.current = Buffer(Rect(0, 0, max(width, 0), max(height, 0)))
        self.output_descriptor = output_descriptor
        self.first_frame = True

    def viewport(self) -> Rect:
        return self.current.area.copy()

    def present(mut self, buffer: Buffer) raises:
        if not buffer.area.equals(self.current.area):
            raise Error("presented buffer does not match inline backend viewport")
        var output = FileDescriptor(self.output_descriptor)
        if self.first_frame:
            output.write_string(inline_reserve_sequence(self.current.area.height))
            self.first_frame = False
        var encoded = encode_ansi_inline_diff(self.current, buffer)
        if encoded:
            output.write_string(encoded)
        self.current = buffer.copy()

    def clear(mut self):
        """Erase the owned rows; the next presentation reserves them again."""
        if self.first_frame:
            return
        var output = FileDescriptor(self.output_descriptor)
        output.write_string(inline_clear_sequence(self.current.area.height))
        self.current.clear()
        self.first_frame = True
