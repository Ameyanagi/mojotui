# MojoTUI benchmarks

Benchmarks measure rendering and editor workloads. They are reproducibility
tools, not standalone performance claims.

Run the current suites with:

```bash
pixi run bench
pixi run bench-editor
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
