"""Block, paragraph, and clearing widgets."""

from std.collections import List

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style
from ..core.widget import Widget
from ..text.rich import Alignment, Line, Text, render_line, render_text
from ..text.width import grapheme_width


struct Borders(Copyable, Equatable, ImplicitlyCopyable):
    """Validated set of block border edges."""

    comptime NONE = Borders(0, _validated=True)
    comptime TOP = Borders(1 << 0, _validated=True)
    comptime RIGHT = Borders(1 << 1, _validated=True)
    comptime BOTTOM = Borders(1 << 2, _validated=True)
    comptime LEFT = Borders(1 << 3, _validated=True)
    comptime ALL = Borders((1 << 4) - 1, _validated=True)

    var _bits: Int

    def __init__(out self, bits: Int, *, _validated: Bool):
        self._bits = bits

    def __init__(out self, bits: Int) raises:
        if bits < 0 or (bits & ~((1 << 4) - 1)) != 0:
            raise Error(String("block border flags must be within [0, 15]; got ", bits))
        self._bits = bits

    def __eq__(self, other: Self) -> Bool:
        return self._bits == other._bits

    def __or__(self, other: Self) -> Self:
        return Self(self._bits | other._bits, _validated=True)

    def contains(self, border: Self) -> Bool:
        return (self._bits & border._bits) == border._bits


struct Padding(Copyable):
    """Independent block padding on all four sides."""

    var left: Int
    var right: Int
    var top: Int
    var bottom: Int

    def __init__(
        out self,
        left: Int = 0,
        right: Int = 0,
        top: Int = 0,
        bottom: Int = 0,
    ):
        self.left = max(left, 0)
        self.right = max(right, 0)
        self.top = max(top, 0)
        self.bottom = max(bottom, 0)

    @staticmethod
    def symmetric(horizontal: Int = 0, vertical: Int = 0) -> Self:
        return Self(horizontal, horizontal, vertical, vertical)


