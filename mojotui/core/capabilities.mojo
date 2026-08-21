"""Pure terminal capability values and deterministic adaptive colors."""

from std.collections import List

from .style import Color, ColorKind


struct ColorProfile(Copyable, Equatable, ImplicitlyCopyable):
    """Validated terminal color capability."""

    comptime MONOCHROME = ColorProfile(0, _validated=True)
    comptime ANSI16 = ColorProfile(1, _validated=True)
    comptime ANSI256 = ColorProfile(2, _validated=True)
    comptime TRUE_COLOR = ColorProfile(3, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 3:
            raise Error("invalid terminal color profile")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct TerminalAppearance(Copyable, Equatable, ImplicitlyCopyable):
    """Validated terminal background appearance."""

    comptime UNKNOWN = TerminalAppearance(0, _validated=True)
    comptime LIGHT = TerminalAppearance(1, _validated=True)
    comptime DARK = TerminalAppearance(2, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 2:
            raise Error("invalid terminal appearance")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct TerminalCapabilities(Copyable, ImplicitlyCopyable):
    """Explicit presentation capabilities for one terminal."""

    var profile: ColorProfile
    var appearance: TerminalAppearance
    var synchronized_output: Bool

    def __init__(
        out self,
        profile: ColorProfile = ColorProfile.ANSI16,
        appearance: TerminalAppearance = TerminalAppearance.DARK,
        synchronized_output: Bool = False,
    ):
        self.profile = profile
        self.appearance = appearance
        self.synchronized_output = synchronized_output

    @staticmethod
    def conservative() -> Self:
        """Return the documented deterministic fallback."""
        return Self(ColorProfile.ANSI16, TerminalAppearance.DARK, False)

    @staticmethod
    def headless() -> Self:
        """Return the stable default used by snapshot backends."""
        return Self.conservative()

    def equals(self, other: Self) -> Bool:
        return (
            self.profile == other.profile
            and self.appearance == other.appearance
            and self.synchronized_output == other.synchronized_output
        )


def _distance_squared(
    red: Int,
    green: Int,
    blue: Int,
    target_red: Int,
    target_green: Int,
    target_blue: Int,
) -> Int:
    var red_delta = red - target_red
    var green_delta = green - target_green
    var blue_delta = blue - target_blue
    return red_delta * red_delta + green_delta * green_delta + blue_delta * blue_delta


def _nearest_ansi16(red: Int, green: Int, blue: Int) -> Int:
    var reds: List[Int] = [
        0,
        128,
        0,
        128,
        0,
        128,
        0,
        192,
        128,
        255,
        0,
        255,
        0,
        255,
        0,
        255,
    ]
    var greens: List[Int] = [
        0,
        0,
        128,
        128,
        0,
        0,
        128,
        192,
        128,
        0,
        255,
        255,
        0,
        0,
        255,
        255,
    ]
    var blues: List[Int] = [
        0,
        0,
        0,
        0,
        128,
        128,
        128,
        192,
        128,
        0,
        0,
        0,
        255,
        255,
        255,
        255,
    ]
    var best_index = 0
    var best_distance = Int.MAX
    for index in range(16):
        var distance = _distance_squared(
            red,
            green,
            blue,
            reds[index],
            greens[index],
            blues[index],
        )
        if distance < best_distance:
            best_index = index
            best_distance = distance
    return best_index


def _cube_level(index: Int) -> Int:
    if index == 0:
        return 0
    return 55 + index * 40


def _nearest_ansi256(red: Int, green: Int, blue: Int) -> Int:
    var best_index = 16
    var best_distance = Int.MAX
    for red_index in range(6):
        for green_index in range(6):
            for blue_index in range(6):
                var distance = _distance_squared(
                    red,
                    green,
                    blue,
                    _cube_level(red_index),
                    _cube_level(green_index),
                    _cube_level(blue_index),
                )
                if distance < best_distance:
                    best_index = 16 + red_index * 36 + green_index * 6 + blue_index
                    best_distance = distance
    for gray_index in range(24):
        var level = 8 + gray_index * 10
        var distance = _distance_squared(red, green, blue, level, level, level)
        if distance < best_distance:
            best_index = 232 + gray_index
            best_distance = distance
    return best_index


struct ProfiledColor(Copyable):
    """One resolved fallback for every supported terminal color profile."""

    var monochrome: Color
    var ansi16: Color
    var ansi256: Color
    var true_color: Color

    def __init__(
        out self,
        monochrome: Color,
        ansi16: Color,
        ansi256: Color,
        true_color: Color,
    ) raises:
        if monochrome.kind != ColorKind.DEFAULT:
            raise Error("monochrome fallback must use the default color")
        if ansi16.kind == ColorKind.RGB or (
            ansi16.kind == ColorKind.INDEXED and ansi16.index() > 15
        ):
            raise Error("ANSI-16 fallback must be default or indexed 0 through 15")
        if ansi256.kind == ColorKind.RGB:
            raise Error("ANSI-256 fallback must be default or indexed")
        self.monochrome = monochrome.copy()
        self.ansi16 = ansi16.copy()
        self.ansi256 = ansi256.copy()
        self.true_color = true_color.copy()

    @staticmethod
    def from_rgb(red: Int, green: Int, blue: Int) raises -> Self:
        """Build deterministic xterm palette fallbacks from one RGB color."""
        var resolved = Color.rgb(red, green, blue)
        return Self(
            Color.default(),
            Color.indexed(_nearest_ansi16(resolved.red, resolved.green, resolved.blue)),
            Color.indexed(
                _nearest_ansi256(resolved.red, resolved.green, resolved.blue)
            ),
            resolved,
        )

    @staticmethod
    def plain() raises -> Self:
        """Return a color that leaves every terminal profile unchanged."""
        return Self(
            Color.default(),
            Color.default(),
            Color.default(),
            Color.default(),
        )

    def resolve(self, profile: ColorProfile) -> Color:
        if profile == ColorProfile.MONOCHROME:
            return self.monochrome.copy()
        if profile == ColorProfile.ANSI16:
            return self.ansi16.copy()
        if profile == ColorProfile.ANSI256:
            return self.ansi256.copy()
        return self.true_color.copy()


struct AdaptiveColor(Copyable):
    """Light, dark, and unknown-appearance profiled color intent."""

    var light: ProfiledColor
    var dark: ProfiledColor
    var unknown: ProfiledColor

    def __init__(out self, light: ProfiledColor, dark: ProfiledColor):
        self.light = light.copy()
        self.dark = dark.copy()
        self.unknown = dark.copy()

    def __init__(
        out self,
        light: ProfiledColor,
        dark: ProfiledColor,
        unknown: ProfiledColor,
    ):
        self.light = light.copy()
        self.dark = dark.copy()
        self.unknown = unknown.copy()

    def resolve(self, capabilities: TerminalCapabilities) -> Color:
        if capabilities.appearance == TerminalAppearance.LIGHT:
            return self.light.resolve(capabilities.profile)
        if capabilities.appearance == TerminalAppearance.DARK:
            return self.dark.resolve(capabilities.profile)
        return self.unknown.resolve(capabilities.profile)
