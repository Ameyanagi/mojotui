from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import Document, MarkerAffinity


def test_line_lookup_uses_canonical_byte_offsets() raises:
    var document = Document("a\n界x\n")
    assert_equal(document.line_count(), 3)
    assert_equal(document.line_start(0), 0)
    assert_equal(document.line_start(1), 2)
    assert_equal(document.line_start(2), 7)
    assert_equal(document.line_end(0), 1)
    assert_equal(document.line_end(1), 6)
    assert_equal(document.line_text(1), "界x")
    var position = document.position_at(5)
    assert_equal(position.line, 1)
    assert_equal(position.byte_column, 3)
    assert_equal(document.offset_at(1, 3), 5)


def test_line_lookup_rejects_utf8_interior_column() raises:
    var document = Document("界")
    try:
        _ = document.offset_at(0, 1)
    except:
        return
    raise Error("expected UTF-8 interior column rejection")


def test_marker_affinity_controls_exact_insert_boundary() raises:
    var document = Document("abc")
    var before = document.create_marker(1, MarkerAffinity.BEFORE)
    var after = document.create_marker(1, MarkerAffinity.AFTER)
    document.insert(1, "X")
    assert_equal(document.marker_offset(before), 1)
    assert_equal(document.marker_offset(after), 2)


def test_markers_collapse_through_deletion_and_can_be_removed() raises:
    var document = Document("abcdef")
    var inside = document.create_marker(3)
    var trailing = document.create_marker(6)
    _ = document.delete(1, 5)
    assert_equal(document.marker_offset(inside), 1)
    assert_equal(document.marker_offset(trailing), 2)
    assert_equal(document.active_marker_count(), 2)
    assert_true(document.remove_marker(inside))
    assert_false(document.remove_marker(inside))
    assert_equal(document.active_marker_count(), 1)


def test_large_original_is_chunked_for_bounded_local_line_scans() raises:
    var text = String()
    for index in range(20_000):
        text += "\n" if index % 80 == 79 else "x"
    var document = Document(text^)
    assert_true(document.piece_count() >= 4)
    assert_equal(document.line_count(), 251)
    assert_equal(document.line_start(250), 20_000)
    document.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
