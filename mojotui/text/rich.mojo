"""Styled text values and grapheme-aware rendering."""

from std.collections import List

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style
from .width import grapheme_width, text_width


struct Alignment:
    """Horizontal alignment for a logical or wrapped line."""

    comptime START = 0
    comptime CENTER = 1
    comptime END = 2


struct Span(Copyable):
    """One styled run of UTF-8 text."""

    var content: String
    var style: Style

    def __init__(
        out self,
        var content: String = "",
        style: Style = Style.plain(),
    ):
        self.content = content^
        self.style = style.copy()

    def width(self, ambiguous_is_wide: Bool = False) -> Int:
        return text_width(self.content, ambiguous_is_wide)


struct Line(Copyable):
    """A logical line composed of styled spans."""

    var spans: List[Span]
    var alignment: Int

    def __init__(
        out self,
        var spans: List[Span] = List[Span](),
        alignment: Int = Alignment.START,
    ):
        self.spans = spans^
        self.alignment = (
            alignment if alignment >= Alignment.START
            and alignment <= Alignment.END else Alignment.START
        )

    @staticmethod
    def from_text(
        var content: String,
        style: Style = Style.plain(),
        alignment: Int = Alignment.START,
    ) -> Self:
        return Self([Span(content^, style)], alignment)

    def width(self, ambiguous_is_wide: Bool = False) -> Int:
        var total = 0
        for index in range(len(self.spans)):
            var width = self.spans[index].width(ambiguous_is_wide)
            if width > Int.MAX - total:
                return Int.MAX
            total += width
        return total

    def wrapped(
        self, maximum_width: Int, ambiguous_is_wide: Bool = False
    ) -> List[Line]:
        """Wrap at grapheme boundaries while preserving every span style."""
        var lines = List[Line]()
        var current = List[Span]()
        var current_width = 0
        var safe_width = max(maximum_width, 0)

        if safe_width == 0:
            lines.append(Line(alignment=self.alignment))
            return lines^

        for span_index in range(len(self.spans)):
            var span = self.spans[span_index].copy()
            for grapheme in span.content.graphemes():
                var width = grapheme_width(grapheme, ambiguous_is_wide)
                if width > safe_width:
                    if len(current) > 0:
                        lines.append(Line(current^, self.alignment))
                        current = List[Span]()
                        current_width = 0
                    continue
                if (
                    width > 0
                    and current_width > 0
                    and current_width + width > safe_width
                ):
                    lines.append(Line(current^, self.alignment))
                    current = List[Span]()
                    current_width = 0
                current.append(Span(String(grapheme), span.style))
                current_width += width

        if len(current) > 0 or len(lines) == 0:
            lines.append(Line(current^, self.alignment))
        return lines^


struct Text(Copyable):
    """A sequence of independently aligned logical lines."""

    var lines: List[Line]

    def __init__(out self, var lines: List[Line] = List[Line]()):
        self.lines = lines^

    @staticmethod
    def from_line(line: Line) -> Self:
        return Self([line.copy()])


def render_line(
    line: Line,
    area: Rect,
    mut buffer: Buffer,
    ambiguous_is_wide: Bool = False,
):
    """Render one line, clipping without splitting a wide grapheme."""
    if area.is_empty():
        return
    var width = line.width(ambiguous_is_wide)
    var offset = 0
    if width < area.width:
        if line.alignment == Alignment.CENTER:
            offset = (area.width - width) // 2
        elif line.alignment == Alignment.END:
            offset = area.width - width

    var x = area.x + offset
    var right = area.right()
    for span_index in range(len(line.spans)):
        var span = line.spans[span_index].copy()
        for grapheme in span.content.graphemes():
            var grapheme_columns = grapheme_width(grapheme, ambiguous_is_wide)
            if grapheme_columns == 0:
                continue
            if x >= right or grapheme_columns > right - x:
                return
            _ = buffer.set_cell(
                Point(x, area.y),
                Cell(String(grapheme), grapheme_columns, style=span.style),
            )
            x += grapheme_columns


def render_text(
    text: Text,
    area: Rect,
    mut buffer: Buffer,
    wrap: Bool = True,
    ambiguous_is_wide: Bool = False,
):
    """Render visible logical lines, optionally wrapping by grapheme width."""
    if area.is_empty():
        return
    var row = area.y
    for line_index in range(len(text.lines)):
        if row >= area.bottom():
            return
        var line = text.lines[line_index].copy()
        if wrap:
            var wrapped = line.wrapped(area.width, ambiguous_is_wide)
            for wrapped_index in range(len(wrapped)):
                if row >= area.bottom():
                    return
                render_line(
                    wrapped[wrapped_index],
                    Rect(area.x, row, area.width, 1),
                    buffer,
                    ambiguous_is_wide,
                )
                row += 1
        else:
            render_line(
                line,
                Rect(area.x, row, area.width, 1),
                buffer,
                ambiguous_is_wide,
            )
            row += 1
