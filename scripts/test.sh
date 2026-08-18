#!/usr/bin/env bash
set -euo pipefail

for test_file in tests/test_*.mojo; do
  mojo run -I . "$test_file"
done

mkdir -p .pixi/test-bin
mojo build -I . examples/hello.mojo -o .pixi/test-bin/hello
mojo build -I . examples/dashboard.mojo -o .pixi/test-bin/dashboard
mojo build -I . tests/fixtures/session_probe.mojo -o .pixi/test-bin/session-probe
python scripts/test-pty.py .pixi/test-bin/session-probe
