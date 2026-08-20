"""An array-backed implicit-treap piece table with cached text metrics."""

from std.collections import List


struct PieceSource(Copyable, Equatable, ImplicitlyCopyable):
    """The immutable original buffer or append-only edit buffer."""

    comptime ORIGINAL = PieceSource(0, _validated=True)
    comptime ADD = PieceSource(1, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 1:
            raise Error("invalid document piece source")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct MarkerAffinity(Copyable, Equatable, ImplicitlyCopyable):
    """How a marker behaves when text is inserted exactly at its offset."""

    comptime BEFORE = MarkerAffinity(0, _validated=True)
    comptime AFTER = MarkerAffinity(1, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 1:
            raise Error("invalid marker affinity")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct MarkerId(Copyable):
    """An opaque stable identity owned by one document."""

    var value: Int

    def __init__(out self, value: Int):
        self.value = value


struct TextPosition(Copyable):
    """A canonical byte offset with derived line and byte-column metadata."""

    var byte_offset: Int
    var line: Int
    var byte_column: Int

    def __init__(out self, byte_offset: Int, line: Int, byte_column: Int):
        self.byte_offset = byte_offset
        self.line = line
        self.byte_column = byte_column


struct _Marker(Copyable):
    var id: MarkerId
    var offset: Int
    var affinity: MarkerAffinity
    var active: Bool

    def __init__(out self, id: MarkerId, offset: Int, affinity: MarkerAffinity):
        self.id = id.copy()
        self.offset = offset
        self.affinity = affinity
        self.active = True


struct _Piece(Copyable):
    var source: PieceSource
    var start: Int
    var byte_length: Int
    var newlines: Int

    def __init__(
        out self,
        source: PieceSource,
        start: Int,
        byte_length: Int,
        newlines: Int,
    ):
        self.source = source
        self.start = start
        self.byte_length = byte_length
        self.newlines = newlines


struct _PieceNode(Copyable):
    var piece: _Piece
    var left: Int
    var right: Int
    var priority: Int
    var subtree_bytes: Int
    var subtree_newlines: Int
    var subtree_pieces: Int

    def __init__(out self, piece: _Piece, priority: Int):
        self.piece = piece.copy()
        self.left = -1
        self.right = -1
        self.priority = priority
        self.subtree_bytes = piece.byte_length
        self.subtree_newlines = piece.newlines
        self.subtree_pieces = 1


struct Document(Movable):
    """UTF-8 text stored as pieces in a deterministic balanced sequence tree.

    Public positions are canonical byte offsets. Mutations reject offsets in
    the middle of a UTF-8 code point. Nodes live in a safe Mojo `List`; tree
    links are checked integer indices and no pointer or FFI operation is used.
    """

    var original: String
    var additions: String
    var nodes: List[_PieceNode]
    var root: Int
    var version: Int
    var markers: List[_Marker]
    var next_marker_id: Int

    def __init__(out self, var text: String = ""):
        self.original = text^
        self.additions = ""
        self.nodes = List[_PieceNode]()
        self.root = -1
        self.version = 0
        self.markers = List[_Marker]()
        self.next_marker_id = 0
        var length = self.original.byte_length()
        if length > 0:
            self.root = self._tree_for_range(PieceSource.ORIGINAL, 0, length)

    @staticmethod
    def _count_newlines(text: StringSlice) -> Int:
        var count = 0
        for byte in text.bytes():
            if byte == UInt8(0x0A):
                count += 1
        return count

    @staticmethod
    def _priority(index: Int) -> Int:
        """Bit reversal distributes sequential allocations without randomness."""
        var value = index + 1
        var result = 0
        for _ in range(31):
            result = result * 2 + (value & 1)
            value >>= 1
        return result

    def _new_node(mut self, piece: _Piece) -> Int:
        var index = len(self.nodes)
        self.nodes.append(_PieceNode(piece, Self._priority(index)))
        return index

    def _new_node_with_priority(mut self, piece: _Piece, priority: Int) -> Int:
        var index = len(self.nodes)
        self.nodes.append(_PieceNode(piece, priority))
        return index

    def _bytes(self, node: Int) -> Int:
        return 0 if node < 0 else self.nodes[node].subtree_bytes

    def _newlines(self, node: Int) -> Int:
        return 0 if node < 0 else self.nodes[node].subtree_newlines

    def _pieces(self, node: Int) -> Int:
        return 0 if node < 0 else self.nodes[node].subtree_pieces

    def _refresh(mut self, node: Int):
        if node < 0:
            return
        var left = self.nodes[node].left
        var right = self.nodes[node].right
        self.nodes[node].subtree_bytes = (
            self._bytes(left) + self.nodes[node].piece.byte_length + self._bytes(right)
        )
        self.nodes[node].subtree_newlines = (
            self._newlines(left)
            + self.nodes[node].piece.newlines
            + self._newlines(right)
        )
        self.nodes[node].subtree_pieces = self._pieces(left) + 1 + self._pieces(right)

    def _piece_text(self, piece: _Piece) -> String:
        if piece.source == PieceSource.ORIGINAL:
            return String(
                self.original[byte = piece.start : piece.start + piece.byte_length]
            )
        return String(
            self.additions[byte = piece.start : piece.start + piece.byte_length]
        )

    def _source_byte(self, source: PieceSource, offset: Int) -> UInt8:
        if source == PieceSource.ORIGINAL:
            return self.original.as_bytes()[offset]
        return self.additions.as_bytes()[offset]

    def _range_newlines(self, source: PieceSource, start: Int, length: Int) -> Int:
        var count = 0
        for offset in range(start, start + length):
            if self._source_byte(source, offset) == UInt8(0x0A):
                count += 1
        return count

    def _tree_for_range(
        mut self, source: PieceSource, start: Int, byte_length: Int
    ) -> Int:
        """Chunk source ranges so local scans stay bounded on large files."""
        comptime TARGET_BYTES = 4096
        var result = -1
        var cursor = start
        var limit = start + byte_length
        while cursor < limit:
            var end = min(cursor + TARGET_BYTES, limit)
            while (
                end < limit
                and Int(self._source_byte(source, end)) >= 0x80
                and Int(self._source_byte(source, end)) <= 0xBF
            ):
                end -= 1
            var length = end - cursor
            var piece = _Piece(
                source,
                cursor,
                length,
                self._range_newlines(source, cursor, length),
            )
            result = self._merge(result, self._new_node(piece))
            cursor = end
        return result

    def _piece_range(
        self, piece: _Piece, relative_start: Int, byte_length: Int
    ) -> String:
        var start = piece.start + relative_start
        if piece.source == PieceSource.ORIGINAL:
            return String(self.original[byte = start : start + byte_length])
        return String(self.additions[byte = start : start + byte_length])

    def _subpiece(self, piece: _Piece, relative_start: Int, byte_length: Int) -> _Piece:
        var text = self._piece_range(piece, relative_start, byte_length)
        return _Piece(
            piece.source,
            piece.start + relative_start,
            byte_length,
            Self._count_newlines(text),
        )

    def _merge(mut self, left: Int, right: Int) -> Int:
        if left < 0:
            return right
        if right < 0:
            return left
        if self.nodes[left].priority <= self.nodes[right].priority:
            var child = self.nodes[left].right
            self.nodes[left].right = self._merge(child, right)
            self._refresh(left)
            return left
        var child = self.nodes[right].left
        self.nodes[right].left = self._merge(left, child)
        self._refresh(right)
        return right

    def _split(mut self, node: Int, byte_offset: Int) raises -> Tuple[Int, Int]:
        """Split a tree before a known UTF-8 boundary."""
        if node < 0:
            return -1, -1
        var left = self.nodes[node].left
        var right = self.nodes[node].right
        var left_bytes = self._bytes(left)
        var piece = self.nodes[node].piece.copy()

        if byte_offset < left_bytes:
            var before, after = self._split(left, byte_offset)
            self.nodes[node].left = after
            self._refresh(node)
            return before, node
        if byte_offset > left_bytes + piece.byte_length:
            var before, after = self._split(
                right, byte_offset - left_bytes - piece.byte_length
            )
            self.nodes[node].right = before
            self._refresh(node)
            return node, after
        if byte_offset == left_bytes:
            self.nodes[node].left = -1
            self._refresh(node)
            return left, node
        if byte_offset == left_bytes + piece.byte_length:
            self.nodes[node].right = -1
            self._refresh(node)
            return node, right

        var within = byte_offset - left_bytes
        var left_piece = self._subpiece(piece, 0, within)
        var right_piece = self._subpiece(piece, within, piece.byte_length - within)
        # Both fragments retain the original node's heap priority. Assigning
        # fresh priorities here would let a fragment outrank an ancestor and
        # invalidate the standard implicit-treap split operation.
        var priority = self.nodes[node].priority
        var left_node = self._new_node_with_priority(left_piece, priority)
        var right_node = self._new_node_with_priority(right_piece, priority)
        return self._merge(left, left_node), self._merge(right_node, right)

    def _byte_at(self, offset: Int) -> Int:
        var node = self.root
        var remaining = offset
        while node >= 0:
            var left_bytes = self._bytes(self.nodes[node].left)
            if remaining < left_bytes:
                node = self.nodes[node].left
                continue
            remaining -= left_bytes
            var piece = self.nodes[node].piece.copy()
            if remaining < piece.byte_length:
                if piece.source == PieceSource.ORIGINAL:
                    return Int(self.original.as_bytes()[piece.start + remaining])
                return Int(self.additions.as_bytes()[piece.start + remaining])
            remaining -= piece.byte_length
            node = self.nodes[node].right
        return -1

    def is_utf8_boundary(self, offset: Int) -> Bool:
        if offset < 0 or offset > self.byte_length():
            return False
        if offset == 0 or offset == self.byte_length():
            return True
        var byte = self._byte_at(offset)
        return byte < 0x80 or byte > 0xBF

    def _validate_range(self, start: Int, end: Int) raises:
        if start < 0 or end < start or end > self.byte_length():
            raise Error("document byte range is out of bounds")
        if not self.is_utf8_boundary(start) or not self.is_utf8_boundary(end):
            raise Error("document byte range splits a UTF-8 code point")

    def _bump_version(mut self) raises:
        if self.version == Int.MAX:
            raise Error("document version exhausted")
        self.version += 1

    def _ensure_version_available(self) raises:
        if self.version == Int.MAX:
            raise Error("document version exhausted")

    def byte_length(self) -> Int:
        return self._bytes(self.root)

    def newline_count(self) -> Int:
        return self._newlines(self.root)

    def line_count(self) -> Int:
        return self.newline_count() + 1

    def piece_count(self) -> Int:
        return self._pieces(self.root)

    def insert(mut self, offset: Int, var text: String) raises:
        """Insert UTF-8 bytes at a canonical code-point boundary."""
        self._validate_range(offset, offset)
        if text == "":
            return
        self._ensure_version_available()
        var add_start = self.additions.byte_length()
        var byte_length = text.byte_length()
        self.additions += text
        var before, after = self._split(self.root, offset)
        var inserted = self._tree_for_range(PieceSource.ADD, add_start, byte_length)
        self.root = self._merge(self._merge(before, inserted), after)
        self._markers_after_insert(offset, byte_length)
        self._bump_version()

    def _collect(self, mut result: String, node: Int):
        if node < 0:
            return
        self._collect(result, self.nodes[node].left)
        result += self._piece_text(self.nodes[node].piece)
        self._collect(result, self.nodes[node].right)

    def to_string(self) -> String:
        var result = String()
        self._collect(result, self.root)
        return result^

    def _collect_range(
        self,
        mut result: String,
        node: Int,
        subtree_start: Int,
        wanted_start: Int,
        wanted_end: Int,
    ):
        if node < 0 or wanted_start >= wanted_end:
            return
        var left = self.nodes[node].left
        var left_bytes = self._bytes(left)
        var piece = self.nodes[node].piece.copy()
        var piece_start = subtree_start + left_bytes
        var piece_end = piece_start + piece.byte_length
        if wanted_start < piece_start:
            self._collect_range(
                result,
                left,
                subtree_start,
                wanted_start,
                min(wanted_end, piece_start),
            )
        var overlap_start = max(wanted_start, piece_start)
        var overlap_end = min(wanted_end, piece_end)
        if overlap_start < overlap_end:
            result += self._piece_range(
                piece,
                overlap_start - piece_start,
                overlap_end - overlap_start,
            )
        if wanted_end > piece_end:
            self._collect_range(
                result,
                self.nodes[node].right,
                piece_end,
                max(wanted_start, piece_end),
                wanted_end,
            )

    def slice(self, start: Int, end: Int) raises -> String:
        self._validate_range(start, end)
        var result = String()
        self._collect_range(result, self.root, 0, start, end)
        return result^

    def delete(mut self, start: Int, end: Int) raises -> String:
        """Delete a range and return its exact UTF-8 contents."""
        self._validate_range(start, end)
        if start == end:
            return ""
        self._ensure_version_available()
        var removed = self.slice(start, end)
        var before, tail = self._split(self.root, start)
        var discarded, after = self._split(tail, end - start)
        _ = discarded
        self.root = self._merge(before, after)
        self._markers_after_delete(start, end)
        self._bump_version()
        return removed^

    def replace(mut self, start: Int, end: Int, var text: String) raises -> String:
        """Atomically replace one range and advance the version once."""
        self._validate_range(start, end)
        if start == end and text == "":
            return ""
        self._ensure_version_available()
        var removed = self.slice(start, end)

        var before, tail = self._split(self.root, start)
        var discarded, after = self._split(tail, end - start)
        _ = discarded
        self.root = self._merge(before, after)
        if end > start:
            self._markers_after_delete(start, end)

        if text != "":
            var add_start = self.additions.byte_length()
            var byte_length = text.byte_length()
            self.additions += text
            var inserted = self._tree_for_range(PieceSource.ADD, add_start, byte_length)
            var prefix, suffix = self._split(self.root, start)
            self.root = self._merge(self._merge(prefix, inserted), suffix)
            self._markers_after_insert(start, byte_length)
        self._bump_version()
        return removed^

    def _markers_after_insert(mut self, offset: Int, byte_length: Int):
        for index in range(len(self.markers)):
            if not self.markers[index].active:
                continue
            if self.markers[index].offset > offset or (
                self.markers[index].offset == offset
                and self.markers[index].affinity == MarkerAffinity.AFTER
            ):
                self.markers[index].offset += byte_length

    def _markers_after_delete(mut self, start: Int, end: Int):
        var removed = end - start
        for index in range(len(self.markers)):
            if not self.markers[index].active:
                continue
            if self.markers[index].offset >= end:
                self.markers[index].offset -= removed
            elif self.markers[index].offset >= start:
                self.markers[index].offset = start

    def _marker_index(self, id: MarkerId) -> Int:
        for index in range(len(self.markers)):
            if self.markers[index].active and self.markers[index].id.value == id.value:
                return index
        return -1

    def create_marker(
        mut self,
        offset: Int,
        affinity: MarkerAffinity = MarkerAffinity.AFTER,
    ) raises -> MarkerId:
        self._validate_range(offset, offset)
        if self.next_marker_id == Int.MAX:
            raise Error("document marker IDs exhausted")
        var id = MarkerId(self.next_marker_id)
        self.next_marker_id += 1
        self.markers.append(_Marker(id, offset, affinity))
        return id^

    def marker_offset(self, id: MarkerId) raises -> Int:
        var index = self._marker_index(id)
        if index < 0:
            raise Error("document marker is not active")
        return self.markers[index].offset

    def remove_marker(mut self, id: MarkerId) -> Bool:
        var index = self._marker_index(id)
        if index < 0:
            return False
        self.markers[index].active = False
        return True

    def active_marker_count(self) -> Int:
        var count = 0
        for index in range(len(self.markers)):
            if self.markers[index].active:
                count += 1
        return count

    def line_of_offset(self, offset: Int) raises -> Int:
        """Return the zero-based line containing a canonical byte offset."""
        self._validate_range(offset, offset)
        var node = self.root
        var remaining = offset
        var lines = 0
        while node >= 0:
            var left = self.nodes[node].left
            var left_bytes = self._bytes(left)
            if remaining < left_bytes:
                node = left
                continue
            lines += self._newlines(left)
            remaining -= left_bytes
            var piece = self.nodes[node].piece.copy()
            if remaining <= piece.byte_length:
                for relative in range(min(remaining, piece.byte_length)):
                    if self._source_byte(piece.source, piece.start + relative) == UInt8(
                        0x0A
                    ):
                        lines += 1
                return lines
            lines += piece.newlines
            remaining -= piece.byte_length
            node = self.nodes[node].right
        return lines

    def line_start(self, line: Int) raises -> Int:
        """Locate a line start using subtree newline caches."""
        if line < 0 or line >= self.line_count():
            raise Error("document line is out of bounds")
        if line == 0:
            return 0
        var node = self.root
        var needed = line
        var subtree_start = 0
        while node >= 0:
            var left = self.nodes[node].left
            var left_newlines = self._newlines(left)
            if needed <= left_newlines:
                node = left
                continue
            needed -= left_newlines
            var left_bytes = self._bytes(left)
            var piece = self.nodes[node].piece.copy()
            var piece_start = subtree_start + left_bytes
            if needed <= piece.newlines:
                for relative in range(piece.byte_length):
                    if self._source_byte(piece.source, piece.start + relative) == UInt8(
                        0x0A
                    ):
                        needed -= 1
                        if needed == 0:
                            return piece_start + relative + 1
            needed -= piece.newlines
            subtree_start = piece_start + piece.byte_length
            node = self.nodes[node].right
        raise Error("document line cache is inconsistent")

    def line_end(self, line: Int) raises -> Int:
        if line < 0 or line >= self.line_count():
            raise Error("document line is out of bounds")
        if line + 1 == self.line_count():
            return self.byte_length()
        return self.line_start(line + 1) - 1

    def line_text(self, line: Int) raises -> String:
        return self.slice(self.line_start(line), self.line_end(line))

    def position_at(self, offset: Int) raises -> TextPosition:
        self._validate_range(offset, offset)
        var line = self.line_of_offset(offset)
        var start = self.line_start(line)
        return TextPosition(offset, line, offset - start)

    def offset_at(self, line: Int, byte_column: Int) raises -> Int:
        var start = self.line_start(line)
        var end = self.line_end(line)
        if byte_column < 0 or byte_column > end - start:
            raise Error("document byte column is out of bounds")
        var offset = start + byte_column
        if not self.is_utf8_boundary(offset):
            raise Error("document byte column splits a UTF-8 code point")
        return offset

    def _height(self, node: Int) -> Int:
        if node < 0:
            return 0
        return 1 + max(
            self._height(self.nodes[node].left),
            self._height(self.nodes[node].right),
        )

    def tree_height(self) -> Int:
        return self._height(self.root)

    def _validate_node(self, node: Int) raises -> Tuple[Int, Int, Int]:
        if node < 0:
            return 0, 0, 0
        if node >= len(self.nodes):
            raise Error("piece-tree child index is invalid")
        var left = self.nodes[node].left
        var right = self.nodes[node].right
        if left >= 0 and self.nodes[left].priority < self.nodes[node].priority:
            raise Error(
                "piece-tree left heap invariant failed at node ",
                String(node),
                " parent=",
                String(self.nodes[node].priority),
                " child=",
                String(self.nodes[left].priority),
            )
        if right >= 0 and self.nodes[right].priority < self.nodes[node].priority:
            raise Error(
                "piece-tree right heap invariant failed at node ",
                String(node),
                " parent=",
                String(self.nodes[node].priority),
                " child=",
                String(self.nodes[right].priority),
            )
        var left_bytes, left_newlines, left_pieces = self._validate_node(left)
        var right_bytes, right_newlines, right_pieces = self._validate_node(right)
        var expected_bytes = (
            left_bytes + self.nodes[node].piece.byte_length + right_bytes
        )
        var expected_newlines = (
            left_newlines + self.nodes[node].piece.newlines + right_newlines
        )
        var expected_pieces = left_pieces + 1 + right_pieces
        if (
            expected_bytes != self.nodes[node].subtree_bytes
            or expected_newlines != self.nodes[node].subtree_newlines
            or expected_pieces != self.nodes[node].subtree_pieces
        ):
            raise Error("piece-tree cached metrics are inconsistent")
        return expected_bytes, expected_newlines, expected_pieces

    def validate(self) raises:
        """Check indices, heap ordering, and every cached subtree metric."""
        var bytes, newlines, pieces = self._validate_node(self.root)
        if (
            bytes != self.byte_length()
            or newlines != self.newline_count()
            or pieces != self.piece_count()
        ):
            raise Error("piece-tree root metrics are inconsistent")
