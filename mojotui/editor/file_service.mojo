"""UTF-8 file loading, metadata checks, and POSIX atomic replacement."""

from std.collections import Optional
from std.pathlib import Path

from ..platform import atomic_replace_file


struct LineEnding(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal newline encoding preserved during file round trips."""

    comptime LF = LineEnding(0, _validated=True)
    comptime CRLF = LineEnding(1, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 1:
            raise Error(String("file line ending must be within [0, 1]; got ", value))
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct FileMetadata(Copyable):
    """Identity and modification fields used for external-change checks."""

    var device: Int
    var inode: Int
    var size: Int
    var modified_ns: Int

    def __init__(out self, device: Int, inode: Int, size: Int, modified_ns: Int):
        self.device = device
        self.inode = inode
        self.size = size
        self.modified_ns = modified_ns

    def equals(self, other: Self) -> Bool:
        return (
            self.device == other.device
            and self.inode == other.inode
            and self.size == other.size
            and self.modified_ns == other.modified_ns
        )


struct LoadedFile(Copyable):
    """Normalized editor text plus round-trip format and filesystem metadata."""

    var content: String
    var line_ending: LineEnding
    var had_bom: Bool
    var metadata: FileMetadata

    def __init__(
        out self,
        var content: String,
        line_ending: LineEnding,
        had_bom: Bool,
        metadata: FileMetadata,
    ):
        self.content = content^
        self.line_ending = line_ending
        self.had_bom = had_bom
        self.metadata = metadata.copy()


struct SaveOptions(Copyable):
    """Round-trip formatting and optional optimistic-concurrency check."""

    var line_ending: LineEnding
    var write_bom: Bool
    var expected: Optional[FileMetadata]

    def __init__(
        out self,
        line_ending: LineEnding = LineEnding.LF,
        write_bom: Bool = False,
        expected: Optional[FileMetadata] = None,
    ):
        self.line_ending = line_ending
        self.write_bom = write_bom
        self.expected = expected.copy()


trait _FileReader(Deinitable, Movable):
    """Internal deterministic seam for observing changes around a text read."""

    def metadata(mut self, path: StringSlice) raises -> FileMetadata:
        ...

    def read_text(mut self, path: StringSlice) raises -> String:
        ...


struct _LocalFileReader(_FileReader):
    def __init__(out self):
        pass

    def metadata(mut self, path: StringSlice) raises -> FileMetadata:
        return _file_metadata(path)

    def read_text(mut self, path: StringSlice) raises -> String:
        return Path(path).read_text()


def _file_metadata(path: StringSlice) raises -> FileMetadata:
    var observed = Path(path).stat()
    return FileMetadata(
        observed.st_dev,
        observed.st_ino,
        observed.st_size,
        observed.st_mtimespec.as_nanoseconds(),
    )


def _load_with_reader[
    Reader: _FileReader
](mut reader: Reader, path: StringSlice) raises -> LoadedFile:
    var before = reader.metadata(path)
    var raw = reader.read_text(path)
    var after = reader.metadata(path)
    if not before.equals(after):
        raise Error(String("file '", path, "' changed while loading; retry the load"))
    var had_bom = raw.startswith("﻿")
    var content = String(raw[byte=3:]) if had_bom else raw.copy()
    var line_ending = LineEnding.CRLF if "\r\n" in content else LineEnding.LF
    if line_ending == LineEnding.CRLF:
        content = content.replace("\r\n", "\n")
    return LoadedFile(content^, line_ending, had_bom, after)


struct LocalFileService(Copyable):
    """Safe standard-library I/O plus one audited POSIX atomic rename."""

    def __init__(out self):
        pass

    def metadata(self, path: StringSlice) raises -> FileMetadata:
        return _file_metadata(path)

    def load(self, path: StringSlice) raises -> LoadedFile:
        """Reject a changed identity, size, or mtime across the complete read.

        This is optimistic observation, not a lock against concurrent writers.
        The returned metadata belongs to the observed stable file version and
        can be passed to SaveOptions.expected to reject subsequent changes.
        """
        var reader = _LocalFileReader()
        return _load_with_reader(reader, path)

    def has_external_change(
        self, path: StringSlice, expected: FileMetadata
    ) raises -> Bool:
        if not Path(path).exists():
            return True
        return not self.metadata(path).equals(expected)

    def serialize(self, var content: String, options: SaveOptions) -> String:
        var result = (
            content.replace("\n", "\r\n") if options.line_ending
            == LineEnding.CRLF else content.copy()
        )
        if options.write_bom:
            result = "﻿" + result
        return result^

    def save_atomic(
        self,
        var path: String,
        var temporary_path: String,
        var content: String,
        options: SaveOptions = SaveOptions(),
    ) raises -> FileMetadata:
        """Write a prepared sibling then atomically replace the destination.

        The caller chooses a unique temporary path in the destination's
        directory. A failed rename leaves that path intact for recovery.
        """
        if path == temporary_path:
            raise Error("atomic save temporary path equals destination")
        if options.expected and self.has_external_change(
            path, options.expected.value()
        ):
            raise Error("file changed externally before save")
        var serialized = self.serialize(content^, options)
        Path(temporary_path).write_text(serialized)
        atomic_replace_file(temporary_path.copy(), path.copy())
        return self.metadata(path)
