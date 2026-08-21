"""A safe incremental parser for terminal input byte streams."""

from std.collections import List, Optional
from std.utils import Variant


struct KeyCode(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal semantic keyboard code independent of terminal bytes."""

    comptime CHARACTER = KeyCode(0, _validated=True)
    comptime ESCAPE = KeyCode(1, _validated=True)
    comptime ENTER = KeyCode(2, _validated=True)
    comptime TAB = KeyCode(3, _validated=True)
    comptime BACKSPACE = KeyCode(4, _validated=True)
    comptime UP = KeyCode(5, _validated=True)
    comptime DOWN = KeyCode(6, _validated=True)
    comptime RIGHT = KeyCode(7, _validated=True)
    comptime LEFT = KeyCode(8, _validated=True)
    comptime HOME = KeyCode(9, _validated=True)
    comptime END = KeyCode(10, _validated=True)
    comptime INSERT = KeyCode(11, _validated=True)
    comptime DELETE = KeyCode(12, _validated=True)
    comptime PAGE_UP = KeyCode(13, _validated=True)
    comptime PAGE_DOWN = KeyCode(14, _validated=True)
    comptime F1 = KeyCode(15, _validated=True)
    comptime F2 = KeyCode(16, _validated=True)
    comptime F3 = KeyCode(17, _validated=True)
    comptime F4 = KeyCode(18, _validated=True)
    comptime F5 = KeyCode(19, _validated=True)
    comptime F6 = KeyCode(20, _validated=True)
    comptime F7 = KeyCode(21, _validated=True)
    comptime F8 = KeyCode(22, _validated=True)
    comptime F9 = KeyCode(23, _validated=True)
    comptime F10 = KeyCode(24, _validated=True)
    comptime F11 = KeyCode(25, _validated=True)
    comptime F12 = KeyCode(26, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 26:
            raise Error(
                "invalid key code: argument 'value' was ",
                String(value),
                "; accepted range is 0..26",
            )
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct KeyModifiers(Copyable, Equatable, ImplicitlyCopyable):
    """Validated set of keyboard modifier flags."""

    comptime NONE = KeyModifiers(0, _validated=True)
    comptime SHIFT = KeyModifiers(1, _validated=True)
    comptime ALT = KeyModifiers(2, _validated=True)
    comptime CONTROL = KeyModifiers(4, _validated=True)

    var _bits: Int

    def __init__(out self, bits: Int, *, _validated: Bool):
        self._bits = bits

    def __init__(out self, bits: Int) raises:
        if bits < 0 or (bits & ~7) != 0:
            raise Error("invalid key modifier flags")
        self._bits = bits

    def __eq__(self, other: Self) -> Bool:
        return self._bits == other._bits

    def contains(self, modifier: Self) -> Bool:
        return (self._bits & modifier._bits) == modifier._bits

    def union(self, modifier: Self) -> Self:
        return Self(self._bits | modifier._bits, _validated=True)


struct KeyEventKind(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal semantic kind of a keyboard event."""

    comptime PRESS = KeyEventKind(_value=0)
    comptime REPEAT = KeyEventKind(_value=1)
    comptime RELEASE = KeyEventKind(_value=2)

    var _value: Int

    def __init__(out self, *, _value: Int):
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct KeyEvent(Copyable):
    """A keyboard event with a semantic key code, modifiers, and event kind."""

    comptime CHARACTER = KeyCode.CHARACTER
    comptime ESCAPE = KeyCode.ESCAPE
    comptime ENTER = KeyCode.ENTER
    comptime TAB = KeyCode.TAB
    comptime BACKSPACE = KeyCode.BACKSPACE
    comptime UP = KeyCode.UP
    comptime DOWN = KeyCode.DOWN
    comptime RIGHT = KeyCode.RIGHT
    comptime LEFT = KeyCode.LEFT
    comptime HOME = KeyCode.HOME
    comptime END = KeyCode.END
    comptime INSERT = KeyCode.INSERT
    comptime DELETE = KeyCode.DELETE
    comptime PAGE_UP = KeyCode.PAGE_UP
    comptime PAGE_DOWN = KeyCode.PAGE_DOWN
    comptime F1 = KeyCode.F1
    comptime F2 = KeyCode.F2
    comptime F3 = KeyCode.F3
    comptime F4 = KeyCode.F4
    comptime F5 = KeyCode.F5
    comptime F6 = KeyCode.F6
    comptime F7 = KeyCode.F7
    comptime F8 = KeyCode.F8
    comptime F9 = KeyCode.F9
    comptime F10 = KeyCode.F10
    comptime F11 = KeyCode.F11
    comptime F12 = KeyCode.F12

    comptime NO_MODIFIERS = KeyModifiers.NONE
    comptime SHIFT = KeyModifiers.SHIFT
    comptime ALT = KeyModifiers.ALT
    comptime CONTROL = KeyModifiers.CONTROL

    comptime PRESS = KeyEventKind.PRESS
    comptime REPEAT = KeyEventKind.REPEAT
    comptime RELEASE = KeyEventKind.RELEASE

    var code: KeyCode
    var text: String
    var modifiers: KeyModifiers
    var kind: KeyEventKind

    def __init__(
        out self,
        code: KeyCode,
        var text: String = "",
        modifiers: KeyModifiers = KeyModifiers.NONE,
        *,
        kind: KeyEventKind = KeyEventKind.PRESS,
    ):
        self.code = code
        self.text = text^
        self.modifiers = modifiers
        self.kind = kind

    @staticmethod
    def character(
        var text: String,
        modifiers: KeyModifiers = KeyModifiers.NONE,
        *,
        kind: KeyEventKind = KeyEventKind.PRESS,
    ) -> Self:
        return Self(Self.CHARACTER, text^, modifiers, kind=kind)

    @staticmethod
    def named(
        code: KeyCode,
        modifiers: KeyModifiers = KeyModifiers.NONE,
        *,
        kind: KeyEventKind = KeyEventKind.PRESS,
    ) -> Self:
        return Self(code, modifiers=modifiers, kind=kind)


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


struct MouseKind(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal semantic kind of an SGR mouse event."""

    comptime PRESS = MouseKind(0, _validated=True)
    comptime RELEASE = MouseKind(1, _validated=True)
    comptime MOVE = MouseKind(2, _validated=True)
    comptime SCROLL_UP = MouseKind(3, _validated=True)
    comptime SCROLL_DOWN = MouseKind(4, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 4:
            raise Error("invalid mouse event kind")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct MouseButton(Copyable, Equatable, ImplicitlyCopyable):
    """Nominal physical mouse button; absence is represented by `None`."""

    comptime LEFT = MouseButton(0, _validated=True)
    comptime MIDDLE = MouseButton(1, _validated=True)
    comptime RIGHT = MouseButton(2, _validated=True)

    var _value: Int

    def __init__(out self, value: Int, *, _validated: Bool):
        self._value = value

    def __init__(out self, value: Int) raises:
        if value < 0 or value > 2:
            raise Error("invalid mouse button")
        self._value = value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


struct MouseEvent(Copyable):
    """An SGR mouse event in zero-based terminal coordinates."""

    comptime PRESS = MouseKind.PRESS
    comptime RELEASE = MouseKind.RELEASE
    comptime MOVE = MouseKind.MOVE
    comptime SCROLL_UP = MouseKind.SCROLL_UP
    comptime SCROLL_DOWN = MouseKind.SCROLL_DOWN

    comptime LEFT = MouseButton.LEFT
    comptime MIDDLE = MouseButton.MIDDLE
    comptime RIGHT = MouseButton.RIGHT

    var kind: MouseKind
    var button: Optional[MouseButton]
    var x: Int
    var y: Int
    var modifiers: KeyModifiers

    def __init__(
        out self,
        kind: MouseKind,
        button: Optional[MouseButton],
        x: Int,
        y: Int,
        modifiers: KeyModifiers = KeyModifiers.NONE,
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
        modifiers: KeyModifiers = KeyModifiers.NONE,
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

    def _key_code_for_final(self, final: Int) -> Optional[KeyCode]:
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
        return None

    def _function_key_code_for_final(self, final: Int) -> Optional[KeyCode]:
        if final == 0x50:
            return KeyEvent.F1
        if final == 0x51:
            return KeyEvent.F2
        if final == 0x52:
            return KeyEvent.F3
        if final == 0x53:
            return KeyEvent.F4
        return None

    def _key_code_for_tilde_parameter(self, parameter: Int) -> Optional[KeyCode]:
        if parameter == 1:
            return KeyEvent.HOME
        if parameter == 2:
            return KeyEvent.INSERT
        if parameter == 3:
            return KeyEvent.DELETE
        if parameter == 4:
            return KeyEvent.END
        if parameter == 5:
            return KeyEvent.PAGE_UP
        if parameter == 6:
            return KeyEvent.PAGE_DOWN
        if parameter == 11:
            return KeyEvent.F1
        if parameter == 12:
            return KeyEvent.F2
        if parameter == 13:
            return KeyEvent.F3
        if parameter == 14:
            return KeyEvent.F4
        if parameter == 15:
            return KeyEvent.F5
        if parameter == 17:
            return KeyEvent.F6
        if parameter == 18:
            return KeyEvent.F7
        if parameter == 19:
            return KeyEvent.F8
        if parameter == 20:
            return KeyEvent.F9
        if parameter == 21:
            return KeyEvent.F10
        if parameter == 23:
            return KeyEvent.F11
        if parameter == 24:
            return KeyEvent.F12
        return None

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

        var modifiers = KeyModifiers.NONE
        if encoded & 4:
            modifiers = modifiers.union(KeyEvent.SHIFT)
        if encoded & 8:
            modifiers = modifiers.union(KeyEvent.ALT)
        if encoded & 16:
            modifiers = modifiers.union(KeyEvent.CONTROL)

        var low_button = encoded & 3
        var button: Optional[MouseButton] = None
        if low_button == 0:
            button = MouseEvent.LEFT
        elif low_button == 1:
            button = MouseEvent.MIDDLE
        elif low_button == 2:
            button = MouseEvent.RIGHT
        var kind = MouseEvent.PRESS
        var final = Int(self._byte(length - 1))
        if encoded & 64:
            kind = MouseEvent.SCROLL_UP if low_button == 0 else MouseEvent.SCROLL_DOWN
            button = None
        elif final == 0x6D:
            kind = MouseEvent.RELEASE
        elif encoded & 32:
            kind = MouseEvent.MOVE

        self._consume(length)
        events.append(
            InputEvent(MouseEvent(kind, button, column - 1, row - 1, modifiers))
        )
        return True

    def _parse_csi_u(mut self, mut events: List[InputEvent], length: Int) -> Bool:
        if Int(self._byte(length - 1)) != 0x75:
            return False

        var separator = -1
        var kind_separator = -1
        for offset in range(2, length - 1):
            var value = Int(self._byte(offset))
            if value == 0x3B:
                if separator >= 0 or kind_separator >= 0:
                    return False
                separator = offset
            elif value == 0x3A:
                if separator < 0 or kind_separator >= 0:
                    return False
                kind_separator = offset

        var codepoint_end = separator if separator >= 0 else length - 1
        var codepoint = self._decimal(2, codepoint_end)
        if codepoint < 0 or codepoint > 0x10FFFF:
            return False

        var modifiers = KeyModifiers.NONE
        var kind = KeyEvent.PRESS
        if separator >= 0:
            var modifiers_end = kind_separator if kind_separator >= 0 else length - 1
            var modifier_parameter = self._decimal(separator + 1, modifiers_end)
            if modifier_parameter < 1 or modifier_parameter > 255:
                return False
            modifiers = KeyModifiers((modifier_parameter - 1) & 7, _validated=True)
            if kind_separator >= 0:
                var event_type = self._decimal(kind_separator + 1, length - 1)
                if event_type == 2:
                    kind = KeyEvent.REPEAT
                elif event_type == 3:
                    kind = KeyEvent.RELEASE
                elif event_type != 1:
                    return False

        if codepoint == 27:
            self._consume(length)
            events.append(
                InputEvent(KeyEvent.named(KeyEvent.ESCAPE, modifiers, kind=kind))
            )
            return True
        if codepoint == 13:
            self._consume(length)
            events.append(
                InputEvent(KeyEvent.named(KeyEvent.ENTER, modifiers, kind=kind))
            )
            return True
        if codepoint == 9:
            self._consume(length)
            events.append(
                InputEvent(KeyEvent.named(KeyEvent.TAB, modifiers, kind=kind))
            )
            return True
        if codepoint == 127:
            self._consume(length)
            events.append(
                InputEvent(KeyEvent.named(KeyEvent.BACKSPACE, modifiers, kind=kind))
            )
            return True

        var scalar = Codepoint.from_u32(UInt32(codepoint))
        if not scalar:
            return False
        var text = String()
        text.append(scalar.value())
        self._consume(length)
        events.append(InputEvent(KeyEvent.character(text^, modifiers, kind=kind)))
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
            if code:
                self._consume(length)
                events.append(InputEvent(KeyEvent.named(code.value())))
                return True
            if final == 0x5A:
                self._consume(length)
                events.append(InputEvent(KeyEvent.named(KeyEvent.TAB, KeyEvent.SHIFT)))
                return True
            if final == 0x49 or final == 0x4F:
                self._consume(length)
                events.append(InputEvent(FocusEvent(final == 0x49)))
                return True

        if Int(self._byte(length - 1)) == 0x7E:
            var separator = -1
            for offset in range(2, length - 1):
                if Int(self._byte(offset)) == 0x3B:
                    if separator >= 0:
                        separator = -2
                        break
                    separator = offset
            var parameter_end = separator if separator >= 0 else length - 1
            var parameter = self._decimal(2, parameter_end)
            var code = self._key_code_for_tilde_parameter(parameter)
            var modifiers = KeyModifiers.NONE
            var valid_modifiers = separator >= -1
            if separator >= 0:
                var modifier_parameter = self._decimal(separator + 1, length - 1)
                valid_modifiers = modifier_parameter >= 2 and modifier_parameter <= 8
                if valid_modifiers:
                    modifiers = KeyModifiers(
                        modifier_parameter - 1,
                        _validated=True,
                    )
            if code and valid_modifiers:
                self._consume(length)
                events.append(InputEvent(KeyEvent.named(code.value(), modifiers)))
                return True

        if length == 6 and Int(self._byte(2)) == 0x31 and Int(self._byte(3)) == 0x3B:
            var modifier_parameter = Int(self._byte(4)) - 0x30
            var code = self._key_code_for_final(Int(self._byte(5)))
            if not code:
                code = self._function_key_code_for_final(Int(self._byte(5)))
            if modifier_parameter >= 2 and modifier_parameter <= 8 and code:
                self._consume(length)
                events.append(
                    InputEvent(
                        KeyEvent.named(
                            code.value(),
                            KeyModifiers(
                                modifier_parameter - 1,
                                _validated=True,
                            ),
                        )
                    )
                )
                return True

        if length == 6 and self._matches_paste_delimiter(0, 0x30):
            self._consume(length)
            self.paste_bytes.clear()
            self.in_paste = True
            return True

        if self._parse_csi_u(events, length):
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
        if Int(self._byte(1)) == 0x4F:
            if self.pending_byte_count() == 2:
                return False
            var final = Int(self._byte(2))
            var code = self._key_code_for_final(final)
            if not code:
                code = self._function_key_code_for_final(final)
            if code:
                self._consume(3)
                events.append(InputEvent(KeyEvent.named(code.value())))
                return True
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
