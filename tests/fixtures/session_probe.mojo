"""PTY child used by the terminal lifecycle integration tests."""

from std.sys import argv

from mojotui import (
    InputParser,
    KeyEvent,
    PosixReactor,
    SessionOptions,
    TerminalSession,
)


def test_options() -> SessionOptions:
    return SessionOptions(
        alternate_screen=False,
        hide_cursor=False,
        bracketed_paste=False,
        focus_events=False,
    )


def check_size(reactor: PosixReactor) raises:
    if reactor.last_size.width != 80 or reactor.last_size.height != 24:
        raise Error(
            "unexpected PTY size ",
            String(reactor.last_size.width),
            "x",
            String(reactor.last_size.height),
        )


def wait_for_input(mut reactor: PosixReactor) raises:
    var parser = InputParser()
    for _ in range(20):
        var observed = reactor.wait(100)
        if observed.input_ready:
            _ = reactor.read_events(parser)
            return
    raise Error("PTY lifecycle handshake timed out")


def normal_exit() raises:
    var session = TerminalSession(options=test_options())
    var reactor = PosixReactor()
    check_size(reactor)
    print("READY", flush=True)
    wait_for_input(reactor)
    session.close()


def implicit_exit() raises:
    var session = TerminalSession(options=test_options())
    var reactor = PosixReactor()
    check_size(reactor)
    print("READY", flush=True)
    wait_for_input(reactor)
    _ = session.active


def raised_exit() raises:
    var session = TerminalSession(options=test_options())
    var reactor = PosixReactor()
    check_size(reactor)
    print("READY", flush=True)
    wait_for_input(reactor)
    _ = session.active
    raise Error("intentional lifecycle probe failure")


def control_c_exit() raises:
    var session = TerminalSession(options=test_options())
    var reactor = PosixReactor()
    var parser = InputParser()
    check_size(reactor)
    print("READY", flush=True)

    for _ in range(20):
        var observed = reactor.wait(100)
        if observed.input_ready:
            var events = reactor.read_events(parser)
            for index in range(len(events)):
                if events[index].isa[KeyEvent]():
                    var key = events[index][KeyEvent].copy()
                    if (
                        key.code == KeyEvent.CHARACTER
                        and key.text == "c"
                        and key.modifiers == KeyEvent.CONTROL
                    ):
                        session.close()
                        return
    raise Error("control-c byte was not observed")


def resize_exit() raises:
    var session = TerminalSession(options=test_options())
    var reactor = PosixReactor()
    check_size(reactor)
    print("READY", flush=True)
    for _ in range(20):
        var observed = reactor.wait(100)
        if (
            observed.resized
            and observed.size.width == 100
            and observed.size.height == 40
        ):
            print("RESIZED", flush=True)
            session.close()
            return
    raise Error("PTY resize was not observed")


def main() raises:
    var args = argv()
    var mode = String(args[1]) if len(args) > 1 else String("normal")
    if mode == "normal":
        normal_exit()
    elif mode == "implicit":
        implicit_exit()
    elif mode == "error":
        raised_exit()
    elif mode == "control-c":
        control_c_exit()
    elif mode == "resize":
        resize_exit()
    else:
        raise Error("unknown lifecycle probe mode")
