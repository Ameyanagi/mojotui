from std.testing import TestSuite, assert_equal

from mojotui import codepoint_width, grapheme_width, text_width, unicode_version


def test_unicode_data_version() raises:
    assert_equal(unicode_version(), "17.0.0")


def test_ascii_and_control_widths() raises:
    assert_equal(codepoint_width(0x41), 1)
    assert_equal(codepoint_width(0x0A), 0)
    assert_equal(codepoint_width(0x7F), 0)


def test_combining_grapheme_width() raises:
    assert_equal(grapheme_width("e\u0301"), 1)
    assert_equal(grapheme_width("\u0301"), 0)


def test_cjk_width() raises:
    assert_equal(grapheme_width("界"), 2)


def test_emoji_widths() raises:
    assert_equal(grapheme_width("🙂"), 2)
    assert_equal(grapheme_width("❤️"), 2)
    assert_equal(grapheme_width("❤︎"), 1)
    assert_equal(grapheme_width("👨‍👩‍👧‍👦"), 2)
    assert_equal(grapheme_width("🇯🇵"), 2)


def test_ambiguous_width_policy() raises:
    assert_equal(grapheme_width("·"), 1)
    assert_equal(grapheme_width("·", ambiguous_is_wide=True), 2)


def test_text_width_scans_graphemes() raises:
    assert_equal(text_width("a界🙂"), 5)
    assert_equal(text_width("cafe\u0301"), 4)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
