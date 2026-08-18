from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import KeyChord, Keymap, KeymapState


def test_context_binding_overrides_global_binding() raises:
    var keymap = Keymap[Int]()
    keymap.bind_key("", KeyChord.character("q"), 1)
    keymap.bind_key("editor", KeyChord.character("q"), 2)
    var state = KeymapState[Int]()
    var result = keymap.resolve(state, KeyChord.character("q"), "editor", 0)
    assert_equal(len(result.actions), 1)
    assert_equal(result.actions[0], 2)


def test_multi_key_sequence_waits_then_resolves() raises:
    var keymap = Keymap[Int]()
    keymap.bind("editor", [KeyChord.character("g"), KeyChord.character("g")], 7)
    var state = KeymapState[Int]()
    var first = keymap.resolve(state, KeyChord.character("g"), "editor", 10)
    assert_true(first.pending)
    assert_equal(len(first.actions), 0)
    var second = keymap.resolve(state, KeyChord.character("g"), "editor", 20)
    assert_false(second.pending)
    assert_equal(second.actions[0], 7)


def test_ambiguous_exact_binding_fires_on_injected_timeout() raises:
    var keymap = Keymap[Int](timeout_ns=100)
    keymap.bind_key("editor", KeyChord.character("g"), 3)
    keymap.bind("editor", [KeyChord.character("g"), KeyChord.character("g")], 7)
    var state = KeymapState[Int]()
    var first = keymap.resolve(state, KeyChord.character("g"), "editor", 50)
    assert_true(first.pending)
    assert_true(keymap.flush(state, 149).pending)
    var expired = keymap.flush(state, 150)
    assert_equal(expired.actions[0], 3)


def test_invalid_prefix_retries_current_key() raises:
    var keymap = Keymap[Int]()
    keymap.bind("editor", [KeyChord.character("g"), KeyChord.character("g")], 7)
    keymap.bind_key("", KeyChord.character("q"), 1)
    var state = KeymapState[Int]()
    _ = keymap.resolve(state, KeyChord.character("g"), "editor", 0)
    var recovered = keymap.resolve(state, KeyChord.character("q"), "editor", 1)
    assert_equal(recovered.actions[0], 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
