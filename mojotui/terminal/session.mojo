"""Safe ownership of terminal presentation and raw-input state."""

from std.io import FileDescriptor

from ..platform import PosixTerminalMode, write_all


struct MouseCapture(Copyable, Equatable, ImplicitlyCopyable):
    """Select the terminal mouse events captured during a session."""

    comptime OFF = MouseCapture(_value=0)
    comptime CLICKS = MouseCapture(_value=1)
    comptime DRAG = MouseCapture(_value=2)
    comptime MOTION = MouseCapture(_value=3)

    var _value: Int

    def __init__(out self, *, _value: Int):
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct SessionOptions(Copyable):
    """Terminal features enabled for the duration of a session.

    Keyboard enhancement is progressive; unsupported terminals harmlessly ignore
    its push and pop sequences.
    """

    var alternate_screen: Bool
    var hide_cursor: Bool
    var bracketed_paste: Bool
    var focus_events: Bool
    var mouse: MouseCapture
    var keyboard_enhancement: Bool

    def __init__(
        out self,
        alternate_screen: Bool = True,
        hide_cursor: Bool = True,
        bracketed_paste: Bool = True,
        focus_events: Bool = True,
        mouse: MouseCapture = MouseCapture.OFF,
        keyboard_enhancement: Bool = True,
    ):
        self.alternate_screen = alternate_screen
        self.hide_cursor = hide_cursor
        self.bracketed_paste = bracketed_paste
        self.focus_events = focus_events
        self.mouse = mouse
        self.keyboard_enhancement = keyboard_enhancement


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
    if options.mouse == MouseCapture.CLICKS:
        result += "\x1b[?1000h\x1b[?1006h"
    elif options.mouse == MouseCapture.DRAG:
        result += "\x1b[?1002h\x1b[?1006h"
    elif options.mouse == MouseCapture.MOTION:
        result += "\x1b[?1003h\x1b[?1006h"
    if options.keyboard_enhancement:
        result += "\x1b[>3u"
    return result^


def session_leave_sequence(options: SessionOptions) -> String:
    """Build the reverse sequence, leaving style and cursor in safe defaults."""
    var result = String()
    if options.keyboard_enhancement:
        result += "\x1b[<u"
    result += "\x1b[0m"
    if options.mouse == MouseCapture.CLICKS:
        result += "\x1b[?1006l\x1b[?1000l"
    elif options.mouse == MouseCapture.DRAG:
        result += "\x1b[?1006l\x1b[?1002l"
    elif options.mouse == MouseCapture.MOTION:
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
    var presentation_active: Bool
    var active: Bool

    def __init__(
        out self,
        input_descriptor: Int = 0,
        output_descriptor: Int = 1,
        options: SessionOptions = SessionOptions(),
    ) raises:
        if not FileDescriptor(output_descriptor).isatty():
            raise Error(
                String(
                    "output descriptor ",
                    output_descriptor,
                    (
                        " is not an interactive terminal; run from a TTY, or use"
                        " HeadlessBackend or InlineBackend for non-interactive output"
                    ),
                )
            )
        self.input_descriptor = input_descriptor
        self.output_descriptor = output_descriptor
        self.options = options.copy()
        self.mode = PosixTerminalMode(input_descriptor)
        # Treat presentation as owned before the enter write because a failed
        # transport may already have accepted a prefix.
        self.presentation_active = True
        self.active = True
        try:
            write_all(output_descriptor, session_enter_sequence(options))
        except error:
            try:
                self.close()
            except:
                pass
            raise error

    def _sync_active(mut self):
        self.active = self.mode.active or self.presentation_active

    def close(mut self) raises:
        """Retry each unfinished cleanup half; repeated calls are harmless."""
        self._sync_active()
        if not self.active:
            return

        if self.mode.active:
            try:
                self.mode.restore()
            except raw_error:
                # Presentation cleanup is independent and must still be
                # attempted when restoring input mode fails.
                if self.presentation_active:
                    try:
                        write_all(
                            self.output_descriptor,
                            session_leave_sequence(self.options),
                        )
                        self.presentation_active = False
                    except:
                        pass
                self._sync_active()
                raise raw_error

        if self.presentation_active:
            try:
                write_all(
                    self.output_descriptor,
                    session_leave_sequence(self.options),
                )
                self.presentation_active = False
            except presentation_error:
                self._sync_active()
                raise presentation_error
        self._sync_active()

    def __deinit__(deinit self):
        if self.mode.active:
            self.mode.restore_silently()
        if self.presentation_active:
            try:
                write_all(self.output_descriptor, session_leave_sequence(self.options))
            except:
                pass
