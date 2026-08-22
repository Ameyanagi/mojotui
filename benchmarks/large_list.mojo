"""Compare eager and lazy 50k-row highlighted lists under viewport jumps."""

from std.benchmark import keep
from std.collections import List as MojoList
from std.sys import argv
from std.time import perf_counter_ns

from mojotui import (
    Buffer,
    Color,
    Line,
    List,
    ListItem,
    ListLineProvider,
    ListRenderContext,
    ListState,
    Rect,
    Style,
    StylePatch,
    VirtualList,
)


comptime _ROW_COUNT = 50_000
comptime _SAMPLES = 31


def _positions() -> MojoList[Int]:
    return [0, 11]


def _make_items() raises -> MojoList[ListItem]:
    var items = MojoList[ListItem](capacity=_ROW_COUNT)
    var patch = StylePatch(
        foreground=Color.indexed(6),
        add_modifiers=Style.BOLD,
    )
    for index in range(_ROW_COUNT):
        var content = String("result row ", index, " / preview text")
        var positions = _positions()
        items.append(ListItem.from_line(Line.highlighted(content^, positions, patch)))
    return items^


struct HighlightedRowProvider(Copyable, ListLineProvider):
    var count: Int
    var patch: StylePatch

    def __init__(out self, count: Int = _ROW_COUNT):
        self.count = count
        self.patch = StylePatch(
            foreground=Color.indexed(6),
            add_modifiers=Style.BOLD,
        )

    def item_count(self) -> Int:
        return self.count

    def line(self, context: ListRenderContext) raises -> Line:
        var content = String("result row ", context.index, " / preview text")
        var positions = _positions()
        return Line.highlighted(content^, positions, self.patch)


def _render_frames(
    widget: List,
    mut state: ListState,
    mut buffer: Buffer,
    frame_start: Int,
    frame_count: Int,
) raises -> Int:
    var area = buffer.area.copy()
    for frame in range(frame_count):
        state.selected = UInt(((frame_start + frame) * 49_979) % _ROW_COUNT)
        state.offset = 0
        widget.render(area, buffer, state)
    keep(state.offset)
    keep(buffer)
    return state.offset


def _render_virtual_frames(
    widget: VirtualList[HighlightedRowProvider],
    mut state: ListState,
    mut buffer: Buffer,
    frame_start: Int,
    frame_count: Int,
) raises -> Int:
    var area = buffer.area.copy()
    for frame in range(frame_count):
        state.selected = UInt(((frame_start + frame) * 49_979) % _ROW_COUNT)
        state.offset = 0
        widget.render(area, buffer, state)
    keep(state.offset)
    keep(buffer)
    return state.offset


def _sort_timings(mut values: MojoList[Int]):
    for index in range(1, len(values)):
        var value = values[index]
        var destination = index
        while destination > 0 and values[destination - 1] > value:
            values[destination] = values[destination - 1]
            destination -= 1
        values[destination] = value


def _benchmark() raises:
    var construction = MojoList[Int](capacity=_SAMPLES)
    for _ in range(_SAMPLES):
        var started = perf_counter_ns()
        var constructed = List(_make_items())
        keep(constructed)
        construction.append(perf_counter_ns() - started)
    _sort_timings(construction)

    var widget = List(_make_items())
    var frames = MojoList[Int](capacity=_SAMPLES)
    var list_state = ListState(selected=UInt(0))
    var list_buffer = Buffer(Rect(0, 0, 80, 24))
    for sample_index in range(_SAMPLES):
        var started = perf_counter_ns()
        _ = _render_frames(
            widget,
            list_state,
            list_buffer,
            sample_index * 100,
            100,
        )
        frames.append((perf_counter_ns() - started) // 100)
    _sort_timings(frames)

    var virtual_construction = MojoList[Int](capacity=_SAMPLES)
    var virtual_checksum = 0
    for sample_index in range(_SAMPLES):
        var started = perf_counter_ns()
        for index in range(10_000):
            var count = _ROW_COUNT + ((index + sample_index) % 2)
            var virtual = VirtualList(HighlightedRowProvider(count))
            virtual_checksum += virtual.provider.item_count()
            keep(virtual)
        virtual_construction.append((perf_counter_ns() - started) // 10_000)
    _sort_timings(virtual_construction)
    keep(virtual_checksum)

    var virtual = VirtualList(HighlightedRowProvider())
    var virtual_frames = MojoList[Int](capacity=_SAMPLES)
    var virtual_state = ListState(selected=UInt(0))
    var virtual_buffer = Buffer(Rect(0, 0, 80, 24))
    for sample_index in range(_SAMPLES):
        var started = perf_counter_ns()
        _ = _render_virtual_frames(
            virtual,
            virtual_state,
            virtual_buffer,
            sample_index * 100,
            100,
        )
        virtual_frames.append((perf_counter_ns() - started) // 100)
    _sort_timings(virtual_frames)
    print(
        "BENCH mojotui eager_large_list rows=50000 samples=31 ",
        "construct_p50_ns=",
        construction[15],
        " construct_p95_ns=",
        construction[29],
        " frame_batch_mean_p50_ns=",
        frames[15],
        " frame_batch_mean_p95_ns=",
        frames[29],
        sep="",
    )
    print(
        "BENCH mojotui virtual_large_list rows=50000 samples=31 ",
        "construct_batch_mean_p50_ns=",
        virtual_construction[15],
        " construct_batch_mean_p95_ns=",
        virtual_construction[29],
        " frame_batch_mean_p50_ns=",
        virtual_frames[15],
        " frame_batch_mean_p95_ns=",
        virtual_frames[29],
        sep="",
    )


def _profile_eager() raises:
    var checksum = 0
    var state = ListState(selected=UInt(0))
    var buffer = Buffer(Rect(0, 0, 80, 24))
    # Keep the workload alive beyond the seven-second sampler window used in
    # benchmarks/README.md, including on optimized release builds.
    for iteration in range(80):
        var widget = List(_make_items())
        checksum += len(widget.items)
        checksum += _render_frames(widget, state, buffer, iteration * 1_000, 1_000)
    keep(checksum)


def _profile_virtual() raises:
    var checksum = 0
    var widget = VirtualList(HighlightedRowProvider())
    var state = ListState(selected=UInt(0))
    var buffer = Buffer(Rect(0, 0, 80, 24))
    for iteration in range(2_000):
        checksum += _render_virtual_frames(widget, state, buffer, iteration * 100, 100)
    keep(checksum)


def main() raises:
    var arguments = argv()
    if len(arguments) > 1 and String(arguments[1]) == "profile-eager":
        _profile_eager()
    elif len(arguments) > 1 and String(arguments[1]) == "profile-virtual":
        _profile_virtual()
    else:
        _benchmark()
