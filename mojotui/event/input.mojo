"""A safe incremental parser for terminal input byte streams."""

from std.collections import List
from std.utils import Variant


struct KeyEvent(Copyable):
    """A keyboard event with a semantic key code and modifier mask."""

    comptime CHARACTER = 0
    comptime ESCAPE = 1
    comptime ENTER = 2
    comptime TAB = 3
    comptime BACKSPACE = 4
    comptime UP = 5
    comptime DOWN = 6
    comptime RIGHT = 7
    comptime LEFT = 8
    comptime HOME = 9
    comptime END = 10
    comptime INSERT = 11
    comptime DELETE = 12
    comptime PAGE_UP = 13
    comptime PAGE_DOWN = 14

    comptime SHIFT = 1
    comptime ALT = 2
    comptime CONTROL = 4

    var code: Int
    var text: String
    var modifiers: Int

    def __init__(out self, code: Int, var text: String = "", modifiers: Int = 0):
        self.code = code
        self.text = text^
        self.modifiers = modifiers

    @staticmethod
    def character(var text: String, modifiers: Int = 0) -> Self:
        return Self(Self.CHARACTER, text^, modifiers)

    @staticmethod
    def named(code: Int, modifiers: Int = 0) -> Self:
        return Self(code, modifiers=modifiers)


struct PasteEvent(Copyable):
    """Text received between bracketed-paste delimiters."""

    var text: String

    def __init__(out self, var text: String):
        self.text = text^


struct FocusEvent(Copyable):
    """A terminal focus transition."""

    var focused: Bool

    def __init__(out self, focused: Bool):
        self.focused = focused


struct MouseEvent(Copyable):
    """An SGR mouse event in zero-based terminal coordinates."""

    comptime PRESS = 0
    comptime RELEASE = 1
    comptime MOVE = 2
    comptime SCROLL_UP = 3
    comptime SCROLL_DOWN = 4

    comptime NONE = -1
    comptime LEFT = 0
    comptime MIDDLE = 1
    comptime RIGHT = 2

    var kind: Int
    var button: Int
    var x: Int
    var y: Int
    var modifiers: Int

    def __init__(
        out self,
        kind: Int,
        button: Int,
        x: Int,
        y: Int,
        modifiers: Int = 0,
    ):
        self.kind = kind
        self.button = button
        self.x = x
        self.y = y
        self.modifiers = modifiers


struct UnknownEvent(Copyable):
    """A complete but unsupported terminal control sequence."""

    var sequence: String

    def __init__(out self, var sequence: String):
        self.sequence = sequence^


comptime InputEvent = Variant[
    KeyEvent, PasteEvent, FocusEvent, MouseEvent, UnknownEvent
]


