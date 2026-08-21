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
    var first = key(events[0].copy())
    assert_equal(first.text, "a")
    assert_true(first.kind == KeyEvent.PRESS)
    assert_equal(key(events[1].copy()).text, "b")


def test_key_event_is_char_requires_matching_press_character() raises:
    assert_true(KeyEvent.character("q").is_char("q"))
    assert_false(KeyEvent.character("q", kind=KeyEvent.RELEASE).is_char("q"))
    assert_false(KeyEvent(KeyEvent.ENTER, "q").is_char("q"))


def test_fragmented_arrow_sequence() raises:
    var parser = InputParser()
    var first = parser.feed(bytes2(0x1B, 0x5B))
    assert_equal(len(first), 0)
    assert_equal(parser.pending_byte_count(), 2)
    var second = parser.feed([UInt8(0x41)])
    assert_equal(len(second), 1)
    assert_true(key(second[0].copy()).code == KeyEvent.UP)


def test_ss3_function_key_and_arrow_sequences() raises:
    var parser = InputParser()
    var function_key = parser.feed(bytes3(0x1B, 0x4F, 0x50))
    assert_equal(len(function_key), 1)
    assert_true(key(function_key[0].copy()).code == KeyEvent.F1)

    var arrow = parser.feed(bytes3(0x1B, 0x4F, 0x41))
    assert_equal(len(arrow), 1)
    assert_true(key(arrow[0].copy()).code == KeyEvent.UP)


def test_fragmented_ss3_sequence() raises:
    var parser = InputParser()
    var first = parser.feed(bytes2(0x1B, 0x4F))
    assert_equal(len(first), 0)
    assert_equal(parser.pending_byte_count(), 2)
    var second = parser.feed([UInt8(0x50)])
    assert_equal(len(second), 1)
    assert_true(key(second[0].copy()).code == KeyEvent.F1)


def test_csi_tilde_function_keys() raises:
    var parser = InputParser()
    var first: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x31),
        UInt8(0x31),
        UInt8(0x7E),
    ]
    var f1 = parser.feed(first^)
    assert_equal(len(f1), 1)
    assert_true(key(f1[0].copy()).code == KeyEvent.F1)

    var last: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x32),
        UInt8(0x34),
        UInt8(0x7E),
    ]
    var f12 = parser.feed(last^)
    assert_equal(len(f12), 1)
    assert_true(key(f12[0].copy()).code == KeyEvent.F12)


def test_modified_csi_function_keys() raises:
    var parser = InputParser()
    var tilde: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x31),
        UInt8(0x31),
        UInt8(0x3B),
        UInt8(0x35),
        UInt8(0x7E),
    ]
    var tilde_events = parser.feed(tilde^)
    var tilde_key = key(tilde_events[0].copy())
    assert_true(tilde_key.code == KeyEvent.F1)
    assert_true(tilde_key.modifiers == KeyEvent.CONTROL)

    var final: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x31),
        UInt8(0x3B),
        UInt8(0x35),
        UInt8(0x50),
    ]
    var final_events = parser.feed(final^)
    var final_key = key(final_events[0].copy())
    assert_true(final_key.code == KeyEvent.F1)
    assert_true(final_key.modifiers == KeyEvent.CONTROL)

    var navigation: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x31),
        UInt8(0x3B),
        UInt8(0x35),
        UInt8(0x7E),
    ]
    var navigation_events = parser.feed(navigation^)
    var navigation_key = key(navigation_events[0].copy())
    assert_true(navigation_key.code == KeyEvent.HOME)
    assert_true(navigation_key.modifiers == KeyEvent.CONTROL)


def test_csi_u_character_with_control() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x39),
        UInt8(0x37),
        UInt8(0x3B),
        UInt8(0x35),
        UInt8(0x75),
    ]
    var events = parser.feed(sequence^)
    assert_equal(len(events), 1)
    var event = key(events[0].copy())
    assert_true(event.code == KeyEvent.CHARACTER)
    assert_equal(event.text, "a")
    assert_true(event.modifiers == KeyEvent.CONTROL)
    assert_true(event.kind == KeyEvent.PRESS)


def test_csi_u_release_without_modifiers() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x39),
        UInt8(0x37),
        UInt8(0x3B),
        UInt8(0x31),
        UInt8(0x3A),
        UInt8(0x33),
        UInt8(0x75),
    ]
    var events = parser.feed(sequence^)
    assert_equal(len(events), 1)
    var event = key(events[0].copy())
    assert_true(event.code == KeyEvent.CHARACTER)
    assert_equal(event.text, "a")
    assert_true(event.modifiers == KeyEvent.NO_MODIFIERS)
    assert_true(event.kind == KeyEvent.RELEASE)


