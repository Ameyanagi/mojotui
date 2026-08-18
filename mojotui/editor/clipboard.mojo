"""Pluggable clipboard contracts and bounded OSC 52 copy support."""

from std.io import FileDescriptor


comptime _BASE64_ALPHABET = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
)


trait Clipboard(Deinitable, Movable):
    """A text clipboard supplied to editor commands by the application host."""

    def read(self) raises -> String:
        ...

    def write(mut self, var text: String) raises:
        ...


struct MemoryClipboard(Clipboard, Copyable):
    """An owned clipboard for tests, headless apps, and fallback behavior."""

    var content: String

    def __init__(out self, var content: String = ""):
        self.content = content^

    def read(self) raises -> String:
        return self.content.copy()

    def write(mut self, var text: String) raises:
        self.content = text^


def _base64_symbol(index: Int) -> String:
    return String(_BASE64_ALPHABET[byte = index : index + 1])


def encode_base64(var text: String) -> String:
    """Encode UTF-8 bytes without Python, FFI, or unsafe storage."""
    var result = String()
    var bytes = text.as_bytes()
    var cursor = 0
    while cursor + 3 <= len(bytes):
        var first = Int(bytes[cursor])
        var second = Int(bytes[cursor + 1])
        var third = Int(bytes[cursor + 2])
        result += _base64_symbol(first >> 2)
        result += _base64_symbol(((first & 0x03) << 4) | (second >> 4))
        result += _base64_symbol(((second & 0x0F) << 2) | (third >> 6))
        result += _base64_symbol(third & 0x3F)
        cursor += 3

    var remaining = len(bytes) - cursor
    if remaining == 1:
        var first = Int(bytes[cursor])
        result += _base64_symbol(first >> 2)
        result += _base64_symbol((first & 0x03) << 4)
        result += "=="
    elif remaining == 2:
        var first = Int(bytes[cursor])
        var second = Int(bytes[cursor + 1])
        result += _base64_symbol(first >> 2)
        result += _base64_symbol(((first & 0x03) << 4) | (second >> 4))
        result += _base64_symbol((second & 0x0F) << 2)
        result += "="
    return result^


def osc52_copy_sequence(var text: String, max_bytes: Int = 100_000) raises -> String:
    """Build a clipboard-copy sequence after enforcing a UTF-8 byte limit."""
    if max_bytes < 0:
        raise Error("OSC 52 maximum byte count must be non-negative")
    if text.byte_length() > max_bytes:
        raise Error(
            "OSC 52 clipboard payload exceeds ",
            String(max_bytes),
            " bytes",
        )
    return "\x1b]52;c;" + encode_base64(text^) + "\x1b\\"


struct Osc52Clipboard(Clipboard):
    """Explicit, bounded terminal clipboard writer.

    OSC 52 has no synchronous, portable read operation. `read()` therefore
    returns only the last value copied through this provider. Paste from an
    external system clipboard should be supplied by another host adapter.
    """

    var output_descriptor: Int
    var max_bytes: Int
    var content: String

    def __init__(
        out self,
        output_descriptor: Int = 1,
        max_bytes: Int = 100_000,
    ) raises:
        if output_descriptor < 0:
            raise Error("OSC 52 output descriptor must be non-negative")
        if max_bytes < 0:
            raise Error("OSC 52 maximum byte count must be non-negative")
        self.output_descriptor = output_descriptor
        self.max_bytes = max_bytes
        self.content = ""

    def read(self) raises -> String:
        return self.content.copy()

    def write(mut self, var text: String) raises:
        var sequence = osc52_copy_sequence(text.copy(), self.max_bytes)
        var output = FileDescriptor(self.output_descriptor)
        output.write_string(sequence)
        self.content = text^


def clipboard_round_trip[
    C: Clipboard
](mut clipboard: C, var text: String) raises -> String:
    """Exercise a concrete clipboard through static generic dispatch."""
    clipboard.write(text^)
    return clipboard.read()
