"""Unicode-aware terminal column measurement."""

from moji import (
    UNICODE_DATA_VERSION,
    AmbiguousWidth,
    grapheme_width as moji_grapheme_width,
    scalar_width,
    text_width as moji_text_width,
)


def unicode_version() -> String:
    """Return the Unicode version used by moji's width tables."""
    return String(UNICODE_DATA_VERSION)


def codepoint_width(value: Int, ambiguous_is_wide: Bool = False) -> Int:
    """Return a safe terminal width for one Unicode scalar value."""
    if value < 0 or value > 0x10FFFF:
        return 0
    var scalar = Codepoint.from_u32(UInt32(value))
    if not scalar:
        return 0
    return scalar_width(
        scalar.value(),
        AmbiguousWidth.WIDE if ambiguous_is_wide else AmbiguousWidth.NARROW,
    )


def grapheme_width(grapheme: StringSlice, ambiguous_is_wide: Bool = False) -> Int:
    """Measure one extended grapheme cluster as zero, one, or two columns."""
    return moji_grapheme_width(
        grapheme,
        AmbiguousWidth.WIDE if ambiguous_is_wide else AmbiguousWidth.NARROW,
    )


def text_width(text: StringSlice, ambiguous_is_wide: Bool = False) -> Int:
    """Measure text by scanning each grapheme cluster once."""
    return moji_text_width(
        text,
        AmbiguousWidth.WIDE if ambiguous_is_wide else AmbiguousWidth.NARROW,
    )
