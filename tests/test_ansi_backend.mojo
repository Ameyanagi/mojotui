from std.collections import List
from std.os import Pipe
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import AnsiBackend, Buffer, Cell, InlineBackend, Rect


def read_exact(mut pipe: Pipe, count: Int) raises -> String:
    var storage = List[UInt8](length=count, fill=0)
    var read = pipe.read_bytes(storage)
    assert_equal(read, count)
    return String(from_utf8_lossy=storage)


def test_ansi_backend_clears_once_then_emits_diffs() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var backend = AnsiBackend(Rect(0, 0, 2, 1), output_descriptor)

    var first = Buffer(Rect(0, 0, 2, 1))
    _ = first.set_cell({0, 0}, Cell("a"))
    backend.present(first)
    var first_output = read_exact(pipe, 18)
    assert_equal(first_output, "\x1b[2J\x1b[H\x1b[0m\x1b[1;1Ha")
    assert_false(backend.first_frame)

    var second = first.copy()
    _ = second.set_cell({1, 0}, Cell("b"))
    backend.present(second)
    assert_equal(read_exact(pipe, 11), "\x1b[0m\x1b[1;2Hb")
    assert_equal(pipe.fd_out.value().value, output_descriptor)


def test_ansi_backend_writes_initial_clear_for_blank_frame() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var backend = AnsiBackend(Rect(0, 0, 1, 1), output_descriptor)
    backend.present(Buffer(Rect(0, 0, 1, 1)))
    assert_equal(read_exact(pipe, 7), "\x1b[2J\x1b[H")
    assert_true(backend.current.cell({0, 0}).equals(Cell.blank()))
    assert_equal(pipe.fd_out.value().value, output_descriptor)


def test_inline_backend_reserves_once_and_emits_relative_diffs() raises:
    var pipe = Pipe()
    var output_descriptor = pipe.fd_out.value().value
    var backend = InlineBackend(2, 1, output_descriptor)
    var first = Buffer(Rect(0, 0, 2, 1))
    _ = first.set_cell({0, 0}, Cell("a"))
    backend.present(first)
    assert_equal(
        read_exact(pipe, 29),
        "\x1b[2K\r\n\x1b[s\x1b[u\x1b[1A\r\x1b[0ma\x1b[u\x1b[0m",
    )
    var second = first.copy()
    _ = second.set_cell({1, 0}, Cell("b"))
    backend.present(second)
    assert_equal(
        read_exact(pipe, 27),
        "\x1b[s\x1b[u\x1b[1A\r\x1b[1C\x1b[0mb\x1b[u\x1b[0m",
    )
    assert_false(backend.first_frame)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
