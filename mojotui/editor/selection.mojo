"""Ordered multiple selections with grapheme-aware cursor navigation."""

from std.collections import List, Optional

from ..text.width import grapheme_width
from .document import Document


struct Selection(Copyable):
    """An anchor and active head expressed as canonical byte offsets."""

    var anchor: Int
    var head: Int
    var desired_column: Optional[UInt]

    def __init__(
        out self,
        anchor: Int = 0,
        head: Int = 0,
        desired_column: Optional[UInt] = None,
    ):
        self.anchor = max(anchor, 0)
        self.head = max(head, 0)
        self.desired_column = desired_column.copy()

    @staticmethod
    def caret(offset: Int) -> Self:
        return Self(offset, offset)

    def start(self) -> Int:
        return min(self.anchor, self.head)

    def end(self) -> Int:
        return max(self.anchor, self.head)

    def is_empty(self) -> Bool:
        return self.anchor == self.head


struct SelectionSet(Copyable):
    """Sorted, non-overlapping selections with one primary selection."""

    var selections: List[Selection]
    var primary: Int

    def __init__(
        out self,
        var selections: List[Selection] = [Selection.caret(0)],
        primary: Int = 0,
    ):
        self.selections = selections^
        self.primary = max(primary, 0)
        if len(self.selections) == 0:
            self.selections.append(Selection.caret(0))
            self.primary = 0
        else:
            self.primary = min(self.primary, len(self.selections) - 1)

    def primary_selection(self) -> Selection:
        return self.selections[self.primary].copy()

    def normalize(mut self, document: Document) raises:
        """Sort selections and merge overlap or touching ranges."""
        var primary_head = self.selections[self.primary].head
        for index in range(len(self.selections)):
            var selection = self.selections[index].copy()
            if (
                selection.end() > document.byte_length()
                or not document.is_utf8_boundary(selection.anchor)
                or not document.is_utf8_boundary(selection.head)
            ):
                raise Error("selection is not on a valid document boundary")

        for index in range(1, len(self.selections)):
            var value = self.selections[index].copy()
            var cursor = index
            while cursor > 0:
                var previous = self.selections[cursor - 1].copy()
                if previous.start() < value.start() or (
                    previous.start() == value.start() and previous.end() <= value.end()
                ):
                    break
                self.selections[cursor] = previous.copy()
                cursor -= 1
            self.selections[cursor] = value.copy()

        var normalized = List[Selection]()
        for index in range(len(self.selections)):
            var current = self.selections[index].copy()
            if len(normalized) == 0:
                normalized.append(current.copy())
                continue
            var last = normalized[len(normalized) - 1].copy()
            if current.start() <= last.end():
                normalized[len(normalized) - 1] = Selection(
                    min(last.start(), current.start()),
                    max(last.end(), current.end()),
                )
            else:
                normalized.append(current.copy())

        self.selections = normalized^
        self.primary = 0
        for index in range(len(self.selections)):
            if (
                primary_head >= self.selections[index].start()
                and primary_head <= self.selections[index].end()
            ):
                self.primary = index
                break


struct CursorMotion(Copyable):
    """A resulting offset plus the sticky display column for vertical motion."""

    var offset: Int
    var desired_column: Optional[UInt]

    def __init__(out self, offset: Int, desired_column: Optional[UInt] = None):
        self.offset = offset
        self.desired_column = desired_column.copy()


def next_grapheme_offset(document: Document, offset: Int) raises -> Int:
    """Move to the next extended-grapheme boundary, including newlines."""
    var position = document.position_at(offset)
    if offset == document.byte_length():
        return offset
    var line_end = document.line_end(position.line)
    if offset == line_end:
        return offset + 1
    var line_start = document.line_start(position.line)
    var line = document.line_text(position.line)
    var relative = offset - line_start
    var cursor = 0
    for grapheme in line.graphemes():
        cursor += grapheme.byte_length()
        if cursor > relative:
            return line_start + cursor
    return line_end


