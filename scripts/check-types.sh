#!/usr/bin/env bash
set -euo pipefail

# Mojo 1.1 has unified function declarations on `def`.  The old `fn`
# declaration is rejected by the pinned compiler, so it cannot be used as a
# proxy for strictness.  Strictness comes from typed signatures, explicit
# effects, static generic constraints, and compiler validation.
if matches=$(rg -n '^[[:space:]]*(async[[:space:]]+)?fn[[:space:]]+[[:alnum:]_`]+' \
  mojotui --glob '*.mojo'); then
  printf '%s\n' 'Obsolete fn declaration found; Mojo 1.1 requires def:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

# Keep dynamic interop types out of the library surface.  A future adapter may
# request a narrowly scoped exception, but it must not silently weaken core
# APIs.
dynamic_pattern='\b(AnyType|PythonObject)\b'
if matches=$(rg -n "$dynamic_pattern" mojotui --glob '*.mojo'); then
  printf '%s\n' 'Dynamic escape-hatch type found in the Mojotui package:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

printf '%s\n' \
  'Strict type policy passed (modern def syntax; no dynamic escape hatches).'
