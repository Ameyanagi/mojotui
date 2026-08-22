"""Statically dispatched terminal backends."""

from std.collections import Optional
from std.memory import ArcPointer

from ..core.buffer import Buffer
from ..core.capabilities import TerminalCapabilities
from ..core.cell import Cell
from ..core.geometry import Point, Rect, Size
from ..platform import terminal_size, write_all
from .ansi import (
    _encode_ansi_inline_patch,
    _encode_ansi_patch,
    inline_clear_sequence,
    inline_reserve_sequence,
)
from .frame import (
    CompletedFrame,
    Frame,
    FramePatch,
    _FrameOwnerToken,
    diff_frame,
)
from .capabilities import detect_terminal_capabilities


trait Backend(Deinitable, Movable):
    """A destination for terminal-owned changed-cell patches."""

    def capabilities(self) -> TerminalCapabilities:
        """Return the color and appearance contract configured for output."""
        return TerminalCapabilities.conservative()

    def viewport(mut self) raises -> Rect:
        ...

    def resize_viewport(mut self, size: Size) raises:
        """Apply a host-observed terminal size when the backend is resizable."""
        pass

    def present(mut self, patch: FramePatch) raises:
        ...

    def clear(mut self) raises:
        ...

    def flush(mut self) raises:
        ...


struct Terminal[B: Backend](Movable):
    """A frame transaction owner parameterized by one concrete backend."""

    var backend: Self.B
    var previous: Buffer
    var available: Optional[Buffer]
    var force_full_redraw: Bool
    var frame_count: Int
    var _frame_owner: ArcPointer[_FrameOwnerToken]

    def __init__(out self, var backend: Self.B) raises:
        var area = backend.viewport()
        self.previous = Buffer(area)
        self.available = Buffer(area)
        self.backend = backend^
        self.force_full_redraw = True
        self.frame_count = 0
        self._frame_owner = ArcPointer(_FrameOwnerToken())

    def _refresh_viewport(mut self) raises -> Rect:
        var observed = self.backend.viewport()
        if not observed.equals(self.previous.area):
            self.previous = Buffer(observed)
            self.available = Buffer(observed)
            self.force_full_redraw = True
        return observed^

    def viewport(mut self) raises -> Rect:
        """Return the current backend viewport and prepare resize state."""
        return self._refresh_viewport()

    def capabilities(self) -> TerminalCapabilities:
        """Return the backend capability value used for theme resolution."""
        return self.backend.capabilities()

    def begin_frame(mut self) raises -> Frame:
        """Prepare a blank frame against one stable observed viewport."""
        var area = self._refresh_viewport()
        if self.available:
            var buffer = self.available.take()
            buffer.clear()
            return Frame(buffer^, self._frame_owner.copy(), self.frame_count)
        return Frame(Buffer(area), self._frame_owner.copy(), self.frame_count)

    def finish_frame(mut self, var frame: Frame) raises -> CompletedFrame:
        """Diff and present one frame, committing state only after success."""
        if not (frame._owner is self._frame_owner):
            raise Error("frame belongs to a different terminal")
        if frame.base_frame_count != self.frame_count:
            raise Error("frame was prepared from a stale terminal generation")
        if not frame.buffer.area.equals(self.previous.area):
            raise Error(
                String(
                    "completed frame does not match terminal viewport; got frame=Rect(",
                    frame.buffer.area.x,
                    ", ",
                    frame.buffer.area.y,
                    ", ",
                    frame.buffer.area.width,
                    ", ",
                    frame.buffer.area.height,
                    "), viewport=Rect(",
                    self.previous.area.x,
                    ", ",
                    self.previous.area.y,
                    ", ",
                    self.previous.area.width,
                    ", ",
                    self.previous.area.height,
                    ")",
                )
            )
        if frame.cursor and not frame.buffer.area.contains(frame.cursor.value()):
            var cursor = frame.cursor.value().copy()
            raise Error(
                String(
                    "requested cursor is outside the completed frame; got cursor (",
                    cursor.x,
                    ", ",
                    cursor.y,
                    "), frame=Rect(",
                    frame.buffer.area.x,
                    ", ",
                    frame.buffer.area.y,
                    ", ",
                    frame.buffer.area.width,
                    ", ",
                    frame.buffer.area.height,
                    ")",
                )
            )

        var full_redraw = self.force_full_redraw
        var cursor = frame.cursor.copy()
        var patch = diff_frame(
            self.previous,
            frame.buffer,
            full_redraw,
            cursor,
        )
        var changed = len(patch.changes)
        try:
            self.backend.present(patch)
        except error:
            # A backend may have written a prefix before reporting failure.
            # Preserve logical history, but distrust physical terminal state.
            self.force_full_redraw = True
            raise error
        var current = frame^.take_buffer()
        var reusable = self.previous^
        self.previous = current^
        self.available = reusable^
        self.force_full_redraw = False
        self.frame_count += 1
        return CompletedFrame(
            self.previous.area,
            self.frame_count,
            changed,
            full_redraw,
            cursor,
        )

    def present(mut self, var buffer: Buffer) raises -> CompletedFrame:
        """Compatibility path for callers that already built a complete buffer."""
        var frame = Frame(buffer^, self._frame_owner.copy(), self.frame_count)
        return self.finish_frame(frame^)

    def invalidate(mut self):
        """Force the next completed frame to repaint the entire viewport."""
        self.force_full_redraw = True

    def handle_resize(mut self, size: Size) raises:
        """Forward a host resize and invalidate terminal-owned frame history."""
        self.backend.resize_viewport(size)
        self.invalidate()

    def clear(mut self) raises:
        """Clear backend output and reset terminal-owned frame history."""
        try:
            self.backend.clear()
        except error:
            # A checked clear may have written a prefix before reporting a
            # transport error. Keep logical history and repaint it completely.
            self.force_full_redraw = True
            raise error
        self.previous.clear()
        if self.available:
            self.available.value().clear()
        self.force_full_redraw = False

    def flush(mut self) raises:
        """Flush pending backend output when its transport buffers writes."""
        self.backend.flush()

    def last_frame(self) -> Buffer:
        """Return a snapshot of the last successfully presented frame."""
        return self.previous.copy()


