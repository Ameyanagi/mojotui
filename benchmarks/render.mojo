"""Microbenchmarks for full, changed, and unchanged 80x24 ANSI frames."""

from std.benchmark import keep, run

from mojotui import Buffer, Cell, Rect, encode_ansi_diff


def encode_full_frame() raises:
    var area = Rect(0, 0, 80, 24)
    var blank = Buffer(area)
    var full = Buffer(area)
    full.fill(area, Cell("x"))
    var output = encode_ansi_diff(blank, full)
    keep(output)


def encode_changed_frame() raises:
    var area = Rect(0, 0, 80, 24)
    var blank = Buffer(area)
    var changed = blank.copy()
    _ = changed.set_cell({40, 12}, Cell("x"))
    var output = encode_ansi_diff(blank, changed)
    keep(output)


def encode_unchanged_frame() raises:
    var area = Rect(0, 0, 80, 24)
    var blank = Buffer(area)
    var unchanged = blank.copy()
    var output = encode_ansi_diff(blank, unchanged)
    keep(output)


def main() raises:
    var full_report = run(
        encode_full_frame,
        num_warmup_iters=5,
        min_runtime_secs=0.2,
        max_runtime_secs=2.0,
    )
    var changed_report = run(
        encode_changed_frame,
        num_warmup_iters=5,
        min_runtime_secs=0.2,
        max_runtime_secs=2.0,
    )
    var unchanged_report = run(
        encode_unchanged_frame,
        num_warmup_iters=5,
        min_runtime_secs=0.2,
        max_runtime_secs=2.0,
    )
    var full_us = full_report.mean("us")
    var changed_us = changed_report.mean("us")
    var unchanged_us = unchanged_report.mean("us")
    print("80x24 full ANSI diff mean (us):", full_us)
    print("80x24 one-cell ANSI diff mean (us):", changed_us)
    print("80x24 unchanged ANSI diff mean (us):", unchanged_us)
    print("full frames/second:", 1_000_000.0 / full_us)
    print("changed frames/second:", 1_000_000.0 / changed_us)
    print("unchanged frames/second:", 1_000_000.0 / unchanged_us)
