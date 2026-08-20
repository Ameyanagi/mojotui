from std.testing import TestSuite, assert_equal, assert_true

from mojotui import Constraint, Flex, Layout, Margin, Rect


def test_fixed_and_weighted_fill() raises:
    var layout = Layout.horizontal(
        [Constraint.length(5), Constraint.fill(1), Constraint.fill(2)],
        spacing=1,
    )
    var areas = layout.split(Rect(0, 0, 20, 2))
    assert_equal(areas[0].width, 5)
    assert_equal(areas[1].width, 4)
    assert_equal(areas[2].width, 9)
    assert_equal(areas[1].x, 6)
    assert_equal(areas[2].x, 11)


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
    assert_equal(areas[0].height, 2)
    assert_equal(areas[1].y, 7)
    assert_equal(areas[1].height, 7)


def test_ratatui_flex_position_fixtures() raises:
    var start = Layout.horizontal([Constraint.length(25), Constraint.length(25)]).split(
        Rect(0, 0, 100, 1)
    )
    assert_equal(start[0].x, 0)
    assert_equal(start[1].x, 25)

    var center = Layout.horizontal(
        [Constraint.length(25), Constraint.length(25)],
        flex=Flex.CENTER,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(center[0].x, 25)
    assert_equal(center[1].x, 50)

    var end = Layout.horizontal(
        [Constraint.length(25), Constraint.length(25)],
        flex=Flex.END,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(end[0].x, 50)
    assert_equal(end[1].x, 75)

    var between = Layout.horizontal(
        [Constraint.length(25), Constraint.length(25)],
        flex=Flex.SPACE_BETWEEN,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(between[0].x, 0)
    assert_equal(between[1].x, 75)

    var evenly = Layout.horizontal(
        [Constraint.length(25), Constraint.length(25)],
        flex=Flex.SPACE_EVENLY,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(evenly[0].x, 17)
    assert_equal(evenly[1].x, 58)

    var around = Layout.horizontal(
        [Constraint.length(25), Constraint.length(25)],
        flex=Flex.SPACE_AROUND,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(around[0].x, 13)
    assert_equal(around[1].x, 63)


def test_ratatui_constraint_kind_fixtures() raises:
    var ratio = Layout.horizontal([Constraint.ratio(1, 2)], flex=Flex.CENTER).split(
        Rect(0, 0, 100, 1)
    )
    assert_equal(ratio[0].x, 25)
    assert_equal(ratio[0].width, 50)

    var minimums = Layout.horizontal(
        [Constraint.minimum(25), Constraint.minimum(25)]
    ).split(Rect(0, 0, 100, 1))
    assert_equal(minimums[0].width, 50)
    assert_equal(minimums[1].width, 50)

    var maximums = Layout.horizontal(
        [Constraint.maximum(25), Constraint.maximum(25)],
        flex=Flex.SPACE_AROUND,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(maximums[0].x, 13)
    assert_equal(maximums[0].width, 25)
    assert_equal(maximums[1].x, 63)

    var percentages = Layout.horizontal(
        [Constraint.percentage(25), Constraint.percentage(25)],
        flex=Flex.SPACE_EVENLY,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(percentages[0].x, 17)
    assert_equal(percentages[0].width, 25)
    assert_equal(percentages[1].x, 58)


def test_ratatui_spacing_and_fill_fixtures() raises:
    var fixed = Layout.horizontal(
        [Constraint.length(20), Constraint.length(20), Constraint.length(20)],
        spacing=2,
        flex=Flex.CENTER,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(fixed[0].x, 18)
    assert_equal(fixed[1].x, 40)
    assert_equal(fixed[2].x, 62)

    var evenly = Layout.horizontal(
        [Constraint.fill(), Constraint.fill()],
        spacing=10,
        flex=Flex.SPACE_EVENLY,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(evenly[0].x, 10)
    assert_equal(evenly[0].width, 35)
    assert_equal(evenly[1].x, 55)
    assert_equal(evenly[1].width, 35)

    var around = Layout.horizontal(
        [Constraint.fill(), Constraint.fill()],
        spacing=10,
        flex=Flex.SPACE_AROUND,
    ).split(Rect(0, 0, 100, 1))
    assert_equal(around[0].x, 10)
    assert_equal(around[0].width, 30)
    assert_equal(around[1].x, 60)
    assert_equal(around[1].width, 30)


def test_ratatui_priority_and_rounding_fixtures() raises:
    var priority = Layout.horizontal(
        [
            Constraint.length(100),
            Constraint.length(1),
            Constraint.minimum(20),
        ]
    ).split(Rect(0, 0, 100, 1))
    assert_equal(priority[0].width, 79)
    assert_equal(priority[1].width, 1)
    assert_equal(priority[2].width, 20)

    var rounded = Layout.horizontal(
        [Constraint.length(4), Constraint.length(4)], spacing=1
    ).split(Rect(0, 0, 4, 1))
    assert_equal(rounded[0].width, 2)
    assert_equal(rounded[1].x, 3)
    assert_equal(rounded[1].width, 1)

    var above_one = Layout.horizontal(
        [Constraint.percentage(200), Constraint.length(10)]
    ).split(Rect(0, 0, 100, 1))
    assert_equal(above_one[0].width, 90)
    assert_equal(above_one[1].width, 10)


def test_zero_weight_fill_and_margin_fixtures() raises:
    var fills = Layout.horizontal(
        [Constraint.fill(0), Constraint.length(20), Constraint.fill(0)]
    ).split(Rect(0, 0, 100, 1))
    assert_equal(fills[0].width, 40)
    assert_equal(fills[1].width, 20)
    assert_equal(fills[2].width, 40)

    var inset = (
        Layout.horizontal(
            [Constraint.length(20)],
            flex=Flex.END,
        )
        .with_margin(Margin(5, 2))
        .split(Rect(10, 20, 100, 10))
    )
    assert_equal(inset[0].x, 85)
    assert_equal(inset[0].y, 22)
    assert_equal(inset[0].width, 20)
    assert_equal(inset[0].height, 6)

    var named = (
        Layout.horizontal([Constraint.length(10)])
        .margin(2)
        .flex(Flex.END)
        .spacing(1)
        .split(Rect(0, 0, 20, 5))
    )
    assert_equal(named[0].x, 8)
    assert_equal(named[0].y, 2)
    assert_equal(named[0].height, 1)


def test_space_between_single_segment_stretches_like_ratatui() raises:
    var areas = Layout.horizontal(
        [Constraint.length(20)], flex=Flex.SPACE_BETWEEN
    ).split(Rect(4, 7, 100, 2))
    var area = areas[0].copy()
    assert_equal(area.x, 4)
    assert_equal(area.width, 100)


def test_empty_layout_returns_no_areas() raises:
    var layout = Layout.horizontal([])
    assert_equal(len(layout.split(Rect(0, 0, 10, 2))), 0)


def test_layout_stays_inside_area_across_small_widths() raises:
    for flex in [
        Flex.START,
        Flex.CENTER,
        Flex.END,
        Flex.SPACE_BETWEEN,
        Flex.SPACE_EVENLY,
        Flex.SPACE_AROUND,
    ]:
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
                flex=flex,
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
