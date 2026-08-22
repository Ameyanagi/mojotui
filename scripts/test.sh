#!/usr/bin/env bash
set -euo pipefail

for test_file in tests/test_*.mojo; do
  mojo run -I . "$test_file"
done

mkdir -p .pixi/test-bin
mojo build -I . examples/hello.mojo -o .pixi/test-bin/hello
mojo build -I . examples/hello_loop.mojo -o .pixi/test-bin/hello-loop
mojo build -I . examples/counter.mojo -o .pixi/test-bin/counter
mojo build -I . examples/dashboard.mojo -o .pixi/test-bin/dashboard
mojo build -I . examples/editor.mojo -o .pixi/test-bin/editor
mojo build -I . examples/fuzzy.mojo -o .pixi/test-bin/fuzzy
mojo build -I . examples/form.mojo -o .pixi/test-bin/form
mojo build -I . examples/virtual_list.mojo -o .pixi/test-bin/virtual-list
mojo build -I . tests/fixtures/session_probe.mojo -o .pixi/test-bin/session-probe
python scripts/test-pty.py \
  .pixi/test-bin/session-probe \
  .pixi/test-bin/editor \
  .pixi/test-bin/virtual-list