struct BorderType(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal glyph set used to draw block borders."""

    comptime PLAIN = BorderType(0, _validated=True)
    comptime ROUNDED = BorderType(1, _validated=True)
    comptime DOUBLE = BorderType(2, _validated=True)
    comptime THICK = BorderType(3, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 3:
            raise Error(String("border type must be within [0, 3]; got ", value))
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct TitlePosition(Copyable, Equatable, ImplicitlyCopyable):
    """Vertical block edge used for a title."""

    comptime TOP = TitlePosition(0, _validated=True)
    comptime BOTTOM = TitlePosition(1, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 1:
            raise Error(
                String("block title position must be within [0, 1]; got ", value)
            )
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct Block(Copyable, Widget):
    """A styled region with optional borders, titles, and inner padding.

    If the positioned title and `bottom_title` share the bottom edge, the
    bottom title is rendered last and wins where they overlap.
    """

    comptime NONE = Borders.NONE
    comptime TOP = Borders.TOP
    comptime RIGHT = Borders.RIGHT
    comptime BOTTOM = Borders.BOTTOM
    comptime LEFT = Borders.LEFT
    comptime ALL = Borders.ALL
    comptime PLAIN = BorderType.PLAIN
    comptime ROUNDED = BorderType.ROUNDED
    comptime DOUBLE = BorderType.DOUBLE
    comptime THICK = BorderType.THICK
    comptime TITLE_TOP = TitlePosition.TOP
    comptime TITLE_BOTTOM = TitlePosition.BOTTOM

    var title: Line
    var bottom_title: Line
    var style: Style
    var border_style: Style
    var borders: Borders
    var padding: Padding
    var border_type: BorderType
    var title_position: TitlePosition

    def __init__(
        out self,
        title: Line = Line(),
        style: Style = Style.plain(),
        border_style: Style = Style.plain(),
        borders: Borders = Self.NONE,
        padding_x: Int = 0,
        padding_y: Int = 0,
        border_type: BorderType = BorderType.PLAIN,
        title_position: TitlePosition = TitlePosition.TOP,
        bottom_title: Line = Line(),
    ):
        self.title = title.copy()
        self.bottom_title = bottom_title.copy()
        self.style = style.copy()
        self.border_style = border_style.copy()
        self.borders = borders
        self.padding = Padding.symmetric(padding_x, padding_y)
        self.border_type = border_type
        self.title_position = title_position

    @staticmethod
    def bordered(
        title: Line = Line(),
        style: Style = Style.plain(),
        border_style: Style = Style.plain(),
        padding_x: Int = 0,
        padding_y: Int = 0,
        border_type: BorderType = BorderType.PLAIN,
        title_position: TitlePosition = TitlePosition.TOP,
        bottom_title: Line = Line(),
    ) -> Self:
        return Self(
            title,
            style,
            border_style,
            Self.ALL,
            padding_x,
            padding_y,
            border_type,
            title_position,
            bottom_title,
        )

    def with_padding(self, padding: Padding) -> Self:
        var result = self.copy()
        result.padding = padding.copy()
        return result^

    def with_border_type(self, border_type: BorderType) -> Self:
        var result = self.copy()
        result.border_type = border_type
        return result^

    def with_title_position(self, position: TitlePosition) -> Self:
        var result = self.copy()
        result.title_position = position
        return result^

    def title_bottom(self, title: Line) -> Self:
        var result = self.copy()
        result.bottom_title = title.copy()
        return result^

    def has_border(self, border: Borders) -> Bool:
        return self.borders.contains(border)

    def inner(self, area: Rect) -> Rect:
        """Return the drawable region after borders and symmetric padding."""
        var x = area.x
        var y = area.y
        var width = area.width
        var height = area.height
        if self.has_border(Self.LEFT) and width > 0:
            x += 1
            width -= 1
        if self.has_border(Self.RIGHT) and width > 0:
            width -= 1
        if self.has_border(Self.TOP) and height > 0:
            y += 1
            height -= 1
        if self.has_border(Self.BOTTOM) and height > 0:
            height -= 1
        var left_padding = min(self.padding.left, width)
        x += left_padding
        width -= left_padding
        width -= min(self.padding.right, width)
        var top_padding = min(self.padding.top, height)
        y += top_padding
        height -= top_padding
        height -= min(self.padding.bottom, height)
        return Rect(x, y, width, height)

    def _horizontal(self) -> String:
        if self.border_type == BorderType.DOUBLE:
            return "═"
        if self.border_type == BorderType.THICK:
            return "━"
        return "─"

    def _vertical(self) -> String:
        if self.border_type == BorderType.DOUBLE:
            return "║"
        if self.border_type == BorderType.THICK:
            return "┃"
        return "│"

    def _corner(self, top: Bool, left: Bool) -> String:
        if self.border_type == BorderType.ROUNDED:
            if top:
                return "╭" if left else "╮"
            return "╰" if left else "╯"
        if self.border_type == BorderType.DOUBLE:
            if top:
                return "╔" if left else "╗"
            return "╚" if left else "╝"
        if self.border_type == BorderType.THICK:
            if top:
                return "┏" if left else "┓"
            return "┗" if left else "┛"
        if top:
            return "┌" if left else "┐"
        return "└" if left else "┘"

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        buffer.fill(area, Cell(" ", style=self.style))
        var left = area.x
        var right = area.right() - 1
        var top = area.y
        var bottom = area.bottom() - 1
        var horizontal = self._horizontal()
        var vertical = self._vertical()

        if self.has_border(Self.TOP):
            for x in range(area.x, area.right()):
                _ = buffer.set_cell(
                    Point(x, top), Cell(horizontal, style=self.border_style)
                )
        if self.has_border(Self.BOTTOM):
            for x in range(area.x, area.right()):
                _ = buffer.set_cell(
                    Point(x, bottom), Cell(horizontal, style=self.border_style)
                )
        if self.has_border(Self.LEFT):
            for y in range(area.y, area.bottom()):
                _ = buffer.set_cell(
                    Point(left, y), Cell(vertical, style=self.border_style)
                )
        if self.has_border(Self.RIGHT):
            for y in range(area.y, area.bottom()):
                _ = buffer.set_cell(
                    Point(right, y), Cell(vertical, style=self.border_style)
                )

        if self.has_border(Self.TOP) and self.has_border(Self.LEFT):
            _ = buffer.set_cell(
                Point(left, top),
                Cell(self._corner(True, True), style=self.border_style),
            )
        if self.has_border(Self.TOP) and self.has_border(Self.RIGHT):
            _ = buffer.set_cell(
                Point(right, top),
                Cell(self._corner(True, False), style=self.border_style),
            )
        if self.has_border(Self.BOTTOM) and self.has_border(Self.LEFT):
            _ = buffer.set_cell(
                Point(left, bottom),
                Cell(self._corner(False, True), style=self.border_style),
            )
        if self.has_border(Self.BOTTOM) and self.has_border(Self.RIGHT):
            _ = buffer.set_cell(
                Point(right, bottom),
                Cell(self._corner(False, False), style=self.border_style),
            )

        if len(self.title.spans) > 0:
            var title_x = area.x + (1 if self.has_border(Self.LEFT) else 0)
            var title_width = area.width
            if self.has_border(Self.LEFT) and title_width > 0:
                title_width -= 1
            if self.has_border(Self.RIGHT) and title_width > 0:
                title_width -= 1
            var title_y = bottom if self.title_position == TitlePosition.BOTTOM else top
            render_line(
                self.title,
                Rect(title_x, title_y, title_width, 1),
                buffer,
            )
        if len(self.bottom_title.spans) > 0:
            var title_x = area.x + (1 if self.has_border(Self.LEFT) else 0)
            var title_width = area.width
            if self.has_border(Self.LEFT) and title_width > 0:
                title_width -= 1
            if self.has_border(Self.RIGHT) and title_width > 0:
                title_width -= 1
            render_line(
                self.bottom_title,
                Rect(title_x, bottom, title_width, 1),
                buffer,
            )


struct Clear(Copyable, Widget):
    """Replace every visible cell in an area with a plain blank."""

    def __init__(out self):
        pass

    def render(self, area: Rect, mut buffer: Buffer):
        buffer.fill(area, Cell.blank())


struct Fill(Copyable, Widget):
    """Paint every visible cell with one single-column grapheme and style."""

    var cell: Cell

    def __init__(
        out self,
        var symbol: String = " ",
        style: Style = Style.plain(),
    ) raises:
        var valid = StringSlice(symbol).count_graphemes() == 1
        if valid:
            valid = grapheme_width(symbol) == 1
        if not valid:
            raise Error(
                String(
                    (
                        "fill symbol must be exactly one grapheme occupying one"
                        ' terminal column; got "'
                    ),
                    symbol,
                    '"',
                )
            )
        self.cell = Cell(symbol^, 1, style=style)

    def render(self, area: Rect, mut buffer: Buffer):
        buffer.fill(area, self.cell)


struct Paragraph(Copyable, Widget):
    """Styled rich text with word wrapping, scrolling, and an optional block."""

    var text: Text
    var style: Style
    var _wrap: Bool
    var _word_wrap: Bool
    var _trim: Bool
    var _vertical_scroll: Int
    var _horizontal_scroll: Int
    var block: Block
    var draw_block: Bool

    def __init__(
        out self,
        text: Text,
        style: Style = Style.plain(),
        wrap: Bool = True,
        word_wrap: Bool = True,
        trim: Bool = True,
    ):
        self.text = text.copy()
        self.style = style.copy()
        self._wrap = wrap
        self._word_wrap = word_wrap
        self._trim = trim
        self._vertical_scroll = 0
        self._horizontal_scroll = 0
        self.block = Block()
        self.draw_block = False

    @staticmethod
    def with_block(
        text: Text,
        block: Block,
        style: Style = Style.plain(),
        wrap: Bool = True,
        word_wrap: Bool = True,
        trim: Bool = True,
    ) -> Self:
        var result = Self(text, style, wrap, word_wrap, trim)
        result.block = block.copy()
        result.draw_block = True
        return result^

    def wrap(self, trim: Bool = True, word: Bool = True) -> Self:
        var result = self.copy()
        result._wrap = True
        result._word_wrap = word
        result._trim = trim
        return result^

    def without_wrap(self) -> Self:
        var result = self.copy()
        result._wrap = False
        return result^

    def scroll(self, vertical: Int = 0, horizontal: Int = 0) -> Self:
        var result = self.copy()
        result._vertical_scroll = max(vertical, 0)
        result._horizontal_scroll = max(horizontal, 0)
        return result^

    def alignment(self, alignment: Alignment) -> Self:
        var result = self.copy()
        result.text.set_alignment(alignment)
        return result^

    def _visual_lines(self, width: Int) -> List[Line]:
        var lines = List[Line]()
        for index in range(len(self.text.lines)):
            var line = self.text.lines[index].copy()
            if not self._wrap:
                lines.append(line^)
                continue
            var wrapped = line.wrapped_words(
                width, self._trim
            ) if self._word_wrap else line.wrapped(width)
            for wrapped_index in range(len(wrapped)):
                lines.append(wrapped[wrapped_index].copy())
        return lines^

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        buffer.fill(area, Cell(" ", style=self.style))
        var text_area = area.copy()
        if self.draw_block:
            self.block.render(area, buffer)
            text_area = self.block.inner(area)
        if text_area.is_empty():
            return
        var lines = self._visual_lines(text_area.width)
        var visible = List[Line]()
        var start = min(self._vertical_scroll, len(lines))
        var end = min(len(lines), start + text_area.height)
        for index in range(start, end):
            visible.append(lines[index].scrolled(self._horizontal_scroll))
        render_text(
            Text(visible^),
            text_area,
            buffer,
            wrap=False,
            base_style=self.style,
        )
