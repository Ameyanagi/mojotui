"""Manual-loop hello: session, terminal, reactor, and parser wired by hand."""

from mojotui import (
    AnsiBackend,
    InputParser,
    KeyEvent,
    Line,
    Paragraph,
    PosixReactor,
    SessionOptions,
    Terminal,
    TerminalSession,
    Text,
    detect_terminal_capabilities,
)


def main() raises:
    var capabilities = detect_terminal_capabilities()
    var session = TerminalSession(options=SessionOptions())
    var terminal = Terminal(AnsiBackend.from_terminal(capabilities=capabilities))
    var reactor = PosixReactor()
    var parser = InputParser()
    var running = True
    while running:
        var frame = terminal.begin_frame()
        frame.render_widget(
            Paragraph(Text.from_line(Line.from_text("hello world - press any key"))),
            frame.area(),
        )
        _ = terminal.finish_frame(frame^)
        var poll = reactor.wait(250)
        if poll.input_ready:
            for event in reactor.read_events(parser):
                if event.isa[KeyEvent]():
                    running = False
    session.close()
