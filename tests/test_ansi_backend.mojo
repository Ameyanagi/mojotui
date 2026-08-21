from std.collections import List
from std.os import Pipe
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import (
    AnsiBackend,
    Backend,
    Cell,
    ColorProfile,
    FramePatch,
    HeadlessBackend,
    InlineBackend,
    Rect,
    Size,
    Terminal,
    TerminalAppearance,
    TerminalCapabilities,
)


struct DefaultCapabilityBackend(Backend):
    var area: Rect

    def __init__(out self, area: Rect):
        self.area = area.copy()

    def viewport(mut self) raises -> Rect:
        return self.area.copy()

    def present(mut self, patch: FramePatch) raises:
        pass

    def clear(mut self) raises:
        pass

    def flush(mut self) raises:
        pass


def read_exact(mut pipe: Pipe, count: Int) raises -> String:
    var storage = List[UInt8](length=count, fill=0)
    var read = pipe.read_bytes(storage)
    assert_equal(read, count)
    return String(from_utf8_lossy=storage)


def test_ansi_backend_clears_once_then_emits_diffs() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var terminal = Terminal(
        AnsiBackend(
            Rect(0, 0, 2, 1),
            output_descriptor,
            capabilities=TerminalCapabilities.conservative(),
        )
    )

    var first = terminal.begin_frame()
    _ = first.buffer.set_cell({0, 0}, Cell("a"))
    _ = terminal.finish_frame(first^)
    var first_output = read_exact(pipe, 18)
    assert_equal(first_output, "\x1b[2J\x1b[H\x1b[0m\x1b[1;1Ha")
    assert_false(terminal.backend.first_frame)

    var second = terminal.begin_frame()
    _ = second.buffer.set_cell({0, 0}, Cell("a"))
    _ = second.buffer.set_cell({1, 0}, Cell("b"))
    _ = terminal.finish_frame(second^)
    assert_equal(read_exact(pipe, 11), "\x1b[0m\x1b[1;2Hb")
    assert_equal(pipe.fd_out.value().value, output_descriptor)


def test_ansi_backend_writes_initial_clear_for_blank_frame() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var terminal = Terminal(
        AnsiBackend(
            Rect(0, 0, 1, 1),
            output_descriptor,
            capabilities=TerminalCapabilities.conservative(),
        )
    )
    var frame = terminal.begin_frame()
    _ = terminal.finish_frame(frame^)
    assert_equal(read_exact(pipe, 7), "\x1b[2J\x1b[H")
    assert_true(terminal.last_frame().cell({0, 0}).equals(Cell.blank()))
    assert_equal(pipe.fd_out.value().value, output_descriptor)


def test_ansi_backend_brackets_synchronized_presentations() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var capabilities = TerminalCapabilities(synchronized_output=True)
    var terminal = Terminal(
        AnsiBackend(
            Rect(0, 0, 1, 1),
            output_descriptor,
            capabilities=capabilities,
        )
    )
    var frame = terminal.begin_frame()
    _ = frame.buffer.set_cell({0, 0}, Cell("a"))
    _ = terminal.finish_frame(frame^)
    assert_equal(
        read_exact(pipe, 34),
        "\x1b[?2026h\x1b[2J\x1b[H\x1b[0m\x1b[1;1Ha\x1b[?2026l",
    )


def test_ansi_backend_omits_synchronized_output_by_default() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var capabilities = TerminalCapabilities()
    var terminal = Terminal(
        AnsiBackend(
            Rect(0, 0, 1, 1),
            output_descriptor,
            capabilities=capabilities,
        )
    )
    var frame = terminal.begin_frame()
    _ = frame.buffer.set_cell({0, 0}, Cell("a"))
    _ = terminal.finish_frame(frame^)
    assert_equal(read_exact(pipe, 18), "\x1b[2J\x1b[H\x1b[0m\x1b[1;1Ha")


def test_ansi_backend_applies_visible_and_hidden_cursor_intent() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var terminal = Terminal(
        AnsiBackend(
            Rect(0, 0, 2, 1),
            output_descriptor,
            capabilities=TerminalCapabilities.conservative(),
        )
    )
    var visible = terminal.begin_frame()
    visible.set_cursor_position({1, 0})
    var completed = terminal.finish_frame(visible^)
    assert_true(completed.cursor)
    assert_equal(read_exact(pipe, 19), "\x1b[2J\x1b[H\x1b[1;2H\x1b[?25h")

    var hidden = terminal.begin_frame()
    completed = terminal.finish_frame(hidden^)
    assert_false(completed.cursor)
    assert_equal(read_exact(pipe, 6), "\x1b[?25l")


