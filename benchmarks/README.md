# MojoTUI benchmarks

Benchmarks measure rendering and editor workloads. They are reproducibility
tools, not standalone performance claims.

Run the current suites with:

```bash
pixi run bench
pixi run bench-editor
pixi run bench-collections
pixi run bench-large-list
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
pixi run mojo build -I . benchmarks/large_list.mojo -o .pixi/large-list-profile
.pixi/large-list-profile profile-eager &
sample $! 7 -file /tmp/mojotui-eager-profile.txt

.pixi/large-list-profile profile-virtual &
sample $! 7 -file /tmp/mojotui-virtual-profile.txt
```

On an Apple M4 running macOS 26.5.1 on 2026-08-22, the eager profile attributed
2,797 of 5,614 steady-state main-thread samples (49.8%) to constructing all rows. Allocation
and `Line.highlighted` were the two largest resolved children, and peak physical
footprint was 41.4 MiB. The lazy profile had no eager construction phase and a
6.6 MiB peak footprint; its remaining visible-row costs were rich-line
highlighting/allocation and `Buffer.fill`. These are grapheme-aware,
variable-length object operations, so this change does not add an unsafe or
semantically invalid SIMD path.

The same compiled binary reported full eager widget construction at 141.862 ms
p50 and 163.180 ms p95. Its 100-frame batch means were 67.880 µs p50 and 78.370
µs p95 per frame. Lazy widget/provider construction batch means were 6 ns at
both p50 and p95; generating and highlighting the 24 visible rows produced
121.950 µs p50 and 150.370 µs p95 per frame. Thus lazy formatting trades
on-demand visible formatting for removal of the 50,000-row startup phase and an
84% lower sampled peak footprint. Re-run the p50/p95 suite on the target machine
rather than treating these observations as universal constants.
