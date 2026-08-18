from std.testing import TestSuite, assert_equal, assert_true

from mojotui import Constraint, Flex, Layout, Rect


def test_fixed_and_weighted_fill() raises:
    var layout = Layout.horizontal(
        [Constraint.length(5), Constraint.fill(1), Constraint.fill(2)],
        spacing=1,
    )
    var areas = layout.split(Rect(0, 0, 20, 2))
    assert_equal(areas[0].width, 5)
    assert_equal(areas[1].width, 5)
    assert_equal(areas[2].width, 8)
    assert_equal(areas[1].x, 6)
    assert_equal(areas[2].x, 12)


def test_percentage_ratio_and_end_alignment() raises:
    var layout = Layout.horizontal(
        [Constraint.percentage(25), Constraint.ratio(1, 2)],
        flex=Flex.END,
    )
    var areas = layout.split(Rect(10, 0, 100, 1))
    assert_equal(areas[0].x, 35)
    assert_equal(areas[0].width, 25)
    assert_equal(areas[1].x, 60)
    assert_equal(areas[1].width, 50)


def test_maximum_caps_and_space_between() raises:
    var layout = Layout.horizontal(
        [Constraint.maximum(3), Constraint.maximum(3)],
        spacing=1,
        flex=Flex.SPACE_BETWEEN,
    )
    var areas = layout.split(Rect(0, 0, 20, 1))
    assert_equal(areas[0].width, 3)
    assert_equal(areas[1].width, 3)
    assert_equal(areas[1].x, 17)


def test_vertical_minimum_and_fill() raises:
    var layout = Layout.vertical([Constraint.minimum(2), Constraint.fill()], spacing=1)
    var areas = layout.split(Rect(3, 4, 7, 10))
    assert_equal(areas[0].y, 4)
    assert_equal(areas[0].height, 6)
    assert_equal(areas[1].y, 11)
    assert_equal(areas[1].height, 3)


def test_empty_layout_returns_no_areas() raises:
    var layout = Layout.horizontal([])
    assert_equal(len(layout.split(Rect(0, 0, 10, 2))), 0)


def test_layout_stays_inside_area_across_small_widths() raises:
    for width in range(129):
        var parent = Rect(-7, 3, width, 4)
        var layout = Layout.horizontal(
            [
                Constraint.length(9),
                Constraint.minimum(3),
                Constraint.maximum(11),
                Constraint.percentage(33),
                Constraint.ratio(2, 5),
                Constraint.fill(3),
            ],
            spacing=2,
        )
        var areas = layout.split(parent)
        assert_equal(len(areas), 6)
        var previous_right = parent.x
        for index in range(len(areas)):
            var child = areas[index].copy()
            assert_true(child.x >= parent.x)
            assert_true(child.right() <= parent.right())
            assert_true(child.x >= previous_right)
            assert_equal(child.y, parent.y)
            assert_equal(child.height, parent.height)
            previous_right = child.right()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
