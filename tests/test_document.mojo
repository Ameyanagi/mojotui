from std.testing import TestSuite, assert_equal, assert_true

from mojotui import Document


def test_document_insert_delete_replace_and_metrics() raises:
    var document = Document("hello\nworld")
    var initial_revision = document.revision()
    document.insert(0, "")
    assert_true(document.revision() == initial_revision)
    assert_equal(document.byte_length(), 11)
    assert_equal(document.line_count(), 2)
    document.insert(5, ", safe")
    assert_true(document.revision() != initial_revision)
    assert_equal(document.to_string(), "hello, safe\nworld")
    assert_equal(document.delete(5, 11), ", safe")
    assert_equal(document.to_string(), "hello\nworld")
    assert_equal(document.replace(6, 11, "Mojo"), "world")
    assert_equal(document.to_string(), "hello\nMojo")
    assert_equal(document.version, 3)
    var same_content = Document(document.to_string())
    assert_true(document.revision() != same_content.revision())
    document.validate()


def test_document_unicode_offsets_are_bytes_and_boundaries_are_checked() raises:
    var document = Document("a界b")
    assert_equal(document.byte_length(), 5)
    assert_true(document.is_utf8_boundary(1))
    assert_true(document.is_utf8_boundary(4))
    try:
        document.insert(2, "x")
    except:
        assert_equal(document.to_string(), "a界b")
        return
    raise Error("expected rejection inside UTF-8 code point")


def test_document_slice_crosses_piece_boundaries_without_flattening() raises:
    var document = Document("ace")
    document.insert(1, "b")
    document.insert(3, "d")
    document.insert(5, "f")
    assert_equal(document.to_string(), "abcdef")
    assert_equal(document.slice(1, 5), "bcde")
    assert_equal(document.piece_count(), 6)
    document.validate()


def test_sequential_edits_keep_tree_height_bounded() raises:
    var document = Document()
    for _ in range(1000):
        document.insert(document.byte_length(), "x")
    assert_equal(document.byte_length(), 1000)
    assert_true(document.tree_height() < 64)
    document.validate()


def test_deterministic_edit_sequence_matches_flat_model() raises:
    var document = Document("0123456789")
    var expected = String("0123456789")
    for index in range(100):
        var offset = (index * 17) % (expected.byte_length() + 1)
        var inserted = String(index % 10)
        document.insert(offset, inserted)
        expected = (
            String(expected[byte=:offset]) + inserted + String(expected[byte=offset:])
        )
        if index % 3 == 0 and expected.byte_length() > 4:
            var start = (index * 7) % (expected.byte_length() - 1)
            var end = min(start + 2, expected.byte_length())
            _ = document.delete(start, end)
            expected = String(expected[byte=:start]) + String(expected[byte=end:])
        assert_equal(document.to_string(), expected)
        document.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
