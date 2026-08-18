"""Safe ownership of terminal presentation and raw-input state."""

from std.io import FileDescriptor

from ..platform import PosixTerminalMode


struct SessionOptions(Copyable):
    """Terminal features enabled for the duration of a session."""

    var alternate_screen: Bool
    var hide_cursor: Bool
    var bracketed_paste: Bool
    var focus_events: Bool
    var mouse_capture: Bool

    def __init__(
        out self,
        alternate_screen: Bool = True,
        hide_cursor: Bool = True,
        bracketed_paste: Bool = True,
        focus_events: Bool = True,
        mouse_capture: Bool = False,
    ):
        self.alternate_screen = alternate_screen
        self.hide_cursor = hide_cursor
        self.bracketed_paste = bracketed_paste
        self.focus_events = focus_events
        self.mouse_capture = mouse_capture


def session_enter_sequence(options: SessionOptions) -> String:
    """Build the deterministic ANSI sequence for enabled session features."""
    var result = String()
    if options.alternate_screen:
        result += "\x1b[?1049h"
    if options.hide_cursor:
        result += "\x1b[?25l"
    if options.bracketed_paste:
        result += "\x1b[?2004h"
    if options.focus_events:
        result += "\x1b[?1004h"
    if options.mouse_capture:
        result += "\x1b[?1003h\x1b[?1006h"
    return result^


def session_leave_sequence(options: SessionOptions) -> String:
    """Build the reverse sequence, leaving style and cursor in safe defaults."""
    var result = String("\x1b[0m")
    if options.mouse_capture:
        result += "\x1b[?1006l\x1b[?1003l"
    if options.focus_events:
        result += "\x1b[?1004l"
    if options.bracketed_paste:
        result += "\x1b[?2004l"
    if options.hide_cursor:
        result += "\x1b[?25h"
    if options.alternate_screen:
        result += "\x1b[?1049l"
    return result^


struct TerminalSession(Movable):
    """RAII guard that restores raw mode and presentation state."""

    var input_descriptor: Int
    var output_descriptor: Int
    var options: SessionOptions
    var mode: PosixTerminalMode
    var active: Bool

    def __init__(
        out self,
        input_descriptor: Int = 0,
        output_descriptor: Int = 1,
        options: SessionOptions = SessionOptions(),
    ) raises:
        if not FileDescriptor(output_descriptor).isatty():
            raise Error("terminal output descriptor is not a TTY")
        self.input_descriptor = input_descriptor
        self.output_descriptor = output_descriptor
        self.options = options.copy()
        self.mode = PosixTerminalMode(input_descriptor)
        self.active = True
        var output = FileDescriptor(output_descriptor)
        output.write_string(session_enter_sequence(options))

    def close(mut self) raises:
        """Restore presentation and input state; repeated calls are harmless."""
        if not self.active:
            return
        self.mode.restore()
        var output = FileDescriptor(self.output_descriptor)
        output.write_string(session_leave_sequence(self.options))
        self.active = False

    def __deinit__(deinit self):
        if self.active:
            self.mode.restore_silently()
            var output = FileDescriptor(self.output_descriptor)
            output.write_string(session_leave_sequence(self.options))
