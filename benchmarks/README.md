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
