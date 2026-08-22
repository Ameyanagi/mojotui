"""Exercise terminal recovery after a real nonblocking short write."""

from std.collections import List
from std.io import FileDescriptor

from mojotui import AnsiBackend, Cell, Rect, Terminal, TerminalCapabilities


comptime OUTPUT_DESCRIPTOR = 9
comptime WIDTH = 1_000_000


def fill_frame(mut terminal: Terminal[AnsiBackend]) raises:
    var frame = terminal.begin_frame()
    frame.buffer.fill(frame.area(), Cell("x"))
    _ = terminal.finish_frame(frame^)


def main() raises:
    var terminal = Terminal(
        AnsiBackend(
            Rect(0, 0, WIDTH, 1),
            OUTPUT_DESCRIPTOR,
            capabilities=TerminalCapabilities.conservative(),
        )
    )

    try:
        fill_frame(terminal)
    except error:
        if "terminal write failed" not in String(error):
            raise Error("unexpected initial presentation failure: ", error)
        if terminal.frame_count != 0:
            raise Error("failed presentation advanced the terminal generation")
        if not terminal.force_full_redraw:
            raise Error("failed presentation did not request resynchronization")
        if not terminal.last_frame().cell({0, 0}).equals(Cell.blank()):
            raise Error("failed presentation committed terminal history")
        if not terminal.backend.first_frame:
            raise Error("failed presentation committed ANSI backend state")
        print("FAILED_WITHOUT_COMMIT ", String(error), flush=True)

        var signal = FileDescriptor(0)
        var storage = List[UInt8](length=1, fill=0)
        _ = signal.read_bytes(storage)

        var retry = terminal.begin_frame()
        retry.buffer.fill(retry.area(), Cell("x"))
        var completed = terminal.finish_frame(retry^)
        if not completed.full_redraw or completed.frame_count != 1:
            raise Error("retry did not commit one full redraw")
        if not terminal.last_frame().cell({0, 0}).equals(Cell("x")):
            raise Error("retry did not commit terminal history")
        print("RECOVERED_WITH_FULL_REDRAW", flush=True)
        return
    raise Error("nonblocking oversized presentation unexpectedly succeeded")
