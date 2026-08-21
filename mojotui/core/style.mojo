"""Backend-independent terminal colors and composable style patches."""

from std.collections import Optional


def _channel(value: Int) -> Int:
    return max(0, min(value, 255))


struct ColorKind(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal terminal-color representation discriminator."""

    comptime DEFAULT = ColorKind(0, _validated=True)
    comptime INDEXED = ColorKind(1, _validated=True)
    comptime RGB = ColorKind(2, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 2:
            raise Error("invalid terminal color kind")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct Color(Copyable, ImplicitlyCopyable):
    """A default, indexed, or 24-bit terminal color."""

    comptime DEFAULT = ColorKind.DEFAULT
    comptime INDEXED = ColorKind.INDEXED
    comptime RGB = ColorKind.RGB

    var kind: ColorKind
    var red: Int
    var green: Int
    var blue: Int

    def __init__(
        out self,
        kind: ColorKind = Self.DEFAULT,
        red: Int = 0,
        green: Int = 0,
        blue: Int = 0,
    ):
        self.kind = kind
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


struct ModifierSet(Copyable, Equatable, ImplicitlyCopyable):
    """Validated set of terminal text attributes."""

    comptime NONE = ModifierSet(0, _validated=True)
    comptime BOLD = ModifierSet(1 << 0, _validated=True)
    comptime DIM = ModifierSet(1 << 1, _validated=True)
    comptime ITALIC = ModifierSet(1 << 2, _validated=True)
    comptime UNDERLINED = ModifierSet(1 << 3, _validated=True)
    comptime SLOW_BLINK = ModifierSet(1 << 4, _validated=True)
    comptime REVERSED = ModifierSet(1 << 5, _validated=True)
    comptime HIDDEN = ModifierSet(1 << 6, _validated=True)
    comptime CROSSED_OUT = ModifierSet(1 << 7, _validated=True)
    comptime ALL = ModifierSet((1 << 8) - 1, _validated=True)

    var _bits: Int

    def __init__(out self, bits: Int, *, _validated: Bool):
        self._bits = bits

    def __init__(out self, bits: Int) raises:
        if bits < 0 or (bits & ~((1 << 8) - 1)) != 0:
            raise Error("invalid terminal modifier flags")
        self._bits = bits

    def __eq__(self, other: Self) -> Bool:
        return self._bits == other._bits

    def __or__(self, other: Self) -> Self:
        return Self(self._bits | other._bits, _validated=True)

    def union(self, other: Self) -> Self:
        return self | other

    def contains(self, modifier: Self) -> Bool:
        return (self._bits & modifier._bits) == modifier._bits

    def without(self, modifiers: Self) -> Self:
        return Self(self._bits & ~modifiers._bits, _validated=True)

    def is_empty(self) -> Bool:
        return self._bits == 0


struct Style(Copyable):
    """A fully resolved cell style."""

    comptime BOLD = ModifierSet.BOLD
    comptime DIM = ModifierSet.DIM
    comptime ITALIC = ModifierSet.ITALIC
    comptime UNDERLINED = ModifierSet.UNDERLINED
    comptime SLOW_BLINK = ModifierSet.SLOW_BLINK
    comptime REVERSED = ModifierSet.REVERSED
    comptime HIDDEN = ModifierSet.HIDDEN
    comptime CROSSED_OUT = ModifierSet.CROSSED_OUT
    comptime ALL_MODIFIERS = ModifierSet.ALL

    var foreground: Color
    var background: Color
    var underline_color: Color
    var modifiers: ModifierSet

    def __init__(
        out self,
        foreground: Color = Color.default(),
        background: Color = Color.default(),
        modifiers: ModifierSet = ModifierSet.NONE,
        underline_color: Color = Color.default(),
    ):
        self.foreground = foreground.copy()
        self.background = background.copy()
        self.underline_color = underline_color.copy()
        self.modifiers = modifiers

    @staticmethod
    def plain() -> Self:
        return Self()

    def has(self, modifier: ModifierSet) -> Bool:
        return self.modifiers.contains(modifier)

    def bold(self) -> Self:
        return self.patched(StylePatch(add_modifiers=Self.BOLD))

    def italic(self) -> Self:
        return self.patched(StylePatch(add_modifiers=Self.ITALIC))

    def dim(self) -> Self:
        return self.patched(StylePatch(add_modifiers=Self.DIM))

    def underlined(self) -> Self:
        return self.patched(StylePatch(add_modifiers=Self.UNDERLINED))

    def reversed(self) -> Self:
        return self.patched(StylePatch(add_modifiers=Self.REVERSED))

    def crossed_out(self) -> Self:
        return self.patched(StylePatch(add_modifiers=Self.CROSSED_OUT))

    def fg(self, color: Color) -> Self:
        return self.patched(StylePatch(foreground=color))

    def bg(self, color: Color) -> Self:
        return self.patched(StylePatch(background=color))

    def patched(self, patch: StylePatch) -> Self:
        """Resolve one patch over this style without erasing unspecified fields."""
        var result = self.copy()
        result.apply_patch(patch)
        return result^

    def apply_patch(mut self, patch: StylePatch):
        if patch.foreground:
            self.foreground = patch.foreground.value().copy()
        if patch.background:
            self.background = patch.background.value().copy()
        if patch.underline_color:
            self.underline_color = patch.underline_color.value().copy()
        self.modifiers = self.modifiers.union(patch.add_modifiers).without(
            patch.remove_modifiers
        )

    def equals(self, other: Self) -> Bool:
        return (
            self.foreground.equals(other.foreground)
            and self.background.equals(other.background)
            and self.underline_color.equals(other.underline_color)
            and self.modifiers == other.modifiers
        )


struct StylePatch(Copyable):
    """Composable optional changes applied over a resolved `Style`."""

    var foreground: Optional[Color]
    var background: Optional[Color]
    var underline_color: Optional[Color]
    var add_modifiers: ModifierSet
    var remove_modifiers: ModifierSet

    def __init__(
        out self,
        foreground: Optional[Color] = None,
        background: Optional[Color] = None,
        underline_color: Optional[Color] = None,
        add_modifiers: ModifierSet = ModifierSet.NONE,
        remove_modifiers: ModifierSet = ModifierSet.NONE,
    ):
        self.foreground = foreground.copy()
        self.background = background.copy()
        self.underline_color = underline_color.copy()
        self.add_modifiers = add_modifiers.without(remove_modifiers)
        self.remove_modifiers = remove_modifiers

    @staticmethod
    def plain() -> Self:
        return Self()

    def bold(self) -> Self:
        return self.then(Self(add_modifiers=ModifierSet.BOLD))

    def italic(self) -> Self:
        return self.then(Self(add_modifiers=ModifierSet.ITALIC))

    def dim(self) -> Self:
        return self.then(Self(add_modifiers=ModifierSet.DIM))

    def underlined(self) -> Self:
        return self.then(Self(add_modifiers=ModifierSet.UNDERLINED))

    def reversed(self) -> Self:
        return self.then(Self(add_modifiers=ModifierSet.REVERSED))

    def crossed_out(self) -> Self:
        return self.then(Self(add_modifiers=ModifierSet.CROSSED_OUT))

    def fg(self, color: Color) -> Self:
        return self.then(Self(foreground=color))

    def bg(self, color: Color) -> Self:
        return self.then(Self(background=color))

    @staticmethod
    def from_style(style: Style) -> Self:
        """Convert non-default resolved attributes into compositional intent."""
        var foreground: Optional[Color] = None
        var background: Optional[Color] = None
        var underline_color: Optional[Color] = None
        if style.foreground.kind != ColorKind.DEFAULT:
            foreground = style.foreground.copy()
        if style.background.kind != ColorKind.DEFAULT:
            background = style.background.copy()
        if style.underline_color.kind != ColorKind.DEFAULT:
            underline_color = style.underline_color.copy()
        return Self(
            foreground,
            background,
            underline_color,
            style.modifiers,
        )

    def resolved(self, base: Style = Style.plain()) -> Style:
        """Resolve this patch over an explicit cell style."""
        return base.patched(self)

    def then(self, next: Self) -> Self:
        """Compose patches so `next` has precedence over this patch."""
        var foreground = (
            next.foreground.copy() if next.foreground else self.foreground.copy()
        )
        var background = (
            next.background.copy() if next.background else self.background.copy()
        )
        var underline_color = (
            next.underline_color.copy() if next.underline_color else self.underline_color.copy()
        )
        var added = self.add_modifiers.without(next.remove_modifiers).union(
            next.add_modifiers
        )
        var removed = self.remove_modifiers.without(next.add_modifiers).union(
            next.remove_modifiers
        )
        return Self(
            foreground,
            background,
            underline_color,
            added,
            removed,
        )