struct HeadlessBackend(Backend):
    """A deterministic in-memory backend for tests and snapshots."""

    var current: Buffer
    var presentation_count: Int
    var cursor: Optional[Point]
    var terminal_capabilities: TerminalCapabilities

    def __init__(
        out self,
        area: Rect,
        capabilities: TerminalCapabilities = TerminalCapabilities.headless(),
    ) raises:
        self.current = Buffer(area)
        self.presentation_count = 0
        self.cursor = None
        self.terminal_capabilities = capabilities

    def capabilities(self) -> TerminalCapabilities:
        return self.terminal_capabilities

    def viewport(mut self) raises -> Rect:
        return self.current.area.copy()

    def resize(mut self, area: Rect) raises:
        """Change the deterministic viewport observed by the next frame."""
        self.current = Buffer(area)
        self.cursor = None

    def resize_viewport(mut self, size: Size) raises:
        self.resize(
            Rect(
                self.current.area.x,
                self.current.area.y,
                size.width,
                size.height,
            )
        )

    def present(mut self, patch: FramePatch) raises:
        patch.validate()
        if patch.full_redraw:
            self.current = Buffer(patch.area)
        elif not patch.area.equals(self.current.area):
            raise Error(
                String(
                    "frame patch does not match headless viewport; got patch=Rect(",
                    patch.area.x,
                    ", ",
                    patch.area.y,
                    ", ",
                    patch.area.width,
                    ", ",
                    patch.area.height,
                    "), viewport=Rect(",
                    self.current.area.x,
                    ", ",
                    self.current.area.y,
                    ", ",
                    self.current.area.width,
                    ", ",
                    self.current.area.height,
                    ")",
                )
            )
        for index in range(len(patch.changes)):
            if not self.current.set_cell(
                patch.changes[index].point, patch.changes[index].cell
            ):
                raise Error("headless frame patch contains an invalid cell")
        self.cursor = patch.cursor.copy()
        self.presentation_count += 1

    def clear(mut self) raises:
        self.current.clear()
        self.cursor = None

    def flush(mut self) raises:
        pass

    def cell(self, point: Point) raises -> Cell:
        return self.current.cell(point)


