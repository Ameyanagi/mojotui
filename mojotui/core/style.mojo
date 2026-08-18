"""Backend-independent terminal colors and text attributes."""


def _channel(value: Int) -> Int:
    return max(0, min(value, 255))


struct Color(Copyable):
    """A default, indexed, or 24-bit terminal color."""

    comptime DEFAULT = 0
    comptime INDEXED = 1
    comptime RGB = 2

    var kind: Int
    var red: Int
    var green: Int
    var blue: Int

    def __init__(
        out self,
        kind: Int = Self.DEFAULT,
        red: Int = 0,
        green: Int = 0,
        blue: Int = 0,
    ):
        self.kind = kind if kind >= Self.DEFAULT and kind <= Self.RGB else Self.DEFAULT
        self.red = _channel(red)
        self.green = _channel(green)
        self.blue = _channel(blue)

    @staticmethod
    def default() -> Self:
        return Self()

    @staticmethod
    def indexed(index: Int) -> Self:
        return Self(Self.INDEXED, _channel(index))

    @staticmethod
    def rgb(red: Int, green: Int, blue: Int) -> Self:
        return Self(Self.RGB, red, green, blue)

    def index(self) -> Int:
        return self.red

    def equals(self, other: Self) -> Bool:
        return (
            self.kind == other.kind
            and self.red == other.red
            and self.green == other.green
            and self.blue == other.blue
        )


struct Style(Copyable):
    """Foreground, background, and composable terminal modifiers."""

    comptime BOLD = 1 << 0
    comptime DIM = 1 << 1
    comptime ITALIC = 1 << 2
    comptime UNDERLINED = 1 << 3
    comptime SLOW_BLINK = 1 << 4
    comptime REVERSED = 1 << 5
    comptime HIDDEN = 1 << 6
    comptime CROSSED_OUT = 1 << 7
    comptime ALL_MODIFIERS = (1 << 8) - 1

    var foreground: Color
    var background: Color
    var modifiers: Int

    def __init__(
        out self,
        foreground: Color = Color.default(),
        background: Color = Color.default(),
        modifiers: Int = 0,
    ):
        self.foreground = foreground.copy()
        self.background = background.copy()
        self.modifiers = modifiers & Self.ALL_MODIFIERS

    @staticmethod
    def plain() -> Self:
        return Self()

    def has(self, modifier: Int) -> Bool:
        return (self.modifiers & modifier) != 0

    def equals(self, other: Self) -> Bool:
        return (
            self.foreground.equals(other.foreground)
            and self.background.equals(other.background)
            and self.modifiers == other.modifiers
        )
