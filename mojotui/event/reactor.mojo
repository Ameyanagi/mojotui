"""Synchronous POSIX event polling with safe owned results."""

from std.collections import List

from ..core.geometry import Size
from ..platform import poll_readable_pair, read_available, terminal_size
from .input import InputEvent, InputParser


struct ReactorPoll(Copyable):
    """One reactor observation with coalesced timer and resize state."""

    var input_ready: Bool
    var wakeup_ready: Bool
    var timer_elapsed: Bool
    var interrupted: Bool
    var hangup: Bool
    var failed: Bool
    var resized: Bool
    var size: Size

    def __init__(
        out self,
        input_ready: Bool = False,
        wakeup_ready: Bool = False,
        timer_elapsed: Bool = False,
        interrupted: Bool = False,
        hangup: Bool = False,
        failed: Bool = False,
        resized: Bool = False,
        size: Size = Size(),
    ):
        self.input_ready = input_ready
        self.wakeup_ready = wakeup_ready
        self.timer_elapsed = timer_elapsed
        self.interrupted = interrupted
        self.hangup = hangup
        self.failed = failed
        self.resized = resized
        self.size = size.copy()


struct PosixReactor(Movable):
    """Poll terminal input and sample resize state after each wakeup."""

    var input_descriptor: Int
    var terminal_descriptor: Int
    var wakeup_descriptor: Int
    var last_size: Size

    def __init__(
        out self,
        input_descriptor: Int = 0,
        terminal_descriptor: Int = 0,
        wakeup_descriptor: Int = -1,
    ) raises:
        self.input_descriptor = input_descriptor
        self.terminal_descriptor = terminal_descriptor
        self.wakeup_descriptor = wakeup_descriptor
        if terminal_descriptor >= 0:
            var initial = terminal_size(terminal_descriptor)
            self.last_size = Size(initial.columns, initial.rows)
        else:
            self.last_size = Size()

    def wait(mut self, timeout_ms: Int) raises -> ReactorPoll:
        """Wait for input or timeout, then coalesce a size change."""
        var readiness = poll_readable_pair(
            self.input_descriptor,
            self.wakeup_descriptor,
            timeout_ms,
        )
        var size = self.last_size.copy()
        var resized = False
        if self.terminal_descriptor >= 0:
            var observed = terminal_size(self.terminal_descriptor)
            var next_size = Size(observed.columns, observed.rows)
            resized = (
                next_size.width != self.last_size.width
                or next_size.height != self.last_size.height
            )
            if resized:
                self.last_size = next_size.copy()
            size = next_size^
        return ReactorPoll(
            input_ready=readiness.first.readable,
            wakeup_ready=readiness.second.readable,
            timer_elapsed=readiness.first.timed_out,
            interrupted=readiness.first.interrupted,
            hangup=readiness.first.hangup or readiness.second.hangup,
            failed=readiness.first.failed or readiness.second.failed,
            resized=resized,
            size=size,
        )

    def read_events(
        self, mut parser: InputParser, limit: Int = 4096
    ) raises -> List[InputEvent]:
        """Read one ready batch and feed the incremental parser."""
        var bytes = read_available(self.input_descriptor, limit)
        return parser.feed(bytes^)

    def read_wakeup(self, limit: Int = 4096) raises -> List[UInt8]:
        """Drain one ready batch from the configured wakeup descriptor."""
        if self.wakeup_descriptor < 0:
            raise Error("reactor has no wakeup descriptor")
        return read_available(self.wakeup_descriptor, limit)
