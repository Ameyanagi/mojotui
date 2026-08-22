"""PTY child used by the terminal lifecycle integration tests."""

from std.collections import List, Optional
from std.io import FileDescriptor
from std.sys import argv

from mojotui import (
    Application,
    Backend,
    Buffer,
    Cell,
    Command,
    InitResult,
    InputEvent,
    InputParser,
    InlineBackend,
    KeyEvent,
    ManualClock,
    MouseCapture,
    PosixReactor,
    Rect,
    FramePatch,
    RuntimeAdapter,
    SessionOptions,
    Subscription,
    TerminalApplicationHost,
    TerminalSession,
    UpdateResult,
)


struct BlockingFailBackend(Backend):
    """Wait until the PTY observes raw mode, then fail host construction."""

    def __init__(out self):
        pass

    def viewport(mut self) raises -> Rect:
        var storage = List[UInt8](length=1, fill=0)
        var input = FileDescriptor(0)
        _ = input.read_bytes(storage)
        raise Error("intentional backend initialization failure")

    def present(mut self, patch: FramePatch) raises:
        pass

    def clear(mut self) raises:
        pass

    def flush(mut self) raises:
        pass


struct HostProbeApplication(Application, Copyable):
    comptime Model = Bool
    comptime Message = KeyEvent
    comptime Effect = Int

    def __init__(out self):
        pass

    def init(mut self) raises -> InitResult[Self.Model, Self.Effect]:
        return InitResult[Self.Model, Self.Effect].ready(False)

    def update(
        mut self, mut model: Self.Model, var message: Self.Message
    ) raises -> UpdateResult[Self.Effect]:
        model = True
        return UpdateResult[Self.Effect].exit()

    def view(self, model: Self.Model, area: Rect, mut buffer: Buffer) raises:
        buffer.fill(area, Cell("H" if model else "h"))

    def on_input(
        self, model: Self.Model, var event: InputEvent
    ) raises -> Optional[Self.Message]:
        if event.isa[KeyEvent]():
            return event[KeyEvent].copy()
        return None


struct HostProbeAdapter(RuntimeAdapter):
    comptime ApplicationType = HostProbeApplication

    def __init__(out self):
        pass

    def execute(mut self, var command: Command[Self.ApplicationType.Effect]) raises:
        pass

    def start(
        mut self, var subscription: Subscription[Self.ApplicationType.Effect]
    ) raises:
        pass

    def stop(mut self, id: StringSlice) raises:
        pass

    def take_messages(mut self) raises -> List[Self.ApplicationType.Message]:
        return []

    def close(mut self) raises:
        pass

    def close_silently(mut self):
        pass


def test_options() -> SessionOptions:
    return SessionOptions(
        alternate_screen=False,
        hide_cursor=False,
        bracketed_paste=False,
        focus_events=False,
        mouse=MouseCapture.OFF,
        keyboard_enhancement=False,
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


def hosted_exit() raises:
    var host = TerminalApplicationHost(
        HostProbeAdapter(),
        HostProbeApplication(),
        ManualClock(),
        InlineBackend(80, 1),
        options=test_options(),
        tick_interval_ms=100,
    )
    print("READY", flush=True)
    host.run()


def split_descriptor_resize_exit() raises:
    var host = TerminalApplicationHost(
        HostProbeAdapter(),
        HostProbeApplication(),
        ManualClock(),
        InlineBackend(100, 1),
        options=test_options(),
        tick_interval_ms=100,
    )
    if host.reactor.last_size.width != 100 or host.reactor.last_size.height != 40:
        raise Error("host reactor queried the wrong terminal descriptor")
    print("READY", flush=True)
    for _ in range(20):
        _ = host.poll_once()
        if host.application.terminal.backend.area.width == 120:
            if host.application.terminal.backend.area.height != 1:
                raise Error("inline resize changed the fixed viewport height")
            print("RESIZED", flush=True)
            host.close()
            return
    raise Error("split-descriptor inline resize was not observed")


def overlapping_session_exit() raises:
    var session = TerminalSession(options=test_options())
    try:
        var overlapping = TerminalSession(options=test_options())
        overlapping.close()
    except error:
        if "already in raw mode" not in String(error):
            raise Error("overlapping session failed for an unexpected reason: ", error)
        print("READY", flush=True)
        var reactor = PosixReactor()
        wait_for_input(reactor)
        session.close()
        return
    raise Error("overlapping terminal session unexpectedly acquired the same TTY")


def host_initialization_failure() raises:
    print("READY", flush=True)
    var host = TerminalApplicationHost(
        HostProbeAdapter(),
        HostProbeApplication(),
        ManualClock(),
        BlockingFailBackend(),
        options=test_options(),
    )
    _ = host.closed


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
    elif mode == "host":
        hosted_exit()
    elif mode == "split-descriptors":
        split_descriptor_resize_exit()
    elif mode == "overlap":
        overlapping_session_exit()
    elif mode == "host-init-error":
        host_initialization_failure()
    else:
        raise Error("unknown lifecycle probe mode")
