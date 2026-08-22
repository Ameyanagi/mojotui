# MojoTUI benchmarks

Benchmarks measure rendering and editor workloads. They are reproducibility
tools, not standalone performance claims.

Run the current suites with:

```bash
pixi run bench
pixi run bench-editor
pixi run bench-collections
pixi run bench-large-list
pixi run profile-render-build
pixi run profile-large-list-build
```

When reporting results, record:

- CPU and architecture
- operating system and terminal environment
- Mojo and compiler version
- compiler options and build mode
- benchmark workload and input size
- warmup policy and iteration count
- reported metric and measurement method

Compare results only under equivalent conditions. Add representative workloads
and correctness checks before using a benchmark to guide optimization.

The render suite constructs both 80x24 buffers inside each measured operation,
then diffs and encodes ANSI into memory. It covers a fully changed frame, one
changed cell, and an unchanged frame. It deliberately excludes terminal I/O and
emulator painting.

The collections suite constructs 50,000 uniform list items and table rows before
measurement, then repeatedly jumps between distant 80x24 viewports. It isolates
viewport adjustment and visible-row rendering from collection construction.

The large-list suite reports nearest-rank p50/p95 construction and viewport
frame time for eager `List` and lazy `VirtualList` versions of the same 50,000
highlighted rows. Eager construction includes line highlighting, every
`ListItem`, the backing collection, and the `List` itself. Each frame value is
the mean of a 100-frame batch; p50/p95 are selected from 31 independent batch
means. The tiny lazy-construction value is likewise a per-widget mean from a
10,000-construction batch, which keeps timer resolution from dominating. The
suite also contains long-running modes for an operating-system sampling
profiler:

```bash
pixi run profile-large-list-build
.pixi/large-list-profile profile-eager &
sample $! 7 -file /tmp/mojotui-eager-profile.txt

.pixi/large-list-profile profile-virtual &
sample $! 7 -file /tmp/mojotui-virtual-profile.txt
```

The profiling task requests `-O3 -g1`: optimized code plus line-table symbols.
Mojo 1.0 already defaults to optimization level 3, so this makes the evidence
reproducible rather than claiming a new speedup.

On an Apple M4 running macOS 26.5.1 on 2026-08-22, the optimized `v0.1.1`
candidate's eager profile attributed 2,679 of 5,966 steady-state main-thread
samples (44.9%) to constructing all rows. Allocation was the largest resolved
child, and peak physical footprint was 41.4 MiB. The lazy profile had no eager
construction phase and a 6.6 MiB peak footprint; its remaining visible-row
costs were rich-line highlighting/allocation and `Buffer.fill`. These are
grapheme-aware, variable-length object operations, so this change does not add
an unsafe or semantically invalid SIMD path.

The same compiled binary reported full eager widget construction at 99.963 ms
p50 and 101.082 ms p95. Its 100-frame batch means were 67.540 µs p50 and 68.380
µs p95 per frame. Lazy widget/provider construction batch means were 5 ns at
both p50 and p95; generating and highlighting the 24 visible rows produced
107.740 µs p50 and 109.970 µs p95 per frame. The optimized render suite measured
107.331 µs for a full 80x24 ANSI frame, 75.358 µs for a one-cell change, and
73.426 µs for an unchanged frame. Thus lazy formatting trades on-demand visible
formatting for removal of the 50,000-row startup phase and an 84% lower sampled
process peak in these two profiling workloads. Re-run the suites on the target
machine rather than treating these observations as universal constants.
