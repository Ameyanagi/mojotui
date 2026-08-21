"""Styled text values and grapheme-aware rendering."""

from moji import ByteRange, byte_ranges_of_code_points
from std.collections import List, Span as StdSpan

from ..core.buffer import Buffer, BufferWrite
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Color, Style, StylePatch
from ..core.widget import Widget
from .width import grapheme_width, text_width


def _is_whitespace(value: Int) -> Bool:
    """Return whether a scalar has Unicode 17's White_Space property."""
    return (
        (value >= 0x9 and value <= 0xD)
        or value == 0x20
        or value == 0x85
        or value == 0xA0
        or value == 0x1680
        or (value >= 0x2000 and value <= 0x200A)
        or value == 0x2028
        or value == 0x2029
        or value == 0x202F
        or value == 0x205F
        or value == 0x3000
    )


struct Alignment(Copyable, Equatable, ImplicitlyCopyable):
    """Horizontal alignment for a logical or wrapped line."""

    comptime START = Alignment(0, _validated=True)
    comptime CENTER = Alignment(1, _validated=True)
    comptime END = Alignment(2, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 2:
            raise Error(String("text alignment must be within [0, 2]; got ", value))
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct _StyledGrapheme(Copyable):
    var content: String
    var style: StylePatch
    var width: Int
    var whitespace: Bool

    def __init__(out self, var content: String, style: StylePatch, width: Int):
        self.whitespace = True
        var scalar_count = 0
        for scalar in content.codepoints():
            scalar_count += 1
            if not _is_whitespace(Int(scalar.to_u32())):
                self.whitespace = False
        if scalar_count == 0:
            self.whitespace = False
        self.content = content^
        self.style = style.copy()
        self.width = width


def _line_tokens(line: Line, ambiguous_is_wide: Bool) -> List[_StyledGrapheme]:
    var tokens = List[_StyledGrapheme]()
    for span_index in range(len(line.spans)):
        var span = line.spans[span_index].copy()
        for grapheme in span.content.graphemes():
            var content = String(grapheme)
            var width = grapheme_width(grapheme, ambiguous_is_wide)
            if width > 0:
                tokens.append(_StyledGrapheme(content^, span.style, width))
    return tokens^


def _flush_wrapped_line(
    alignment: Alignment,
    mut lines: List[Line],
    mut current: List[Span],
    mut current_width: Int,
):
    lines.append(Line(current^, alignment))
    current = List[Span]()
    current_width = 0


def _append_token_range_wrapped(
    tokens: List[_StyledGrapheme],
    start: Int,
    end: Int,
    maximum_width: Int,
    alignment: Alignment,
    mut lines: List[Line],
    mut current: List[Span],
    mut current_width: Int,
):
    for index in range(start, end):
        var token = tokens[index].copy()
        if token.width > maximum_width:
            if len(current) > 0:
                _flush_wrapped_line(alignment, lines, current, current_width)
            lines.append(
                Line(
                    [Span(token.content.copy(), token.style)],
                    alignment,
                )
            )
            continue
        if current_width > 0 and current_width + token.width > maximum_width:
            _flush_wrapped_line(alignment, lines, current, current_width)
        current.append(Span(token.content.copy(), token.style))
        current_width += token.width


struct Span(Copyable, Widget):
    """One UTF-8 text run carrying compositional style intent."""

    var content: String
    var style: StylePatch

    def __init__(
        out self,
        var content: String = "",
        style: Style = Style.plain(),
    ):
        self.content = content^
        self.style = StylePatch.from_style(style)

    def __init__(out self, var content: String, style: StylePatch):
        self.content = content^
        self.style = style.copy()

    def width(self, ambiguous_is_wide: Bool = False) -> Int:
        return text_width(self.content, ambiguous_is_wide)

    @staticmethod
    def raw(var content: String) -> Self:
        return Self(content^)

    @staticmethod
    def styled(var content: String, style: Style) -> Self:
        return Self(content^, style)

    @staticmethod
    def patched(var content: String, style: StylePatch) -> Self:
        return Self(content^, style)

    def resolved_style(self, base: Style = Style.plain()) -> Style:
        return self.style.resolved(base)

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        var x = area.x
        for grapheme in self.content.graphemes():
            var grapheme_columns = grapheme_width(grapheme)
            if grapheme_columns == 0:
                continue
            if x >= area.right() or grapheme_columns > area.right() - x:
                return
            _ = buffer.set_cell(
                Point(x, area.y),
                Cell(
                    String(grapheme),
                    grapheme_columns,
                    style=self.resolved_style(),
                ),
            )
            x += grapheme_columns

    def write(
        self,
        point: Point,
        mut buffer: Buffer,
        ambiguous_is_wide: Bool = False,
    ) raises -> BufferWrite:
        """Write this span and return its explicit clipping outcome."""
        return buffer.set_string(
            point,
            self.content,
            self.resolved_style(),
            ambiguous_is_wide,
        )

    def apply_style_patch(mut self, patch: StylePatch):
        self.style = self.style.then(patch)

    def patched_style(self, patch: StylePatch) -> Self:
        var result = self.copy()
        result.apply_style_patch(patch)
        return result^

    def bold(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.BOLD))

    def italic(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.ITALIC))

    def dim(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.DIM))

    def underlined(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.UNDERLINED))

    def reversed(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.REVERSED))

    def crossed_out(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.CROSSED_OUT))

    def fg(self, color: Color) -> Self:
        return self.patched_style(StylePatch(foreground=color))

    def bg(self, color: Color) -> Self:
        return self.patched_style(StylePatch(background=color))


