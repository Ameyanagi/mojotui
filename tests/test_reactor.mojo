from std.os import Pipe
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import InputParser, KeyEvent, MouseCapture, PosixReactor, SessionOptions
from mojotui import session_enter_sequence, session_leave_sequence
from mojotui.platform import poll_readable


def test_poll_reports_timeout_and_readiness() raises:
    var pipe = Pipe()
    var input_descriptor = pipe.fd_in.value().value

    var empty = poll_readable(input_descriptor, 0)
    assert_true(empty.timed_out)
    assert_false(empty.readable)

    pipe.write_bytes("x".as_bytes())
    var ready = poll_readable(input_descriptor, 100)
    assert_true(ready.readable)
    assert_false(ready.timed_out)
    assert_equal(pipe.fd_in.value().value, input_descriptor)


def test_reactor_reads_a_ready_event_batch() raises:
    var pipe = Pipe()
    var input_descriptor = pipe.fd_in.value().value
    var reactor = PosixReactor(input_descriptor, terminal_descriptor=-1)
    var parser = InputParser()

    pipe.write_bytes("q".as_bytes())
    var observed = reactor.wait(100)
    assert_true(observed.input_ready)
    var events = reactor.read_events(parser)
    assert_equal(len(events), 1)
    var key = events[0][KeyEvent].copy()
    assert_equal(key.text, "q")
    assert_equal(pipe.fd_in.value().value, input_descriptor)


def test_reactor_wakes_for_background_message_pipe() raises:
    var input_pipe = Pipe()
    var wakeup_pipe = Pipe()
    var input_descriptor = input_pipe.fd_in.value().value
    var wakeup_descriptor = wakeup_pipe.fd_in.value().value
    var reactor = PosixReactor(
        input_descriptor,
        terminal_descriptor=-1,
        wakeup_descriptor=wakeup_descriptor,
    )
    wakeup_pipe.write_bytes("!".as_bytes())
    var observed = reactor.wait(100)
    assert_false(observed.input_ready)
    assert_true(observed.wakeup_ready)
    var wakeup = reactor.read_wakeup()
    assert_equal(len(wakeup), 1)
    assert_equal(wakeup[0], UInt8(0x21))
    # Keep both Pipe owners alive while the reactor borrows their descriptors.
    assert_equal(input_pipe.fd_in.value().value, input_descriptor)
    assert_equal(wakeup_pipe.fd_in.value().value, wakeup_descriptor)


def test_session_sequences_reverse_enabled_features() raises:
    var options = SessionOptions(mouse=MouseCapture.MOTION)
    assert_equal(
        session_enter_sequence(options),
        "\x1b[?1049h\x1b[?25l\x1b[?2004h\x1b[?1004h\x1b[?1003h\x1b[?1006h",
    )
    assert_equal(
        session_leave_sequence(options),
        "\x1b[0m\x1b[?1006l\x1b[?1003l\x1b[?1004l\x1b[?2004l\x1b[?25h\x1b[?1049l",
    )


def test_session_sequences_cover_each_mouse_capture_policy() raises:
    var off = SessionOptions(
        False,
        False,
        False,
        False,
        MouseCapture.OFF,
    )
    assert_equal(session_enter_sequence(off), "")
    assert_equal(session_leave_sequence(off), "\x1b[0m")

    var clicks = SessionOptions(
        False,
        False,
        False,
        False,
        MouseCapture.CLICKS,
    )
    assert_equal(session_enter_sequence(clicks), "\x1b[?1000h\x1b[?1006h")
    assert_equal(session_leave_sequence(clicks), "\x1b[0m\x1b[?1006l\x1b[?1000l")

    var drag = SessionOptions(
        False,
        False,
        False,
        False,
        MouseCapture.DRAG,
    )
    assert_equal(session_enter_sequence(drag), "\x1b[?1002h\x1b[?1006h")
    assert_equal(session_leave_sequence(drag), "\x1b[0m\x1b[?1006l\x1b[?1002l")

    var motion = SessionOptions(
        False,
        False,
        False,
        False,
        MouseCapture.MOTION,
    )
    assert_equal(session_enter_sequence(motion), "\x1b[?1003h\x1b[?1006h")
    assert_equal(session_leave_sequence(motion), "\x1b[0m\x1b[?1006l\x1b[?1003l")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
