"""A safe logical terminal cell."""

from ..text.width import grapheme_width
from .style import Style, StylePatch


struct Cell(Copyable):
    """A grapheme cell without backend-specific escape sequences.

    Width is constrained to the renderer's zero-, one-, or two-column
    invariant. A continuation cell reserves the second column of a wide
    grapheme and is never emitted independently.
    """

    var symbol: String
    var width: Int
    var continuation: Bool
    var style: Style
    var _ambiguous_is_wide: Bool

    def __init__(
        out self,
        var symbol: String = " ",
        width: Int = 1,
        continuation: Bool = False,
        style: Style = Style.plain(),
        *,
        _ambiguous_is_wide: Bool = False,
    ):
        self.symbol = symbol^
        self.width = width
        self.continuation = continuation
        self.style = style.copy()
        self._ambiguous_is_wide = _ambiguous_is_wide

    @staticmethod
    def blank() -> Self:
        return Self()

    @staticmethod
    def trailing(style: Style = Style.plain()) -> Self:
        return Self("", 0, True, style)

    @staticmethod
    def from_grapheme(
        var symbol: String,
        ambiguous_is_wide: Bool = False,
        style: Style = Style.plain(),
    ) raises -> Self:
        """Construct a cell after validating and measuring one grapheme."""
        if StringSlice(symbol).count_graphemes() != 1:
            raise Error(
                String(
                    'cell symbol must be exactly one grapheme; got "',
                    symbol,
                    '"',
                )
            )
        var width = grapheme_width(symbol, ambiguous_is_wide)
        return Self(
            symbol^,
            width,
            style=style,
            _ambiguous_is_wide=ambiguous_is_wide,
        )

    def is_valid(self) -> Bool:
        """Return whether public fields still describe one safe logical cell."""
        if self.continuation:
            return self.symbol == "" and self.width == 0
        if self.width < 1 or self.width > 2:
            return False
        if StringSlice(self.symbol).count_graphemes() != 1:
            return False
        return grapheme_width(self.symbol, self._ambiguous_is_wide) == self.width

    def equals(self, other: Self) -> Bool:
        return (
            self.symbol == other.symbol
            and self.width == other.width
            and self.continuation == other.continuation
            and self.style.equals(other.style)
            and self._ambiguous_is_wide == other._ambiguous_is_wide
        )

    def apply_style_patch(mut self, patch: StylePatch):
        """Apply optional style changes without altering grapheme state."""
        self.style.apply_patch(patch)

    def patched_style(self, patch: StylePatch) -> Self:
        var result = self.copy()
        result.apply_style_patch(patch)
        return result^