struct Line(Copyable, Widget):
    """A logical line composed of styled spans."""

    var spans: List[Span]
    var alignment: Alignment

    def __init__(
        out self,
        var spans: List[Span] = List[Span](),
        alignment: Alignment = Alignment.START,
    ):
        self.spans = spans^
        self.alignment = alignment

    @staticmethod
    def from_text(
        var content: String,
        style: Style = Style.plain(),
        alignment: Alignment = Alignment.START,
    ) -> Self:
        return Self([Span(content^, style)], alignment)

    @staticmethod
    def highlighted(
        var content: String,
        positions: StdSpan[Int, _],
        patch: StylePatch,
        *,
        base: StylePatch = StylePatch.plain(),
    ) raises -> Self:
        """Build a line with scalar-position matches highlighted.

        Positions are zero-based, strictly increasing Unicode scalar indices,
        matching hibana's `MatchResult.positions` contract. Invalid,
        unsorted, or out-of-range positions propagate moji's teaching errors.
        Matched byte ranges expand to whole grapheme clusters before slicing,
        so no rendered span can split a wide or multi-scalar grapheme.
        """
        var ranges = byte_ranges_of_code_points(content, positions)
        if len(ranges) == 0:
            return Self([Span(content^, base)])

        var boundaries: List[Int] = [0]
        var byte_offset = 0
        for grapheme in content.graphemes():
            byte_offset += grapheme.byte_length()
            boundaries.append(byte_offset)

        var expanded = List[ByteRange]()
        for range_index in range(len(ranges)):
            var match_range = ranges[range_index]
            var start = 0
            var end = content.byte_length()
            for boundary_index in range(len(boundaries)):
                var boundary = boundaries[boundary_index]
                if boundary <= match_range.start():
                    start = boundary
                if boundary >= match_range.end():
                    end = boundary
                    break
            if len(expanded) > 0 and start <= expanded[len(expanded) - 1].end():
                var previous = expanded[len(expanded) - 1]
                expanded[len(expanded) - 1] = ByteRange(
                    previous.start(), max(previous.end(), end)
                )
            else:
                expanded.append(ByteRange(start, end))

        var spans = List[Span]()
        var cursor = 0
        var highlighted_style = base.then(patch)
        for range_index in range(len(expanded)):
            var match_range = expanded[range_index]
            if cursor < match_range.start():
                spans.append(
                    Span(
                        String(content[byte = cursor : match_range.start()]),
                        base,
                    )
                )
            spans.append(
                Span(
                    String(content[byte = match_range.start() : match_range.end()]),
                    highlighted_style,
                )
            )
            cursor = match_range.end()
        if cursor < content.byte_length():
            spans.append(Span(String(content[byte=cursor:]), base))
        return Self(spans^)

    @staticmethod
    def raw(var content: String, alignment: Alignment = Alignment.START) -> Self:
        return Self.from_text(content^, alignment=alignment)

    @staticmethod
    def styled(
        var content: String,
        style: Style,
        alignment: Alignment = Alignment.START,
    ) -> Self:
        return Self.from_text(content^, style, alignment)

    def width(self, ambiguous_is_wide: Bool = False) -> Int:
        var total = 0
        for index in range(len(self.spans)):
            var width = self.spans[index].width(ambiguous_is_wide)
            if width > Int.MAX - total:
                return Int.MAX
            total += width
        return total

    def apply_style_patch(mut self, patch: StylePatch):
        for index in range(len(self.spans)):
            self.spans[index].apply_style_patch(patch)

    def append(mut self, span: Span):
        self.spans.append(span.copy())

    def set_alignment(mut self, alignment: Alignment):
        self.alignment = alignment

    def aligned(self, alignment: Alignment) -> Self:
        var result = self.copy()
        result.set_alignment(alignment)
        return result^

    def write(
        self,
        point: Point,
        mut buffer: Buffer,
        ambiguous_is_wide: Bool = False,
    ) raises -> BufferWrite:
        """Write spans in order and stop at the first clipped grapheme."""
        var end = point.copy()
        var graphemes_written = 0
        var columns_written = 0
        for index in range(len(self.spans)):
            var outcome = self.spans[index].write(end, buffer, ambiguous_is_wide)
            end = outcome.end.copy()
            graphemes_written += outcome.graphemes_written
            columns_written += outcome.columns_written
            if outcome.truncated:
                return BufferWrite(
                    end,
                    graphemes_written,
                    columns_written,
                    True,
                )
        return BufferWrite(
            end,
            graphemes_written,
            columns_written,
            False,
        )

    def render(self, area: Rect, mut buffer: Buffer):
        render_line(self, area, buffer)

    def patched_style(self, patch: StylePatch) -> Self:
        var result = self.copy()
        result.apply_style_patch(patch)
        return result^

    def bold(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.BOLD))

    def italic(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.ITALIC))

    def dim(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.DIM))

    def underlined(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.UNDERLINED))

    def reversed(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.REVERSED))

    def crossed_out(self) -> Self:
        return self.patched_style(StylePatch(add_modifiers=Style.CROSSED_OUT))

    def fg(self, color: Color) -> Self:
        return self.patched_style(StylePatch(foreground=color))

    def bg(self, color: Color) -> Self:
        return self.patched_style(StylePatch(background=color))

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
                    lines.append(
                        Line(
                            [Span(String(grapheme), span.style)],
                            self.alignment,
                        )
                    )
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

    def wrapped_words(
        self,
        maximum_width: Int,
        trim: Bool = True,
        ambiguous_is_wide: Bool = False,
    ) -> List[Line]:
        """Wrap at word boundaries while retaining graphemes and span styles."""
        var safe_width = max(maximum_width, 0)
        var lines = List[Line]()
        if safe_width == 0:
            lines.append(Line(alignment=self.alignment))
            return lines^

        var tokens = _line_tokens(self, ambiguous_is_wide)
        var current = List[Span]()
        var current_width = 0
        var pending_start = 0
        var pending_end = 0
        var pending_width = 0
        var index = 0
        while index < len(tokens):
            if tokens[index].whitespace:
                pending_start = index
                pending_width = 0
                while index < len(tokens) and tokens[index].whitespace:
                    pending_width += tokens[index].width
                    index += 1
                pending_end = index
                continue

            var word_start = index
            var word_width = 0
            while index < len(tokens) and not tokens[index].whitespace:
                word_width += tokens[index].width
                index += 1

            if (
                len(current) > 0
                and current_width + pending_width + word_width > safe_width
            ):
                _flush_wrapped_line(self.alignment, lines, current, current_width)

            if not (len(current) == 0 and trim) and pending_width > 0:
                _append_token_range_wrapped(
                    tokens,
                    pending_start,
                    pending_end,
                    safe_width,
                    self.alignment,
                    lines,
                    current,
                    current_width,
                )
            pending_width = 0
            _append_token_range_wrapped(
                tokens,
                word_start,
                index,
                safe_width,
                self.alignment,
                lines,
                current,
                current_width,
            )

        if pending_width > 0 and not trim:
            _append_token_range_wrapped(
                tokens,
                pending_start,
                pending_end,
                safe_width,
                self.alignment,
                lines,
                current,
                current_width,
            )
        if len(current) > 0 or len(lines) == 0:
            lines.append(Line(current^, self.alignment))
        return lines^

    def scrolled(self, columns: Int, ambiguous_is_wide: Bool = False) -> Self:
        """Drop complete graphemes before a horizontal display-column offset."""
        var skip = max(columns, 0)
        if skip == 0:
            return self.copy()
        var tokens = _line_tokens(self, ambiguous_is_wide)
        var spans = List[Span]()
        var consumed = 0
        for index in range(len(tokens)):
            var token = tokens[index].copy()
            if consumed < skip:
                consumed += token.width
                continue
            spans.append(Span(token.content.copy(), token.style))
        return Self(spans^, Alignment.START)


