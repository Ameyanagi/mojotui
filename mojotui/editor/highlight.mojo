"""Versioned syntax-highlight results safe against stale background work."""

from std.collections import List

from ..core.style import Style
from .document import Document


struct HighlightRange(Copyable):
    """A styled canonical byte range."""

    var start: Int
    var end: Int
    var style: Style

    def __init__(out self, start: Int, end: Int, style: Style):
        self.start = start
        self.end = end
        self.style = style.copy()


struct HighlightRequest(Copyable):
    """A runtime-neutral request suitable for a background highlighter."""

    var document_version: Int
    var start: Int
    var end: Int

    def __init__(out self, document_version: Int, start: Int, end: Int):
        self.document_version = document_version
        self.start = start
        self.end = end


struct HighlightSnapshot(Copyable):
    """Ranges produced for one exact document version."""

    var document_version: Int
    var ranges: List[HighlightRange]

    def __init__(
        out self,
        document_version: Int,
        var ranges: List[HighlightRange] = List[HighlightRange](),
    ):
        self.document_version = document_version
        self.ranges = ranges^


struct HighlightState(Copyable):
    """The newest accepted, version-matched highlight snapshot."""

    var document_version: Int
    var ranges: List[HighlightRange]

    def __init__(out self):
        self.document_version = -1
        self.ranges = List[HighlightRange]()

    def request(
        self, document: Document, start: Int, end: Int
    ) raises -> HighlightRequest:
        if (
            start < 0
            or end < start
            or end > document.byte_length()
            or not document.is_utf8_boundary(start)
            or not document.is_utf8_boundary(end)
        ):
            raise Error("highlight request range is invalid")
        return HighlightRequest(document.version, start, end)

    def apply(mut self, document: Document, snapshot: HighlightSnapshot) raises -> Bool:
        """Reject stale versions and validate every range before replacement."""
        if snapshot.document_version != document.version:
            return False
        for index in range(len(snapshot.ranges)):
            var highlight = snapshot.ranges[index].copy()
            if (
                highlight.start < 0
                or highlight.end < highlight.start
                or highlight.end > document.byte_length()
                or not document.is_utf8_boundary(highlight.start)
                or not document.is_utf8_boundary(highlight.end)
            ):
                raise Error("highlight snapshot range is invalid")
        self.document_version = snapshot.document_version
        self.ranges = snapshot.ranges.copy()
        return True

    def style_for(
        self,
        document_version: Int,
        start: Int,
        end: Int,
        fallback: Style,
    ) -> Style:
        if self.document_version != document_version:
            return fallback.copy()
        var result = fallback.copy()
        for index in range(len(self.ranges)):
            if start < self.ranges[index].end and end > self.ranges[index].start:
                result = self.ranges[index].style.copy()
        return result^
