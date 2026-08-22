"""Long uniform-list and table viewport-jump benchmarks."""

from std.benchmark import keep
from std.collections import List as MojoList
from std.time import perf_counter_ns

from mojotui import (
    Buffer,
    Constraint,
    Line,
    List,
    ListItem,
    ListState,
    Rect,
    Row,
    Table,
    TableState,
)


def main() raises:
    comptime ROW_COUNT = 50_000
    comptime ITERATIONS = 500

    var items = MojoList[ListItem](capacity=ROW_COUNT)
    var rows = MojoList[Row](capacity=ROW_COUNT)
    for _ in range(ROW_COUNT):
        items.append(ListItem.from_text("item"))
        rows.append(Row.from_lines([Line.from_text("row")]))

    var list = List(items^)
    var list_state = ListState()
    var list_buffer = Buffer(Rect(0, 0, 80, 24))
    var list_area = list_buffer.area.copy()
    var list_started = perf_counter_ns()
    for index in range(ITERATIONS):
        list_state.selected = UInt((index * 49_979) % ROW_COUNT)
        list_state.offset = 0
        list.render(list_area, list_buffer, list_state)
    var list_elapsed = perf_counter_ns() - list_started
    keep(list_state.offset)

    var table = Table(rows^, [Constraint.fill()])
    var table_state = TableState()
    var table_buffer = Buffer(Rect(0, 0, 80, 24))
    var table_area = table_buffer.area.copy()
    var table_started = perf_counter_ns()
    for index in range(ITERATIONS):
        table_state.selected = UInt((index * 49_979) % ROW_COUNT)
        table_state.offset = 0
        table.render(table_area, table_buffer, table_state)
    var table_elapsed = perf_counter_ns() - table_started
    keep(table_state.offset)

    print("rows:", ROW_COUNT)
    print("viewport jumps:", ITERATIONS)
    print(
        "list viewport mean (us):",
        Float64(list_elapsed) / Float64(ITERATIONS * 1_000),
    )
    print(
        "table viewport mean (us):",
        Float64(table_elapsed) / Float64(ITERATIONS * 1_000),
    )