def previous_grapheme_offset(document: Document, offset: Int) raises -> Int:
    """Move to the previous extended-grapheme boundary, including newlines."""
    var position = document.position_at(offset)
    if offset == 0:
        return 0
    var line_start = document.line_start(position.line)
    if offset == line_start:
        return offset - 1
    var line = document.line_text(position.line)
    var relative = offset - line_start
    var cursor = 0
    var previous = 0
    for grapheme in line.graphemes():
        cursor += grapheme.byte_length()
        if cursor >= relative:
            return line_start + previous
        previous = cursor
    return line_start + previous


def _advance_column(
    column: Int,
    var grapheme: String,
    tab_width: Int,
    ambiguous_is_wide: Bool,
) -> Int:
    if grapheme == "\t":
        var width = max(tab_width, 1)
        return column + width - column % width
    return column + grapheme_width(grapheme, ambiguous_is_wide)


def display_column(
    document: Document,
    offset: Int,
    tab_width: Int = 4,
    ambiguous_is_wide: Bool = False,
) raises -> Int:
    """Measure the display column from line start to a byte offset."""
    var position = document.position_at(offset)
    var line_start = document.line_start(position.line)
    var prefix = document.slice(
        line_start, min(offset, document.line_end(position.line))
    )
    var column = 0
    for grapheme in prefix.graphemes():
        column = _advance_column(column, String(grapheme), tab_width, ambiguous_is_wide)
    return column


def offset_for_display_column(
    document: Document,
    line: Int,
    target_column: Int,
    tab_width: Int = 4,
    ambiguous_is_wide: Bool = False,
) raises -> Int:
    """Find the greatest grapheme boundary not exceeding a display column."""
    var start = document.line_start(line)
    var text = document.line_text(line)
    var offset = start
    var column = 0
    var target = max(target_column, 0)
    for grapheme in text.graphemes():
        var content = String(grapheme)
        var next_column = _advance_column(column, content, tab_width, ambiguous_is_wide)
        if next_column > target:
            return offset
        offset += content.byte_length()
        column = next_column
    return offset


def move_vertical(
    document: Document,
    offset: Int,
    line_delta: Int,
    desired_column: Optional[UInt] = None,
    tab_width: Int = 4,
    ambiguous_is_wide: Bool = False,
) raises -> CursorMotion:
    """Move by logical lines while preserving the original display column."""
    var position = document.position_at(offset)
    var desired = Int(desired_column.value()) if desired_column else display_column(
        document, offset, tab_width, ambiguous_is_wide
    )
    var target_line = max(0, min(position.line + line_delta, document.line_count() - 1))
    return CursorMotion(
        offset_for_display_column(
            document,
            target_line,
            desired,
            tab_width,
            ambiguous_is_wide,
        ),
        UInt(desired),
    )


def move_selection_left(
    document: Document, mut selection: Selection, extend: Bool = False
) raises:
    var target = (
        selection.start() if not extend
        and not selection.is_empty() else previous_grapheme_offset(
            document, selection.head
        )
    )
    selection.head = target
    if not extend:
        selection.anchor = target
    selection.desired_column = None


def move_selection_right(
    document: Document, mut selection: Selection, extend: Bool = False
) raises:
    var target = (
        selection.end() if not extend
        and not selection.is_empty() else next_grapheme_offset(document, selection.head)
    )
    selection.head = target
    if not extend:
        selection.anchor = target
    selection.desired_column = None


def move_selection_vertical(
    document: Document,
    mut selection: Selection,
    line_delta: Int,
    extend: Bool = False,
    tab_width: Int = 4,
    ambiguous_is_wide: Bool = False,
) raises:
    var motion = move_vertical(
        document,
        selection.head,
        line_delta,
        selection.desired_column,
        tab_width,
        ambiguous_is_wide,
    )
    selection.head = motion.offset
    selection.desired_column = motion.desired_column
    if not extend:
        selection.anchor = motion.offset
