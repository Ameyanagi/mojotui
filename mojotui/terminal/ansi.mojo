"""Pure ANSI encoding for changed terminal cells."""

from ..core.buffer import Buffer
from ..core.style import Color, ModifierSet, Style
from .frame import FramePatch, diff_frame


def _append_cursor(mut output: String, row: Int, column: Int):
    output += "\x1b["
    output += String(row)
    output += ";"
    output += String(column)
    output += "H"


def _append_color(mut output: String, color: Color, code: Int):
    if color.kind == Color.DEFAULT:
        return
    if color.kind == Color.INDEXED and color.index() < 16 and code != 58:
        var index = color.index()
        var basic_code: Int
        if code == 38:
            basic_code = 30 + index if index < 8 else 90 + index - 8
        else:
            basic_code = 40 + index if index < 8 else 100 + index - 8
        output += "\x1b["
        output += String(basic_code)
        output += "m"
        return
    output += "\x1b["
    output += String(code)
    if color.kind == Color.INDEXED:
        output += ";5;"
        output += String(color.index())
    else:
        output += ";2;"
        output += String(color.red)
        output += ";"
        output += String(color.green)
        output += ";"
        output += String(color.blue)
    output += "m"


def _append_modifier(
    mut output: String,
    style: Style,
    modifier: ModifierSet,
    code: String,
):
    if style.has(modifier):
        output += "\x1b["
        output += code
        output += "m"


def _append_style(mut output: String, style: Style):
    output += "\x1b[0m"
    _append_modifier(output, style, Style.BOLD, "1")
    _append_modifier(output, style, Style.DIM, "2")
    _append_modifier(output, style, Style.ITALIC, "3")
    _append_modifier(output, style, Style.UNDERLINED, "4")
    _append_modifier(output, style, Style.SLOW_BLINK, "5")
    _append_modifier(output, style, Style.REVERSED, "7")
    _append_modifier(output, style, Style.HIDDEN, "8")
    _append_modifier(output, style, Style.CROSSED_OUT, "9")
    _append_color(output, style.foreground, 38)
    _append_color(output, style.background, 48)
    _append_color(output, style.underline_color, 58)


def _encode_ansi_patch(patch: FramePatch) -> String:
    """Encode one terminal-owned changed-cell patch with absolute positions."""
    var output = String()
    var emitted = False
    var cursor_x = -1
    var cursor_y = -1
    var active_style = Style.plain()

    for index in range(len(patch.changes)):
        var x = patch.changes[index].point.x
        var y = patch.changes[index].point.y

        if not emitted:
            output += "\x1b[0m"
            emitted = True

        if cursor_x != x or cursor_y != y:
            _append_cursor(
                output,
                y - patch.area.y + 1,
                x - patch.area.x + 1,
            )

        if not active_style.equals(patch.changes[index].cell.style):
            _append_style(output, patch.changes[index].cell.style)
            active_style = patch.changes[index].cell.style.copy()

        output += patch.changes[index].cell.symbol
        cursor_x = x + patch.changes[index].cell.width
        cursor_y = y

    if emitted and not active_style.equals(Style.plain()):
        output += "\x1b[0m"
    return output^


def encode_ansi_diff(before: Buffer, after: Buffer) raises -> String:
    """Encode changed cells using absolute ANSI cursor moves.

    This compatibility helper delegates diff collection to the same
    terminal-owned patch representation used by `Terminal`.
    """
    return _encode_ansi_patch(diff_frame(before, after))


def inline_reserve_sequence(height: Int) -> String:
    """Reserve and clear a fixed-height region, leaving the cursor below it."""
    var output = String()
    for _ in range(max(height, 0)):
        output += "\x1b[2K\r\n"
    return output^


def _append_relative_position(
    mut output: String,
    height: Int,
    row: Int,
    column: Int,
):
    # Each changed cell begins from the saved cursor immediately below the
    # viewport. Relative positioning avoids assuming an absolute screen row.
    output += "\x1b[u"
    var upward = height - row
    if upward > 0:
        output += "\x1b["
        output += String(upward)
        output += "A"
    output += "\r"
    if column > 0:
        output += "\x1b["
        output += String(column)
        output += "C"


def _encode_ansi_inline_patch(patch: FramePatch) -> String:
    """Encode a changed-cell patch relative to a fixed viewport anchor."""
    var output = String()
    var emitted = False
    for index in range(len(patch.changes)):
        if not emitted:
            output += "\x1b[s"
            emitted = True
        _append_relative_position(
            output,
            patch.area.height,
            patch.changes[index].point.y - patch.area.y,
            patch.changes[index].point.x - patch.area.x,
        )
        _append_style(output, patch.changes[index].cell.style)
        output += patch.changes[index].cell.symbol

    if emitted:
        output += "\x1b[u\x1b[0m"
    return output^


def encode_ansi_inline_diff(before: Buffer, after: Buffer) raises -> String:
    """Encode changes relative to a cursor directly below a fixed viewport."""
    return _encode_ansi_inline_patch(diff_frame(before, after))


def inline_clear_sequence(height: Int) -> String:
    """Clear a reserved inline region while preserving its bottom anchor."""
    var bounded_height = max(height, 0)
    if bounded_height == 0:
        return String()
    var output = String("\x1b[s")
    for row in range(bounded_height):
        output += "\x1b[u\x1b["
        output += String(bounded_height - row)
        output += "A\r\x1b[2K"
    output += "\x1b[u"
    return output^
