"""Conservative terminal capability detection outside the render path."""

from std.os.env import getenv

from ..core.capabilities import (
    ColorProfile,
    TerminalAppearance,
    TerminalCapabilities,
)


def _background_index(colorfgbg: String) -> Int:
    var fields = colorfgbg.split(";")
    if len(fields) == 0:
        return -1
    try:
        return Int(String(fields[len(fields) - 1]))
    except:
        return -1


def terminal_capabilities_from_environment(
    *,
    no_color: Bool = False,
    colorterm: String = "",
    term: String = "",
    colorfgbg: String = "",
    term_program: String = "",
) -> TerminalCapabilities:
    """Resolve copied environment hints into one deterministic capability.

    This pure helper makes precedence and malformed-input behavior testable.
    `NO_COLOR` wins over color-profile hints. Unknown terminals use ANSI-16;
    missing or malformed background hints use a dark appearance.
    """
    var normalized_colorterm = colorterm.lower()
    var normalized_term = term.lower()
    var profile = ColorProfile.ANSI16
    if no_color or normalized_term == "dumb":
        profile = ColorProfile.MONOCHROME
    elif "truecolor" in normalized_colorterm or "24bit" in normalized_colorterm:
        profile = ColorProfile.TRUE_COLOR
    elif "direct" in normalized_term:
        profile = ColorProfile.TRUE_COLOR
    elif "256color" in normalized_term:
        profile = ColorProfile.ANSI256

    var appearance = TerminalAppearance.DARK
    var background = _background_index(colorfgbg)
    if background == 7 or (background >= 9 and background <= 15):
        appearance = TerminalAppearance.LIGHT
    var synchronized_output = (
        term_program == "WezTerm"
        or term_program == "iTerm.app"
        or term_program == "ghostty"
        or term_program == "rio"
        or "kitty" in normalized_term
        or "alacritty" in normalized_term
        or "foot" in normalized_term
        or "contour" in normalized_term
    )
    return TerminalCapabilities(profile, appearance, synchronized_output)


def detect_terminal_capabilities() -> TerminalCapabilities:
    """Read standard environment hints once, outside deterministic rendering."""
    var missing = "__MOJOTUI_ENVIRONMENT_VALUE_IS_MISSING__"
    var no_color = getenv("NO_COLOR", missing) != missing
    return terminal_capabilities_from_environment(
        no_color=no_color,
        colorterm=getenv("COLORTERM"),
        term=getenv("TERM"),
        colorfgbg=getenv("COLORFGBG"),
        term_program=getenv("TERM_PROGRAM"),
    )