struct InputParser(Movable):
    """Incrementally parse fragmented and combined terminal input."""

    var pending: List[UInt8]
    var cursor: Int
    var paste_bytes: List[UInt8]
    var in_paste: Bool

    def __init__(out self):
        self.pending = List[UInt8]()
        self.cursor = 0
        self.paste_bytes = List[UInt8]()
        self.in_paste = False

    def pending_byte_count(self) -> Int:
        return len(self.pending) - self.cursor

    def feed(mut self, var bytes: List[UInt8]) -> List[InputEvent]:
        """Consume available bytes and retain incomplete sequences."""
        self.pending.extend(bytes^)
        var events = List[InputEvent]()
        while self._parse_one(events):
            pass
        self._compact()
        return events^

    def flush_escape(mut self) -> List[InputEvent]:
        """Resolve a pending Escape prefix after the configured timeout."""
        var events = List[InputEvent]()
        if self.pending_byte_count() > 0 and self._byte(0) == 0x1B:
            self._consume(1)
            events.append(InputEvent(KeyEvent.named(KeyEvent.ESCAPE)))
        while self._parse_one(events):
            pass
        self._compact()
        return events^

    def _byte(self, offset: Int) -> UInt8:
        return self.pending[self.cursor + offset]

    def _consume(mut self, count: Int):
        self.cursor += count

    def _compact(mut self):
        if self.cursor == 0:
            return
        if self.cursor < 4096 and self.cursor * 2 < len(self.pending):
            return
        var remaining = List[UInt8](capacity=self.pending_byte_count())
        for index in range(self.cursor, len(self.pending)):
            remaining.append(self.pending[index])
        self.pending = remaining^
        self.cursor = 0

    def _slice_string(self, offset: Int, count: Int) -> String:
        return String(
            from_utf8_lossy=self.pending[
                self.cursor + offset : self.cursor + offset + count
            ]
        )

    def _paste_string(self) -> String:
        return String(from_utf8_lossy=self.paste_bytes)

    def _matches_paste_delimiter(self, offset: Int, final_digit: Int) -> Bool:
        return (
            self.pending_byte_count() >= offset + 6
            and Int(self._byte(offset)) == 0x1B
            and Int(self._byte(offset + 1)) == 0x5B
            and Int(self._byte(offset + 2)) == 0x32
            and Int(self._byte(offset + 3)) == 0x30
            and Int(self._byte(offset + 4)) == final_digit
            and Int(self._byte(offset + 5)) == 0x7E
        )

    def _complete_utf8_length(self, offset: Int) -> Int:
        """Return zero for incomplete input and one for an invalid lead byte."""
        var first = Int(self._byte(offset))
        if first < 0x80:
            return 1
        var expected: Int
        if first >= 0xC2 and first <= 0xDF:
            expected = 2
        elif first >= 0xE0 and first <= 0xEF:
            expected = 3
        elif first >= 0xF0 and first <= 0xF4:
            expected = 4
        else:
            return 1

        var available = self.pending_byte_count() - offset
        var provided = expected if available >= expected else available
        for index in range(1, provided):
            var continuation = Int(self._byte(offset + index))
            if continuation < 0x80 or continuation > 0xBF:
                return 1
        if available < expected:
            return 0

        var second = Int(self._byte(offset + 1))
        if first == 0xE0 and second < 0xA0:
            return 1
        if first == 0xED and second > 0x9F:
            return 1
        if first == 0xF0 and second < 0x90:
            return 1
        if first == 0xF4 and second > 0x8F:
            return 1
        return expected

    def _append_character(
        mut self,
        mut events: List[InputEvent],
        offset: Int = 0,
        modifiers: Int = 0,
    ) -> Bool:
        if self.pending_byte_count() <= offset:
            return False
        var length = self._complete_utf8_length(offset)
        if length == 0:
            return False
        var text = self._slice_string(offset, length)
        self._consume(offset + length)
        events.append(InputEvent(KeyEvent.character(text^, modifiers)))
        return True

    def _append_control_character(mut self, mut events: List[InputEvent], value: Int):
        var bytes = List[UInt8]()
        bytes.append(UInt8(value + 0x60))
        var text = String(from_utf8_lossy=bytes)
        self._consume(1)
        events.append(InputEvent(KeyEvent.character(text^, modifiers=KeyEvent.CONTROL)))

    def _parse_paste(mut self, mut events: List[InputEvent]) -> Bool:
        if self.pending_byte_count() == 0:
            return False
        if Int(self._byte(0)) == 0x1B and self.pending_byte_count() < 6:
            return False
        if self._matches_paste_delimiter(0, 0x31):
            self._consume(6)
            var text = self._paste_string()
            self.paste_bytes.clear()
            self.in_paste = False
            events.append(InputEvent(PasteEvent(text^)))
            return True
        self.paste_bytes.append(self._byte(0))
        self._consume(1)
        return True

    def _csi_length(self) -> Int:
        if self.pending_byte_count() < 3:
            return 0
        for offset in range(2, self.pending_byte_count()):
            var value = Int(self._byte(offset))
            if value >= 0x40 and value <= 0x7E:
                return offset + 1
        return 0

    def _key_code_for_final(self, final: Int) -> Int:
        if final == 0x41:
            return KeyEvent.UP
        if final == 0x42:
            return KeyEvent.DOWN
        if final == 0x43:
            return KeyEvent.RIGHT
        if final == 0x44:
            return KeyEvent.LEFT
        if final == 0x48:
            return KeyEvent.HOME
        if final == 0x46:
            return KeyEvent.END
        return -1

    def _decimal(self, start: Int, end: Int) -> Int:
        if start >= end:
            return -1
        var value = 0
        for offset in range(start, end):
            var digit = Int(self._byte(offset)) - 0x30
            if digit < 0 or digit > 9:
                return -1
            if value > (Int.MAX - digit) // 10:
                return -1
            value = value * 10 + digit
        return value

    def _parse_sgr_mouse(mut self, mut events: List[InputEvent], length: Int) -> Bool:
        if length < 9 or Int(self._byte(2)) != 0x3C:
            return False
        var first_separator = -1
        var second_separator = -1
        for offset in range(3, length - 1):
            if Int(self._byte(offset)) == 0x3B:
                if first_separator < 0:
                    first_separator = offset
                elif second_separator < 0:
                    second_separator = offset
                else:
                    return False
        if first_separator < 0 or second_separator < 0:
            return False

        var encoded = self._decimal(3, first_separator)
        var column = self._decimal(first_separator + 1, second_separator)
        var row = self._decimal(second_separator + 1, length - 1)
        if encoded < 0 or column <= 0 or row <= 0:
            return False

        var modifiers = 0
        if encoded & 4:
            modifiers |= KeyEvent.SHIFT
        if encoded & 8:
            modifiers |= KeyEvent.ALT
        if encoded & 16:
            modifiers |= KeyEvent.CONTROL

        var low_button = encoded & 3
        var button = low_button if low_button < 3 else MouseEvent.NONE
        var kind = MouseEvent.PRESS
        var final = Int(self._byte(length - 1))
        if encoded & 64:
            kind = MouseEvent.SCROLL_UP if low_button == 0 else MouseEvent.SCROLL_DOWN
            button = MouseEvent.NONE
        elif final == 0x6D:
            kind = MouseEvent.RELEASE
        elif encoded & 32:
            kind = MouseEvent.MOVE

        self._consume(length)
        events.append(
            InputEvent(MouseEvent(kind, button, column - 1, row - 1, modifiers))
        )
        return True

    def _parse_csi(mut self, mut events: List[InputEvent]) -> Bool:
        var length = self._csi_length()
        if length == 0:
            return False

        if self._parse_sgr_mouse(events, length):
            return True

        if length == 3:
            var final = Int(self._byte(2))
            var code = self._key_code_for_final(final)
            if code >= 0:
                self._consume(length)
                events.append(InputEvent(KeyEvent.named(code)))
                return True
            if final == 0x5A:
                self._consume(length)
                events.append(InputEvent(KeyEvent.named(KeyEvent.TAB, KeyEvent.SHIFT)))
                return True
            if final == 0x49 or final == 0x4F:
                self._consume(length)
                events.append(InputEvent(FocusEvent(final == 0x49)))
                return True

        if length == 4 and Int(self._byte(2)) >= 0x31:
            var final = Int(self._byte(3))
            if final == 0x7E:
                var parameter = Int(self._byte(2)) - 0x30
                var code = -1
                if parameter == 1:
                    code = KeyEvent.HOME
                elif parameter == 2:
                    code = KeyEvent.INSERT
                elif parameter == 3:
                    code = KeyEvent.DELETE
                elif parameter == 4:
                    code = KeyEvent.END
                elif parameter == 5:
                    code = KeyEvent.PAGE_UP
                elif parameter == 6:
                    code = KeyEvent.PAGE_DOWN
                if code >= 0:
                    self._consume(length)
                    events.append(InputEvent(KeyEvent.named(code)))
                    return True

        if length == 6 and Int(self._byte(2)) == 0x31 and Int(self._byte(3)) == 0x3B:
            var modifier_parameter = Int(self._byte(4)) - 0x30
            var code = self._key_code_for_final(Int(self._byte(5)))
            if modifier_parameter >= 2 and modifier_parameter <= 8 and code >= 0:
                self._consume(length)
                events.append(InputEvent(KeyEvent.named(code, modifier_parameter - 1)))
                return True

        if length == 6 and self._matches_paste_delimiter(0, 0x30):
            self._consume(length)
            self.paste_bytes.clear()
            self.in_paste = True
            return True

        var sequence = self._slice_string(0, length)
        self._consume(length)
        events.append(InputEvent(UnknownEvent(sequence^)))
        return True

    def _parse_escape(mut self, mut events: List[InputEvent]) -> Bool:
        if self.pending_byte_count() == 1:
            return False
        if Int(self._byte(1)) == 0x5B:
            return self._parse_csi(events)
        if Int(self._byte(1)) == 0x1B:
            self._consume(1)
            events.append(InputEvent(KeyEvent.named(KeyEvent.ESCAPE)))
            return True
        return self._append_character(events, offset=1, modifiers=KeyEvent.ALT)

    def _parse_one(mut self, mut events: List[InputEvent]) -> Bool:
        if self.in_paste:
            return self._parse_paste(events)
        if self.pending_byte_count() == 0:
            return False

        var first = Int(self._byte(0))
        if first == 0x1B:
            return self._parse_escape(events)
        if first == 0x0D or first == 0x0A:
            self._consume(1)
            events.append(InputEvent(KeyEvent.named(KeyEvent.ENTER)))
            return True
        if first == 0x09:
            self._consume(1)
            events.append(InputEvent(KeyEvent.named(KeyEvent.TAB)))
            return True
        if first == 0x7F or first == 0x08:
            self._consume(1)
            events.append(InputEvent(KeyEvent.named(KeyEvent.BACKSPACE)))
            return True
        if first >= 0x01 and first <= 0x1A:
            self._append_control_character(events, first)
            return True
        return self._append_character(events)
