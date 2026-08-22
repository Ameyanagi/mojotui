from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import KeyChord, KeyEvent, Keymap, KeymapState


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


def test_key_event_resolution_ignores_release_without_breaking_sequence() raises:
    var keymap = Keymap[Int]()
    keymap.bind("editor", [KeyChord.character("g"), KeyChord.character("g")], 7)
    var state = KeymapState[Int]()
    var first = keymap.resolve(state, KeyEvent.character("g"), "editor", 10)
    assert_true(first.pending)

    var released = keymap.resolve(
        state,
        KeyEvent.character("g", kind=KeyEvent.RELEASE),
        "editor",
        11,
    )
    assert_true(released.pending)
    assert_false(released.consumed)
    assert_equal(len(released.actions), 0)

    var repeated = keymap.resolve(
        state,
        KeyEvent.character("g", kind=KeyEvent.REPEAT),
        "editor",
        12,
    )
    assert_false(repeated.pending)
    assert_equal(repeated.actions[0], 7)


def test_release_in_new_context_clears_pending_exact_before_flush() raises:
    var keymap = Keymap[Int](timeout_ns=100)
    keymap.bind_key("editor", KeyChord.character("g"), 3)
    keymap.bind("editor", [KeyChord.character("g"), KeyChord.character("g")], 7)
    var state = KeymapState[Int]()
    var first = keymap.resolve(state, KeyEvent.character("g"), "editor", 50)
    assert_true(first.pending)

    var released = keymap.resolve(
        state,
        KeyEvent.character("g", kind=KeyEvent.RELEASE),
        "dialog",
        75,
    )
    assert_false(released.pending)
    assert_false(released.consumed)
    assert_equal(len(released.actions), 0)

    var expired = keymap.flush(state, 150)
    assert_false(expired.pending)
    assert_false(expired.consumed)
    assert_equal(len(expired.actions), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
