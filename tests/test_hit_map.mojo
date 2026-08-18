from std.testing import TestSuite, assert_equal, assert_false, assert_true

from mojotui import HitMap, Point, Rect


def test_hit_map_prefers_z_index_then_latest_registration() raises:
    var hits = HitMap(Rect(0, 0, 10, 5))
    assert_true(hits.register("base", Rect(1, 1, 5, 3)))
    assert_true(hits.register("overlay", Rect(2, 1, 3, 2), z_index=2))
    assert_true(hits.register("latest", Rect(2, 1, 1, 1), z_index=2))
    var hit = hits.hit(Point(2, 1))
    assert_true(hit)
    assert_equal(hit.value().id, "latest")
    assert_equal(hit.value().local.x, 0)
    assert_equal(hit.value().local.y, 0)


def test_nested_clip_limits_registered_region() raises:
    var hits = HitMap(Rect(0, 0, 10, 5))
    hits.push_clip(Rect(3, 2, 2, 2))
    assert_true(hits.register("child", Rect(0, 0, 10, 5)))
    assert_false(hits.hit(Point(2, 2)))
    assert_true(hits.hit(Point(3, 2)))
    assert_true(hits.pop_clip())
    assert_false(hits.pop_clip())


def test_reset_discards_previous_frame_regions() raises:
    var hits = HitMap(Rect(0, 0, 2, 2))
    _ = hits.register("old", Rect(0, 0, 2, 2))
    hits.reset(Rect(5, 5, 1, 1))
    assert_equal(hits.region_count(), 0)
    assert_false(hits.hit(Point(0, 0)))
    assert_true(hits.register("new", Rect(5, 5, 1, 1)))
    assert_equal(hits.hit(Point(5, 5)).value().id, "new")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