def test_inline_backend_reserves_once_and_emits_relative_diffs() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var terminal = Terminal(
        InlineBackend(
            2,
            1,
            output_descriptor,
            capabilities=TerminalCapabilities.conservative(),
        )
    )
    var first = terminal.begin_frame()
    _ = first.buffer.set_cell({0, 0}, Cell("a"))
    _ = terminal.finish_frame(first^)
    assert_equal(
        read_exact(pipe, 29),
        "\x1b[2K\r\n\x1b[s\x1b[u\x1b[1A\r\x1b[0ma\x1b[u\x1b[0m",
    )
    var second = terminal.begin_frame()
    _ = second.buffer.set_cell({0, 0}, Cell("a"))
    _ = second.buffer.set_cell({1, 0}, Cell("b"))
    _ = terminal.finish_frame(second^)
    assert_equal(
        read_exact(pipe, 27),
        "\x1b[s\x1b[u\x1b[1A\r\x1b[1C\x1b[0mb\x1b[u\x1b[0m",
    )
    assert_false(terminal.backend.first_frame)


def test_inline_backend_returns_to_anchor_when_hiding_cursor() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var terminal = Terminal(
        InlineBackend(
            2,
            1,
            output_descriptor,
            capabilities=TerminalCapabilities.conservative(),
        )
    )
    var visible = terminal.begin_frame()
    visible.set_cursor_position({1, 0})
    _ = terminal.finish_frame(visible^)
    assert_equal(
        read_exact(pipe, 21),
        "\x1b[2K\r\n\x1b[1A\r\x1b[1C\x1b[?25h",
    )

    var hidden = terminal.begin_frame()
    _ = terminal.finish_frame(hidden^)
    assert_equal(read_exact(pipe, 11), "\x1b[?25l\x1b[1B\r")


def test_inline_backend_follows_width_but_keeps_fixed_height_on_resize() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var terminal = Terminal(
        InlineBackend(
            2,
            3,
            output_descriptor,
            capabilities=TerminalCapabilities.conservative(),
        )
    )
    terminal.handle_resize(Size(7, 40))
    assert_true(terminal.viewport().equals(Rect(0, 0, 7, 3)))

    var frame = terminal.begin_frame()
    assert_true(frame.area().equals(Rect(0, 0, 7, 3)))


def test_inline_resize_retains_cursor_anchor_state() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var terminal = Terminal(
        InlineBackend(
            2,
            1,
            output_descriptor,
            capabilities=TerminalCapabilities.conservative(),
        )
    )
    var visible = terminal.begin_frame()
    visible.set_cursor_position({1, 0})
    _ = terminal.finish_frame(visible^)
    _ = read_exact(pipe, 21)

    terminal.handle_resize(Size(4, 20))
    assert_true(terminal.backend.cursor)
    assert_true(terminal.viewport().equals(Rect(0, 0, 4, 1)))


def test_backends_expose_explicit_terminal_capabilities() raises:
    var capabilities = TerminalCapabilities(
        ColorProfile.ANSI256, TerminalAppearance.LIGHT
    )
    var headless = Terminal(
        HeadlessBackend(Rect(0, 0, 1, 1), capabilities=capabilities)
    )
    assert_true(headless.capabilities().equals(capabilities))

    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var ansi = Terminal(
        AnsiBackend(
            Rect(0, 0, 1, 1),
            output_descriptor,
            capabilities=capabilities,
        )
    )
    assert_true(ansi.capabilities().equals(capabilities))

    var inline = Terminal(
        InlineBackend(
            1,
            1,
            output_descriptor,
            capabilities=capabilities,
        )
    )
    assert_true(inline.capabilities().equals(capabilities))


def test_headless_capabilities_have_a_stable_conservative_default() raises:
    var terminal = Terminal(HeadlessBackend(Rect(0, 0, 1, 1)))
    assert_true(terminal.capabilities().equals(TerminalCapabilities.conservative()))
    assert_false(terminal.capabilities().synchronized_output)


def test_custom_backend_inherits_conservative_capabilities() raises:
    var terminal = Terminal(DefaultCapabilityBackend(Rect(0, 0, 1, 1)))
    assert_true(terminal.capabilities().equals(TerminalCapabilities.conservative()))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
