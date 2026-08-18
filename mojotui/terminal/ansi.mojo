"""Pure ANSI encoding for changed terminal cells."""

from ..core.buffer import Buffer
from ..core.geometry import Point
from ..core.style import Color, Style


def _append_cursor(mut output: String, row: Int, column: Int):
    output += "\x1b["
    output += String(row)
    output += ";"
    output += String(column)
    output += "H"


def _append_color(mut output: String, color: Color, foreground: Bool):
    if color.kind == Color.DEFAULT:
        return
    output += "\x1b["
    output += "38" if foreground else "48"
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


def _append_modifier(mut output: String, style: Style, modifier: Int, code: String):
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
    _append_color(output, style.foreground, True)
    _append_color(output, style.background, False)


def encode_ansi_diff(before: Buffer, after: Buffer) raises -> String:
    """Encode the minimal changed cell runs using absolute ANSI cursor moves.

    Coordinates are relative to the buffer area. The encoder starts and ends
    in the default style, making each result independent from previous calls.
    """
    if not before.area.equals(after.area):
        raise Error("ANSI diff buffers must have equal areas")

    var output = String()
    var emitted = False
    var cursor_x = -1
    var cursor_y = -1
    var active_style = Style.plain()

    for y in range(after.area.y, after.area.bottom()):
        for x in range(after.area.x, after.area.right()):
            var point = Point(x, y)
            var previous = before.cell(point)
            var current = after.cell(point)
            if previous.equals(current) or current.continuation:
                continue

            if not emitted:
                output += "\x1b[0m"
                emitted = True

            if cursor_x != x or cursor_y != y:
                _append_cursor(
                    output,
                    y - after.area.y + 1,
                    x - after.area.x + 1,
                )

            if not active_style.equals(current.style):
                _append_style(output, current.style)
                active_style = current.style.copy()

            output += current.symbol
            cursor_x = x + current.width
            cursor_y = y

    if emitted and not active_style.equals(Style.plain()):
        output += "\x1b[0m"
    return output^


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


def encode_ansi_inline_diff(before: Buffer, after: Buffer) raises -> String:
    """Encode changes relative to a cursor directly below a fixed viewport."""
    if not before.area.equals(after.area):
        raise Error("ANSI inline diff buffers must have equal areas")

    var output = String()
    var emitted = False
    for y in range(after.area.y, after.area.bottom()):
        for x in range(after.area.x, after.area.right()):
            var point = Point(x, y)
            var previous = before.cell(point)
            var current = after.cell(point)
            if previous.equals(current) or current.continuation:
                continue
            if not emitted:
                output += "\x1b[s"
                emitted = True
            _append_relative_position(
                output,
                after.area.height,
                y - after.area.y,
                x - after.area.x,
            )
            _append_style(output, current.style)
            output += current.symbol

    if emitted:
        output += "\x1b[u\x1b[0m"
    return output^


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