struct Text(Copyable, Widget):
    """A sequence of independently aligned logical lines."""

    var lines: List[Line]

    def __init__(out self, var lines: List[Line] = List[Line]()):
        self.lines = lines^

    @staticmethod
    def from_line(line: Line) -> Self:
        return Self([line.copy()])

    @staticmethod
    def from_text(
        var content: String,
        style: Style = Style.plain(),
        alignment: Alignment = Alignment.START,
    ) -> Self:
        """Create independently styled logical lines split at newlines."""
        var lines = List[Line]()
        var parts = StringSlice(content).split("\n")
        for index in range(len(parts)):
            lines.append(Line.from_text(String(parts[index]), style, alignment))
        return Self(lines^)

    @staticmethod
    def raw(var content: String) -> Self:
        return Self.from_text(content^)

    @staticmethod
    def styled(var content: String, style: Style) -> Self:
        return Self.from_text(content^, style)

    def height(self) -> Int:
        return len(self.lines)

    def width(self, ambiguous_is_wide: Bool = False) -> Int:
        var maximum = 0
        for index in range(len(self.lines)):
            maximum = max(maximum, self.lines[index].width(ambiguous_is_wide))
        return maximum

    def append(mut self, line: Line):
        self.lines.append(line.copy())

    def set_alignment(mut self, alignment: Alignment):
        for index in range(len(self.lines)):
            self.lines[index].set_alignment(alignment)

    def aligned(self, alignment: Alignment) -> Self:
        var result = self.copy()
        result.set_alignment(alignment)
        return result^

    def apply_style_patch(mut self, patch: StylePatch):
        for index in range(len(self.lines)):
            self.lines[index].apply_style_patch(patch)

    def patched_style(self, patch: StylePatch) -> Self:
        var result = self.copy()
        result.apply_style_patch(patch)
        return result^

    def render(self, area: Rect, mut buffer: Buffer):
        render_text(self, area, buffer, wrap=False)


def render_line(
    line: Line,
    area: Rect,
    mut buffer: Buffer,
    ambiguous_is_wide: Bool = False,
    base_style: Style = Style.plain(),
    style_patch: StylePatch = StylePatch.plain(),
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
        var resolved_style = base_style.patched(span.style.then(style_patch))
        for grapheme in span.content.graphemes():
            var grapheme_columns = grapheme_width(grapheme, ambiguous_is_wide)
            if grapheme_columns == 0:
                continue
            if x >= right or grapheme_columns > right - x:
                return
            _ = buffer.set_cell(
                Point(x, area.y),
                Cell(String(grapheme), grapheme_columns, style=resolved_style),
            )
            x += grapheme_columns


def render_text(
    text: Text,
    area: Rect,
    mut buffer: Buffer,
    wrap: Bool = True,
    ambiguous_is_wide: Bool = False,
    base_style: Style = Style.plain(),
    style_patch: StylePatch = StylePatch.plain(),
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
                    base_style,
                    style_patch,
                )
                row += 1
        else:
            render_line(
                line,
                Rect(area.x, row, area.width, 1),
                buffer,
                ambiguous_is_wide,
                base_style,
                style_patch,
            )
            row += 1
