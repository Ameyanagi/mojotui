"""Block, paragraph, and clearing widgets."""

from ..core.buffer import Buffer
from ..core.cell import Cell
from ..core.geometry import Point, Rect
from ..core.style import Style
from ..core.widget import Widget
from ..text.rich import Line, Text, render_line, render_text


struct Block(Copyable, Widget):
    """A styled region with optional borders, title, and inner padding."""

    comptime NONE = 0
    comptime TOP = 1 << 0
    comptime RIGHT = 1 << 1
    comptime BOTTOM = 1 << 2
    comptime LEFT = 1 << 3
    comptime ALL = (1 << 4) - 1

    var title: Line
    var style: Style
    var border_style: Style
    var borders: Int
    var padding_x: Int
    var padding_y: Int

    def __init__(
        out self,
        title: Line = Line(),
        style: Style = Style.plain(),
        border_style: Style = Style.plain(),
        borders: Int = Self.NONE,
        padding_x: Int = 0,
        padding_y: Int = 0,
    ):
        self.title = title.copy()
        self.style = style.copy()
        self.border_style = border_style.copy()
        self.borders = borders & Self.ALL
        self.padding_x = max(padding_x, 0)
        self.padding_y = max(padding_y, 0)

    @staticmethod
    def bordered(
        title: Line = Line(),
        style: Style = Style.plain(),
        border_style: Style = Style.plain(),
        padding_x: Int = 0,
        padding_y: Int = 0,
    ) -> Self:
        return Self(
            title,
            style,
            border_style,
            Self.ALL,
            padding_x,
            padding_y,
        )

    def has_border(self, border: Int) -> Bool:
        return (self.borders & border) != 0

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
        return Rect(x, y, width, height).inset(self.padding_x, self.padding_y)

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        buffer.fill(area, Cell(" ", style=self.style))
        var left = area.x
        var right = area.right() - 1
        var top = area.y
        var bottom = area.bottom() - 1

        if self.has_border(Self.TOP):
            for x in range(area.x, area.right()):
                _ = buffer.set_cell(Point(x, top), Cell("─", style=self.border_style))
        if self.has_border(Self.BOTTOM):
            for x in range(area.x, area.right()):
                _ = buffer.set_cell(
                    Point(x, bottom), Cell("─", style=self.border_style)
                )
        if self.has_border(Self.LEFT):
            for y in range(area.y, area.bottom()):
                _ = buffer.set_cell(Point(left, y), Cell("│", style=self.border_style))
        if self.has_border(Self.RIGHT):
            for y in range(area.y, area.bottom()):
                _ = buffer.set_cell(Point(right, y), Cell("│", style=self.border_style))

        if self.has_border(Self.TOP) and self.has_border(Self.LEFT):
            _ = buffer.set_cell(Point(left, top), Cell("┌", style=self.border_style))
        if self.has_border(Self.TOP) and self.has_border(Self.RIGHT):
            _ = buffer.set_cell(Point(right, top), Cell("┐", style=self.border_style))
        if self.has_border(Self.BOTTOM) and self.has_border(Self.LEFT):
            _ = buffer.set_cell(Point(left, bottom), Cell("└", style=self.border_style))
        if self.has_border(Self.BOTTOM) and self.has_border(Self.RIGHT):
            _ = buffer.set_cell(
                Point(right, bottom), Cell("┘", style=self.border_style)
            )

        if len(self.title.spans) > 0:
            var title_x = area.x + (1 if self.has_border(Self.LEFT) else 0)
            var title_width = area.width
            if self.has_border(Self.LEFT) and title_width > 0:
                title_width -= 1
            if self.has_border(Self.RIGHT) and title_width > 0:
                title_width -= 1
            render_line(
                self.title,
                Rect(title_x, top, title_width, 1),
                buffer,
            )


struct Clear(Copyable, Widget):
    """Replace every visible cell in an area with a plain blank."""

    def __init__(out self):
        pass

    def render(self, area: Rect, mut buffer: Buffer):
        buffer.fill(area, Cell.blank())


struct Paragraph(Copyable, Widget):
    """Styled rich text with optional wrapping and an optional block."""

    var text: Text
    var style: Style
    var wrap: Bool
    var block: Block
    var draw_block: Bool

    def __init__(
        out self,
        text: Text,
        style: Style = Style.plain(),
        wrap: Bool = True,
    ):
        self.text = text.copy()
        self.style = style.copy()
        self.wrap = wrap
        self.block = Block()
        self.draw_block = False

    @staticmethod
    def with_block(
        text: Text,
        block: Block,
        style: Style = Style.plain(),
        wrap: Bool = True,
    ) -> Self:
        var result = Self(text, style, wrap)
        result.block = block.copy()
        result.draw_block = True
        return result^

    def render(self, area: Rect, mut buffer: Buffer):
        if area.is_empty():
            return
        buffer.fill(area, Cell(" ", style=self.style))
        var text_area = area.copy()
        if self.draw_block:
            self.block.render(area, buffer)
            text_area = self.block.inner(area)
        render_text(self.text, text_area, buffer, self.wrap)
