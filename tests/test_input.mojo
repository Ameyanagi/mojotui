from std.collections import List
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import (
    FocusEvent,
    InputEvent,
    InputParser,
    KeyEvent,
    MouseEvent,
    PasteEvent,
    UnknownEvent,
)


def bytes2(first: Int, second: Int) -> List[UInt8]:
    return [UInt8(first), UInt8(second)]


def bytes3(first: Int, second: Int, third: Int) -> List[UInt8]:
    return [UInt8(first), UInt8(second), UInt8(third)]


def key(var event: InputEvent) raises -> KeyEvent:
    assert_true(event.isa[KeyEvent]())
    return event[KeyEvent].copy()


def test_plain_and_combined_keys() raises:
    var parser = InputParser()
    var events = parser.feed(bytes2(0x61, 0x62))
    assert_equal(len(events), 2)
    assert_equal(key(events[0].copy()).text, "a")
    assert_equal(key(events[1].copy()).text, "b")


def test_fragmented_arrow_sequence() raises:
    var parser = InputParser()
    var first = parser.feed(bytes2(0x1B, 0x5B))
    assert_equal(len(first), 0)
    assert_equal(parser.pending_byte_count(), 2)
    var second = parser.feed([UInt8(0x41)])
    assert_equal(len(second), 1)
    assert_equal(key(second[0].copy()).code, KeyEvent.UP)


def test_fragmented_utf8_character() raises:
    var parser = InputParser()
    assert_equal(len(parser.feed(bytes2(0xE7, 0x95))), 0)
    var events = parser.feed([UInt8(0x8C)])
    assert_equal(key(events[0].copy()).text, "界")


def test_invalid_utf8_does_not_stall_parser() raises:
    var parser = InputParser()
    var events = parser.feed(bytes2(0xE0, 0x41))
    assert_equal(len(events), 2)
    assert_equal(key(events[0].copy()).text, "�")
    assert_equal(key(events[1].copy()).text, "A")


def test_escape_timeout() raises:
    var parser = InputParser()
    assert_equal(len(parser.feed([UInt8(0x1B)])), 0)
    var events = parser.flush_escape()
    assert_equal(key(events[0].copy()).code, KeyEvent.ESCAPE)


def test_alt_character() raises:
    var parser = InputParser()
    var events = parser.feed(bytes2(0x1B, 0x78))
    var event = key(events[0].copy())
    assert_equal(event.text, "x")
    assert_equal(event.modifiers, KeyEvent.ALT)


def test_modified_arrow_and_shift_tab() raises:
    var parser = InputParser()
    var modified: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x31),
        UInt8(0x3B),
        UInt8(0x35),
        UInt8(0x41),
    ]
    var arrows = parser.feed(modified^)
    var arrow = key(arrows[0].copy())
    assert_equal(arrow.code, KeyEvent.UP)
    assert_equal(arrow.modifiers, KeyEvent.CONTROL)

    var tabs = parser.feed(bytes3(0x1B, 0x5B, 0x5A))
    var tab = key(tabs[0].copy())
    assert_equal(tab.code, KeyEvent.TAB)
    assert_equal(tab.modifiers, KeyEvent.SHIFT)


def test_control_character() raises:
    var parser = InputParser()
    var events = parser.feed([UInt8(0x03)])
    var event = key(events[0].copy())
    assert_equal(event.text, "c")
    assert_equal(event.modifiers, KeyEvent.CONTROL)


def test_focus_events() raises:
    var parser = InputParser()
    var gained = parser.feed(bytes3(0x1B, 0x5B, 0x49))
    var lost = parser.feed(bytes3(0x1B, 0x5B, 0x4F))
    assert_true(gained[0].isa[FocusEvent]())
    assert_true(gained[0][FocusEvent].focused)
    assert_true(lost[0].isa[FocusEvent]())
    assert_false(lost[0][FocusEvent].focused)


def test_sgr_mouse_press_and_coordinates() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x3C),
        UInt8(0x30),
        UInt8(0x3B),
        UInt8(0x31),
        UInt8(0x30),
        UInt8(0x3B),
        UInt8(0x35),
        UInt8(0x4D),
    ]
    var events = parser.feed(sequence^)
    assert_true(events[0].isa[MouseEvent]())
    var mouse = events[0][MouseEvent].copy()
    assert_equal(mouse.kind, MouseEvent.PRESS)
    assert_equal(mouse.button, MouseEvent.LEFT)
    assert_equal(mouse.x, 9)
    assert_equal(mouse.y, 4)


def test_sgr_mouse_move_with_control() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x3C),
        UInt8(0x34),
        UInt8(0x38),
        UInt8(0x3B),
        UInt8(0x32),
        UInt8(0x3B),
        UInt8(0x33),
        UInt8(0x4D),
    ]
    var events = parser.feed(sequence^)
    var mouse = events[0][MouseEvent].copy()
    assert_equal(mouse.kind, MouseEvent.MOVE)
    assert_equal(mouse.button, MouseEvent.LEFT)
    assert_equal(mouse.modifiers, KeyEvent.CONTROL)


def test_fragmented_bracketed_paste() raises:
    var parser = InputParser()
    var start: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x32),
        UInt8(0x30),
        UInt8(0x30),
        UInt8(0x7E),
        UInt8(0x68),
        UInt8(0x69),
        UInt8(0x1B),
        UInt8(0x5B),
    ]
    assert_equal(len(parser.feed(start^)), 0)
    var events = parser.feed([UInt8(0x32), UInt8(0x30), UInt8(0x31), UInt8(0x7E)])
    assert_equal(len(events), 1)
    assert_true(events[0].isa[PasteEvent]())
    assert_equal(events[0][PasteEvent].text, "hi")


def test_unknown_complete_sequence_is_preserved() raises:
    var parser = InputParser()
    var events = parser.feed(bytes3(0x1B, 0x5B, 0x58))
    assert_equal(len(events), 1)
    assert_true(events[0].isa[UnknownEvent]())
    assert_equal(events[0][UnknownEvent].sequence, "\x1b[X")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