struct AnsiBackend(Backend):
    """A stateful ANSI backend that emits only changed cells after startup."""

    var area: Rect
    var output_descriptor: Int
    var first_frame: Bool
    var dynamic_viewport: Bool
    var cursor: Optional[Point]
    var terminal_capabilities: TerminalCapabilities

    def __init__(
        out self,
        area: Rect,
        output_descriptor: Int = 1,
        dynamic_viewport: Bool = False,
        capabilities: Optional[TerminalCapabilities] = None,
    ):
        self.area = area.copy()
        self.output_descriptor = output_descriptor
        self.first_frame = True
        self.dynamic_viewport = dynamic_viewport
        self.cursor = None
        self.terminal_capabilities = (
            capabilities.value().copy() if capabilities else detect_terminal_capabilities()
        )

    @staticmethod
    def from_terminal(
        output_descriptor: Int = 1,
        capabilities: Optional[TerminalCapabilities] = None,
    ) raises -> Self:
        var observed = terminal_size(output_descriptor)
        return Self(
            Rect(0, 0, observed.columns, observed.rows),
            output_descriptor,
            True,
            capabilities,
        )

    def capabilities(self) -> TerminalCapabilities:
        return self.terminal_capabilities

    def viewport(mut self) raises -> Rect:
        if self.dynamic_viewport:
            _ = self.refresh_viewport()
        return self.area.copy()

    def refresh_viewport(mut self) raises -> Bool:
        """Recreate the previous-frame buffer after a terminal resize."""
        var observed = terminal_size(self.output_descriptor)
        if observed.columns == self.area.width and observed.rows == self.area.height:
            return False
        self.area = Rect(0, 0, observed.columns, observed.rows)
        self.first_frame = True
        self.cursor = None
        return True

    def resize_viewport(mut self, size: Size) raises:
        if not self.dynamic_viewport:
            return
        if size.width == self.area.width and size.height == self.area.height:
            return
        self.area = Rect(0, 0, size.width, size.height)
        self.cursor = None

    def present(mut self, patch: FramePatch) raises:
        patch.validate()
        if not patch.area.equals(self.area):
            raise Error(
                String(
                    "frame patch does not match ANSI backend viewport; got patch=Rect(",
                    patch.area.x,
                    ", ",
                    patch.area.y,
                    ", ",
                    patch.area.width,
                    ", ",
                    patch.area.height,
                    "), viewport=Rect(",
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
        var encoded = _encode_ansi_patch(patch)
        var presentation = String()
        var reset_screen = self.first_frame or patch.full_redraw
        if reset_screen:
            presentation += "\x1b[2J\x1b[H"
        if encoded:
            presentation += encoded
        var cursor_output = String()
        if patch.cursor:
            var point = patch.cursor.value().copy()
            if encoded or not self.cursor or not self.cursor.value().equals(point):
                cursor_output += "\x1b["
                cursor_output += String(point.y - patch.area.y + 1)
                cursor_output += ";"
                cursor_output += String(point.x - patch.area.x + 1)
                cursor_output += "H"
            if not self.cursor:
                cursor_output += "\x1b[?25h"
        elif self.cursor:
            cursor_output += "\x1b[?25l"
        if cursor_output:
            presentation += cursor_output
        if presentation:
            var output = String()
            if self.terminal_capabilities.synchronized_output:
                output += "\x1b[?2026h"
            output += presentation
            if self.terminal_capabilities.synchronized_output:
                output += "\x1b[?2026l"
            write_all(self.output_descriptor, output)
        if reset_screen:
            self.first_frame = False
        self.cursor = patch.cursor.copy()

    def clear(mut self) raises:
        var encoded = String()
        if self.cursor:
            encoded += "\x1b[?25l"
        encoded += "\x1b[2J\x1b[H"
        write_all(self.output_descriptor, encoded)
        self.first_frame = False
        self.cursor = None

    def flush(mut self) raises:
        pass


struct InlineBackend(Backend):
    """A fixed-height ANSI viewport embedded in ordinary terminal output.

    The cursor is kept immediately below the viewport between presentations.
    Applications must not write unrelated output through the same descriptor
    while this backend is active.
    """

    var area: Rect
    var output_descriptor: Int
    var first_frame: Bool
    var cursor: Optional[Point]
    var terminal_capabilities: TerminalCapabilities

    def __init__(
        out self,
        width: Int,
        height: Int,
        output_descriptor: Int = 1,
        capabilities: Optional[TerminalCapabilities] = None,
    ) raises:
        if output_descriptor < 0:
            raise Error(
                String(
                    "inline output descriptor must be non-negative; got ",
                    output_descriptor,
                )
            )
        self.area = Rect(0, 0, max(width, 0), max(height, 0))
        self.output_descriptor = output_descriptor
        self.first_frame = True
        self.cursor = None
        self.terminal_capabilities = (
            capabilities.value().copy() if capabilities else detect_terminal_capabilities()
        )

    def capabilities(self) -> TerminalCapabilities:
        return self.terminal_capabilities

    def viewport(mut self) raises -> Rect:
        return self.area.copy()

    def resize_viewport(mut self, size: Size) raises:
        """Follow terminal width while retaining the configured inline height."""
        if size.width == self.area.width:
            return
        self.area = Rect(self.area.x, self.area.y, size.width, self.area.height)

    def _return_to_anchor(self, mut output: String):
        if not self.cursor:
            return
        var point = self.cursor.value().copy()
        output += "\x1b[?25l"
        var downward = self.area.bottom() - point.y
        if downward > 0:
            output += "\x1b["
            output += String(downward)
            output += "B"
        output += "\r"

    def _place_cursor(self, mut output: String, point: Point):
        var upward = self.area.bottom() - point.y
        if upward > 0:
            output += "\x1b["
            output += String(upward)
            output += "A"
        output += "\r"
        var column = point.x - self.area.x
        if column > 0:
            output += "\x1b["
            output += String(column)
            output += "C"
        output += "\x1b[?25h"

    def present(mut self, patch: FramePatch) raises:
        patch.validate()
        if not patch.area.equals(self.area):
            raise Error(
                String(
                    (
                        "frame patch does not match inline backend viewport; got"
                        " patch=Rect("
                    ),
                    patch.area.x,
                    ", ",
                    patch.area.y,
                    ", ",
                    patch.area.width,
                    ", ",
                    patch.area.height,
                    "), viewport=Rect(",
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
        var encoded = String()
        self._return_to_anchor(encoded)
        if self.first_frame:
            encoded += inline_reserve_sequence(self.area.height)
        elif patch.full_redraw:
            encoded += inline_clear_sequence(self.area.height)
        encoded += _encode_ansi_inline_patch(patch)
        if patch.cursor:
            self._place_cursor(encoded, patch.cursor.value())
        if encoded:
            var presentation = String()
            if self.terminal_capabilities.synchronized_output:
                presentation += "\x1b[?2026h"
            presentation += encoded
            if self.terminal_capabilities.synchronized_output:
                presentation += "\x1b[?2026l"
            write_all(self.output_descriptor, presentation)
        self.first_frame = False
        self.cursor = patch.cursor.copy()

    def clear(mut self) raises:
        """Erase the owned rows; the next presentation reserves them again."""
        if self.first_frame:
            return
        var encoded = String()
        self._return_to_anchor(encoded)
        encoded += inline_clear_sequence(self.area.height)
        write_all(self.output_descriptor, encoded)
        self.first_frame = True
        self.cursor = None

    def flush(mut self) raises:
        pass
