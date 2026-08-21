from std.collections import List as MojoList
from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from mojotui import (
    Axis,
    Buffer,
    Chart,
    Color,
    Dataset,
    GraphKind,
    Marker,
    Rect,
    Style,
)


def row(buffer: Buffer, y: Int) raises -> String:
    var result = String()
    for x in range(buffer.area.x, buffer.area.right()):
        var cell = buffer.cell({x, y})
        result += "" if cell.continuation else cell.symbol
    return result^


def braille_corner(x: Float64, y: Float64) raises -> String:
    var xs: MojoList[Float64] = [x]
    var ys: MojoList[Float64] = [y]
    var datasets: MojoList[Dataset] = [Dataset(xs, ys, kind=GraphKind.SCATTER)]
    var buffer = Buffer(Rect(0, 0, 2, 2))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 1.0), Axis(0.0, 1.0)).render(area, buffer)
    return buffer.cell({1, 0}).symbol


def point_dataset(x: Float64, style: Style = Style.plain()) raises -> Dataset:
    var xs: MojoList[Float64] = [x]
    var ys: MojoList[Float64] = [0.0]
    return Dataset(
        xs,
        ys,
        kind=GraphKind.SCATTER,
        marker=Marker.DOT,
        style=style,
    )


def empty_dataset() raises -> Dataset:
    var xs = MojoList[Float64]()
    var ys = MojoList[Float64]()
    return Dataset(xs, ys, kind=GraphKind.SCATTER, marker=Marker.DOT)


def test_chart_braille_bit_table_and_full_cell() raises:
    var xs: MojoList[Float64] = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0]
    var ys: MojoList[Float64] = [3.0, 2.0, 1.0, 0.0, 3.0, 2.0, 1.0, 0.0]
    var datasets: MojoList[Dataset] = [Dataset(xs, ys, kind=GraphKind.SCATTER)]
    var buffer = Buffer(Rect(0, 0, 2, 2))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 1.0), Axis(0.0, 3.0)).render(area, buffer)
    assert_equal(row(buffer, 0), "│⣿")
    assert_equal(row(buffer, 1), "└─")

    assert_equal(braille_corner(0.0, 1.0), "⠁")
    assert_equal(braille_corner(0.0, 0.0), "⡀")
    assert_equal(braille_corner(1.0, 1.0), "⠈")
    assert_equal(braille_corner(1.0, 0.0), "⢀")


def test_chart_braille_line_diagonal_snapshot() raises:
    var xs: MojoList[Float64] = [0.0, 1.0]
    var ys: MojoList[Float64] = [0.0, 1.0]
    var datasets: MojoList[Dataset] = [Dataset(xs, ys)]
    var buffer = Buffer(Rect(0, 0, 4, 3))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 1.0), Axis(0.0, 1.0)).render(area, buffer)
    assert_equal(row(buffer, 0), "│ ⢀⠎")
    assert_equal(row(buffer, 1), "│⡰⠁ ")
    assert_equal(row(buffer, 2), "└───")


def test_chart_dot_scatter_rounds_and_skips_out_of_bounds_points() raises:
    var xs: MojoList[Float64] = [0.0, 1.6, 4.0, -1.0, 5.0, Float64("nan")]
    var ys: MojoList[Float64] = [0.0, 0.6, 0.0, 0.5, 0.5, 0.5]
    var datasets: MojoList[Dataset] = [
        Dataset(xs, ys, kind=GraphKind.SCATTER, marker=Marker.DOT)
    ]
    var buffer = Buffer(Rect(0, 0, 6, 3))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 4.0), Axis(0.0, 1.0)).render(area, buffer)
    assert_equal(row(buffer, 0), "│  •  ")
    assert_equal(row(buffer, 1), "│•   •")
    assert_equal(row(buffer, 2), "└─────")


def test_chart_line_does_not_clip_invalid_endpoints() raises:
    var xs: MojoList[Float64] = [-1.0, 0.0, Float64("nan"), 1.0, 2.0]
    var ys: MojoList[Float64] = [0.0, 0.0, 0.5, 1.0, 1.0]
    var datasets: MojoList[Dataset] = [Dataset(xs, ys)]
    var buffer = Buffer(Rect(0, 0, 4, 3))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 1.0), Axis(0.0, 1.0)).render(area, buffer)
    assert_equal(row(buffer, 0), "│   ")
    assert_equal(row(buffer, 1), "│   ")
    assert_equal(row(buffer, 2), "└───")


def test_chart_block_scatter_uses_full_cell_glyphs() raises:
    var xs: MojoList[Float64] = [0.0, 1.0]
    var ys: MojoList[Float64] = [0.0, 1.0]
    var datasets: MojoList[Dataset] = [
        Dataset(xs, ys, kind=GraphKind.SCATTER, marker=Marker.BLOCK)
    ]
    var buffer = Buffer(Rect(0, 0, 4, 3))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 1.0), Axis(0.0, 1.0)).render(area, buffer)
    assert_equal(row(buffer, 0), "│  █")
    assert_equal(row(buffer, 1), "│█  ")
    assert_equal(row(buffer, 2), "└───")


