#!/usr/bin/env bash
set -euo pipefail

format_roots=(mojotui tests)

for optional_root in examples benchmarks; do
  if [[ -d "$optional_root" ]]; then
    format_roots+=("$optional_root")
  fi
done

find "${format_roots[@]}" -type f -name '*.mojo' -print0 \
  | xargs -0 mojo format -l 88
