from std.testing import TestSuite, assert_equal, assert_true

from examples.dashboard import DashboardModel, advance_dashboard, render_dashboard
from mojotui import (
    Buffer,
    Color,
    ColorProfile,
    Rect,
    TerminalAppearance,
    TerminalCapabilities,
)


def row(buffer: Buffer, y: Int) raises -> String:
    var result = String()
    for x in range(buffer.area.x, buffer.area.right()):
        var cell = buffer.cell({x, y})
        result += "" if cell.continuation else cell.symbol
    return result^


def test_dashboard_composes_widgets_in_one_deterministic_frame() raises:
    var model = DashboardModel()
    var buffer = Buffer(Rect(0, 0, 72, 22))
    var area = buffer.area.copy()
    render_dashboard(model, area, buffer)
    assert_true(row(buffer, 0).startswith("┌Mojotui dashboard"))
    assert_true("Overview" in row(buffer, 1))
    assert_true(row(buffer, 3).startswith("┌ CPU "))
    assert_true(row(buffer, 9).startswith("┌ Processes "))
    assert_true("CPU trend" in row(buffer, 9))
    assert_true("Activity" in row(buffer, 17))
    assert_true("q quit" in row(buffer, 21))


def test_dashboard_timer_update_is_bounded() raises:
    var model = DashboardModel()
    var initial = len(model.cpu_history)
    advance_dashboard(model)
    assert_equal(model.tick, 1)
    assert_equal(len(model.cpu_history), initial + 1)
    for _ in range(80):
        advance_dashboard(model)
    assert_equal(len(model.cpu_history), 64)


def test_dashboard_small_viewport_has_resize_message() raises:
    var model = DashboardModel()
    var buffer = Buffer(Rect(0, 0, 32, 6))
    var area = buffer.area.copy()
    render_dashboard(model, area, buffer)
    assert_true("Resize" in row(buffer, 1))


def test_dashboard_theme_resolves_once_for_terminal_capabilities() raises:
    var ansi16_light = DashboardModel(
        TerminalCapabilities(ColorProfile.ANSI16, TerminalAppearance.LIGHT)
    )
    assert_true(ansi16_light.accent.kind == Color.INDEXED)
    assert_true(ansi16_light.accent.index() <= 15)

    var truecolor_dark = DashboardModel(
        TerminalCapabilities(ColorProfile.TRUE_COLOR, TerminalAppearance.DARK)
    )
    assert_true(truecolor_dark.accent.equals(Color.rgb(80, 200, 255)))
    assert_true(truecolor_dark.warning.equals(Color.rgb(255, 190, 70)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