def test_csi_u_disambiguates_escape() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x32),
        UInt8(0x37),
        UInt8(0x75),
    ]
    var events = parser.feed(sequence^)
    assert_equal(len(events), 1)
    var event = key(events[0].copy())
    assert_true(event.code == KeyEvent.ESCAPE)
    assert_true(event.modifiers == KeyEvent.NO_MODIFIERS)
    assert_true(event.kind == KeyEvent.PRESS)
    assert_equal(parser.pending_byte_count(), 0)


def test_csi_u_named_key_with_shift_repeat() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x31),
        UInt8(0x33),
        UInt8(0x3B),
        UInt8(0x32),
        UInt8(0x3A),
        UInt8(0x32),
        UInt8(0x75),
    ]
    var events = parser.feed(sequence^)
    assert_equal(len(events), 1)
    var event = key(events[0].copy())
    assert_true(event.code == KeyEvent.ENTER)
    assert_true(event.modifiers == KeyEvent.SHIFT)
    assert_true(event.kind == KeyEvent.REPEAT)


def test_csi_u_masks_lock_modifier_bits() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x39),
        UInt8(0x37),
        UInt8(0x3B),
        UInt8(0x36),
        UInt8(0x35),
        UInt8(0x75),
    ]
    var events = parser.feed(sequence^)
    assert_equal(len(events), 1)
    var event = key(events[0].copy())
    assert_true(event.code == KeyEvent.CHARACTER)
    assert_equal(event.text, "a")
    assert_true(event.modifiers == KeyEvent.NO_MODIFIERS)
    assert_true(event.kind == KeyEvent.PRESS)


def test_malformed_csi_u_is_unknown() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x3B),
        UInt8(0x75),
    ]
    var events = parser.feed(sequence^)
    assert_equal(len(events), 1)
    assert_true(events[0].isa[UnknownEvent]())
    assert_equal(events[0][UnknownEvent].sequence, "\x1b[;u")


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
    assert_true(key(events[0].copy()).code == KeyEvent.ESCAPE)


def test_alt_character() raises:
    var parser = InputParser()
    var events = parser.feed(bytes2(0x1B, 0x78))
    var event = key(events[0].copy())
    assert_equal(event.text, "x")
    assert_true(event.modifiers == KeyEvent.ALT)


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
    assert_true(arrow.code == KeyEvent.UP)
    assert_true(arrow.modifiers == KeyEvent.CONTROL)

    var tabs = parser.feed(bytes3(0x1B, 0x5B, 0x5A))
    var tab = key(tabs[0].copy())
    assert_true(tab.code == KeyEvent.TAB)
    assert_true(tab.modifiers == KeyEvent.SHIFT)


def test_control_character() raises:
    var parser = InputParser()
    var events = parser.feed([UInt8(0x03)])
    var event = key(events[0].copy())
    assert_equal(event.text, "c")
    assert_true(event.modifiers == KeyEvent.CONTROL)


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
    assert_true(mouse.kind == MouseEvent.PRESS)
    assert_true(mouse.button)
    assert_true(mouse.button.value() == MouseEvent.LEFT)
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
    assert_true(mouse.kind == MouseEvent.MOVE)
    assert_true(mouse.button)
    assert_true(mouse.button.value() == MouseEvent.LEFT)
    assert_true(mouse.modifiers == KeyEvent.CONTROL)


def test_sgr_scroll_has_no_physical_button() raises:
    var parser = InputParser()
    var sequence: List[UInt8] = [
        UInt8(0x1B),
        UInt8(0x5B),
        UInt8(0x3C),
        UInt8(0x36),
        UInt8(0x34),
        UInt8(0x3B),
        UInt8(0x31),
        UInt8(0x3B),
        UInt8(0x31),
        UInt8(0x4D),
    ]
    var events = parser.feed(sequence^)
    var mouse = events[0][MouseEvent].copy()
    assert_true(mouse.kind == MouseEvent.SCROLL_UP)
    assert_false(mouse.button)
    assert_true(mouse.modifiers == KeyEvent.NO_MODIFIERS)


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

    var function_like = parser.feed(bytes3(0x1B, 0x5B, 0x50))
    assert_equal(len(function_like), 1)
    assert_true(function_like[0].isa[UnknownEvent]())
    assert_equal(function_like[0][UnknownEvent].sequence, "\x1b[P")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
