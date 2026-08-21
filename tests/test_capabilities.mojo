from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from mojotui import (
    AdaptiveColor,
    Color,
    ColorProfile,
    ProfiledColor,
    TerminalAppearance,
    TerminalCapabilities,
    terminal_capabilities_from_environment,
)


def test_capability_discriminants_are_validated() raises:
    with assert_raises(contains="invalid terminal color profile"):
        _ = ColorProfile(4)
    with assert_raises(contains="invalid terminal appearance"):
        _ = TerminalAppearance(3)


def test_profiled_color_rejects_values_unsupported_by_each_profile() raises:
    with assert_raises(contains="monochrome fallback"):
        _ = ProfiledColor(
            Color.indexed(7),
            Color.indexed(7),
            Color.indexed(7),
            Color.rgb(255, 255, 255),
        )
    with assert_raises(contains="ANSI-16 fallback"):
        _ = ProfiledColor(
            Color.default(),
            Color.indexed(16),
            Color.indexed(16),
            Color.rgb(0, 95, 0),
        )
    with assert_raises(contains="ANSI-256 fallback"):
        _ = ProfiledColor(
            Color.default(),
            Color.indexed(2),
            Color.rgb(0, 95, 0),
            Color.rgb(0, 95, 0),
        )


def test_rgb_profiled_color_has_deterministic_palette_fallbacks() raises:
    var red = ProfiledColor.from_rgb(255, 0, 0)
    assert_true(red.resolve(ColorProfile.MONOCHROME).equals(Color.default()))
    assert_true(red.resolve(ColorProfile.ANSI16).equals(Color.indexed(9)))
    assert_true(red.resolve(ColorProfile.ANSI256).equals(Color.indexed(196)))
    assert_true(red.resolve(ColorProfile.TRUE_COLOR).equals(Color.rgb(255, 0, 0)))


def test_adaptive_color_resolves_light_dark_and_unknown_explicitly() raises:
    var light = ProfiledColor.from_rgb(80, 40, 160)
    var dark = ProfiledColor.from_rgb(190, 150, 255)
    var unknown = ProfiledColor.from_rgb(0, 200, 120)
    var accent = AdaptiveColor(light, dark, unknown)

    assert_true(
        accent.resolve(
            TerminalCapabilities(ColorProfile.TRUE_COLOR, TerminalAppearance.LIGHT)
        ).equals(Color.rgb(80, 40, 160))
    )
    assert_true(
        accent.resolve(
            TerminalCapabilities(ColorProfile.TRUE_COLOR, TerminalAppearance.DARK)
        ).equals(Color.rgb(190, 150, 255))
    )
    assert_true(
        accent.resolve(
            TerminalCapabilities(ColorProfile.TRUE_COLOR, TerminalAppearance.UNKNOWN)
        ).equals(Color.rgb(0, 200, 120))
    )


def test_two_color_adaptive_constructor_uses_dark_for_unknown() raises:
    var light = ProfiledColor.from_rgb(10, 20, 30)
    var dark = ProfiledColor.from_rgb(40, 50, 60)
    var accent = AdaptiveColor(light, dark)
    assert_true(
        accent.resolve(
            TerminalCapabilities(ColorProfile.TRUE_COLOR, TerminalAppearance.UNKNOWN)
        ).equals(Color.rgb(40, 50, 60))
    )


def test_environment_profile_detection_is_conservative_and_no_color_wins() raises:
    var no_color = terminal_capabilities_from_environment(
        no_color=True,
        colorterm="truecolor",
        term="xterm-256color",
        colorfgbg="15;0",
    )
    assert_true(no_color.profile == ColorProfile.MONOCHROME)
    assert_true(no_color.appearance == TerminalAppearance.DARK)

    var truecolor = terminal_capabilities_from_environment(
        colorterm="TRUECOLOR", term="xterm-256color"
    )
    assert_true(truecolor.profile == ColorProfile.TRUE_COLOR)

    var direct = terminal_capabilities_from_environment(term="xterm-direct")
    assert_true(direct.profile == ColorProfile.TRUE_COLOR)

    var indexed = terminal_capabilities_from_environment(term="screen-256color")
    assert_true(indexed.profile == ColorProfile.ANSI256)

    var dumb = terminal_capabilities_from_environment(term="dumb")
    assert_true(dumb.profile == ColorProfile.MONOCHROME)

    var fallback = terminal_capabilities_from_environment()
    assert_true(fallback.profile == ColorProfile.ANSI16)
    assert_true(fallback.appearance == TerminalAppearance.DARK)


def test_environment_appearance_uses_last_colorfgbg_field() raises:
    var light = terminal_capabilities_from_environment(colorfgbg="0;15")
    assert_true(light.appearance == TerminalAppearance.LIGHT)

    var dark = terminal_capabilities_from_environment(colorfgbg="15;0")
    assert_true(dark.appearance == TerminalAppearance.DARK)

    var bright_black = terminal_capabilities_from_environment(colorfgbg="7;8")
    assert_true(bright_black.appearance == TerminalAppearance.DARK)

    var malformed = terminal_capabilities_from_environment(colorfgbg="white;blue")
    assert_true(malformed.appearance == TerminalAppearance.DARK)
    assert_false(malformed.equals(light))


def test_environment_detects_synchronized_output_implementors() raises:
    assert_true(
        terminal_capabilities_from_environment(
            term_program="WezTerm"
        ).synchronized_output
    )
    assert_true(
        terminal_capabilities_from_environment(
            term_program="iTerm.app"
        ).synchronized_output
    )
    assert_true(
        terminal_capabilities_from_environment(
            term_program="ghostty"
        ).synchronized_output
    )
    assert_true(
        terminal_capabilities_from_environment(term_program="rio").synchronized_output
    )
    assert_true(
        terminal_capabilities_from_environment(term="XTERM-KITTY").synchronized_output
    )
    assert_true(
        terminal_capabilities_from_environment(
            term="alacritty-direct"
        ).synchronized_output
    )
    assert_true(
        terminal_capabilities_from_environment(term="foot-extra").synchronized_output
    )
    assert_true(
        terminal_capabilities_from_environment(
            term="contour-256color"
        ).synchronized_output
    )


def test_environment_synchronized_output_detection_is_conservative() raises:
    assert_false(terminal_capabilities_from_environment().synchronized_output)
    assert_false(
        terminal_capabilities_from_environment(
            term_program="wezterm",
            term="xterm-256color",
        ).synchronized_output
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
