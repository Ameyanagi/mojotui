"""Unicode-aware terminal column measurement."""

from ._unicode_width_data import (
    is_ambiguous,
    is_emoji,
    is_wide,
    is_zero_width,
    unicode_data_version,
)


def unicode_version() -> String:
    """Return the Unicode version used by the generated width tables."""
    return unicode_data_version()


def codepoint_width(value: Int, ambiguous_is_wide: Bool = False) -> Int:
    """Return a safe terminal width for one Unicode scalar value."""
    if value <= 0 or value < 0x20 or (value >= 0x7F and value < 0xA0):
        return 0
    if is_zero_width(value):
        return 0
    if is_wide(value):
        return 2
    if ambiguous_is_wide and is_ambiguous(value):
        return 2
    return 1


def grapheme_width(grapheme: StringSlice, ambiguous_is_wide: Bool = False) -> Int:
    """Measure one extended grapheme cluster as zero, one, or two columns."""
    if not grapheme:
        return 0

    var maximum_width = 0
    var has_emoji = False
    var has_emoji_selector = False
    for scalar in grapheme.codepoints():
        var value = Int(scalar.to_u32())
        if value == 0xFE0F:
            has_emoji_selector = True
        if is_emoji(value):
            has_emoji = True
        var width = codepoint_width(value, ambiguous_is_wide)
        if width > maximum_width:
            maximum_width = width

    if has_emoji and has_emoji_selector:
        return 2
    return maximum_width


def text_width(text: StringSlice, ambiguous_is_wide: Bool = False) -> Int:
    """Measure text by scanning each grapheme cluster once."""
    var total = 0
    for grapheme in text.graphemes():
        total += grapheme_width(grapheme, ambiguous_is_wide)
    return total