def test_chart_axis_layout_snapshot() raises:
    var x_labels: MojoList[String] = ["0", "5", "10"]
    var y_labels: MojoList[String] = ["0", "100"]
    var datasets = MojoList[Dataset]()
    var buffer = Buffer(Rect(0, 0, 12, 6))
    var area = buffer.area.copy()
    Chart(
        datasets^,
        Axis(0.0, 10.0, labels=x_labels),
        Axis(0.0, 100.0, labels=y_labels),
    ).render(area, buffer)
    assert_equal(row(buffer, 0), "100│        ")
    assert_equal(row(buffer, 1), "   │        ")
    assert_equal(row(buffer, 2), "   │        ")
    assert_equal(row(buffer, 3), "  0│        ")
    assert_equal(row(buffer, 4), "   └────────")
    assert_equal(row(buffer, 5), "    0   5 10")


def test_chart_axis_titles_overwrite_axis_regions() raises:
    var datasets = MojoList[Dataset]()
    var buffer = Buffer(Rect(0, 0, 8, 4))
    var area = buffer.area.copy()
    Chart(
        datasets^,
        Axis(0.0, 1.0, title="time"),
        Axis(0.0, 1.0, title="Y"),
    ).render(area, buffer)
    assert_equal(row(buffer, 0), "Y       ")
    assert_equal(row(buffer, 1), "│       ")
    assert_equal(row(buffer, 2), "└───time")
    assert_equal(row(buffer, 3), "        ")


def test_chart_default_color_cycle_wraps_and_preserves_explicit_style() raises:
    var explicit = Style(foreground=Color.indexed(9), modifiers=Style.BOLD)
    var datasets: MojoList[Dataset] = [
        point_dataset(0.0),
        point_dataset(3.0, explicit),
        empty_dataset(),
        empty_dataset(),
        empty_dataset(),
        empty_dataset(),
        point_dataset(7.0),
    ]
    var buffer = Buffer(Rect(0, 0, 9, 2))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 7.0), Axis(0.0, 1.0)).render(area, buffer)
    assert_true(buffer.cell({1, 0}).style.foreground.equals(Color.indexed(6)))
    assert_true(buffer.cell({8, 0}).style.foreground.equals(Color.indexed(6)))
    assert_true(buffer.cell({4, 0}).style.equals(explicit))


def test_chart_later_braille_dataset_replaces_cell_bits() raises:
    var first_xs: MojoList[Float64] = [0.0]
    var first_ys: MojoList[Float64] = [1.0]
    var second_xs: MojoList[Float64] = [1.0]
    var second_ys: MojoList[Float64] = [0.0]
    var datasets: MojoList[Dataset] = [
        Dataset(first_xs, first_ys, kind=GraphKind.SCATTER),
        Dataset(second_xs, second_ys, kind=GraphKind.SCATTER),
    ]
    var buffer = Buffer(Rect(0, 0, 2, 2))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 1.0), Axis(0.0, 1.0)).render(area, buffer)
    assert_equal(row(buffer, 0), "│⢀")
    assert_true(buffer.cell({1, 0}).style.foreground.equals(Color.indexed(3)))


def test_chart_constructors_reject_invalid_ranges_and_lengths() raises:
    with assert_raises(contains="lower must be non-NaN; got lower=nan"):
        _ = Axis(Float64("nan"), 1.0)
    with assert_raises(contains="upper must be non-NaN; got upper=nan"):
        _ = Axis(0.0, Float64("nan"))
    with assert_raises(
        contains="lower must be less than upper; got lower=1.0, upper=1.0"
    ):
        _ = Axis(1.0, 1.0)

    var xs: MojoList[Float64] = [0.0]
    var ys: MojoList[Float64] = [0.0, 1.0]
    with assert_raises(
        contains="xs and ys must have equal lengths; got len(xs)=1, len(ys)=2"
    ):
        _ = Dataset(xs, ys)


def test_chart_empty_dataset_and_empty_area_do_not_raise() raises:
    var datasets: MojoList[Dataset] = [empty_dataset()]
    var buffer = Buffer(Rect(0, 0, 2, 2))
    var area = buffer.area.copy()
    Chart(datasets^, Axis(0.0, 1.0), Axis(0.0, 1.0)).render(area, buffer)
    assert_equal(row(buffer, 0), "│ ")
    assert_equal(row(buffer, 1), "└─")

    var empty_datasets = MojoList[Dataset]()
    var empty = Buffer(Rect(0, 0, 0, 0))
    Chart(empty_datasets^, Axis(0.0, 1.0), Axis(0.0, 1.0)).render(Rect(), empty)
    assert_equal(len(empty), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
