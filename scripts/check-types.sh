#!/usr/bin/env bash
set -euo pipefail

# Mojo has unified function declarations on `def`. The old `fn` declaration is
# deprecated upstream and rejected by project policy and the warnings-as-errors
# build, so it cannot be used as a proxy for strictness. Strictness comes from
# typed signatures, explicit effects, static generic constraints, and compiler
# validation.
if matches=$(rg -n '^[[:space:]]*(async[[:space:]]+)?fn[[:space:]]+[[:alnum:]_`]+' \
  mojotui --glob '*.mojo'); then
  printf '%s\n' 'Deprecated fn declaration found; Mojotui requires def:' >&2
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

migrated_semantic_int_pattern='var (alignment|appearance|control|direction|flex|message_class|orientation|profile|wrap_mode): Int'
if matches=$(rg -n "$migrated_semantic_int_pattern" mojotui --glob '*.mojo'); then
  printf '%s\n' 'A migrated semantic field regressed to a raw Int:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

if matches=$(rg -n 'var selected: Int' mojotui/widgets/collection.mojo); then
  printf '%s\n' 'Collection selection must remain an Optional unsigned index:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

event_editor_int_pattern='var (button|code|kind|modifiers): Int'
if matches=$(rg -n "$event_editor_int_pattern" \
  mojotui/event/input.mojo \
  mojotui/app/keymap.mojo \
  mojotui/editor/commands.mojo \
  mojotui/editor/controllers.mojo); then
  printf '%s\n' 'A migrated event or editor discriminator regressed to Int:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

if matches=$(rg -n 'var (affinity|line_ending|source): Int' \
  mojotui/editor/document.mojo mojotui/editor/file_service.mojo); then
  printf '%s\n' 'A migrated editor semantic field regressed to Int:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

if matches=$(rg -n 'var desired_column: Int' mojotui/editor); then
  printf '%s\n' 'Sticky editor columns must represent absence with Optional:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

if matches=$(rg -n 'var (borders|border_type|highlight_spacing|kind|modifiers|selection|title_position): Int' \
  mojotui/core/style.mojo mojotui/widgets/basic.mojo); then
  printf '%s\n' 'A migrated style or border field regressed to Int:' >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

# These fixtures must remain ill-typed. They prove that semantic values cannot
# silently cross public API boundaries as unrelated integers and that absence
# is not represented by a negative collection index.
type_check_dir=$(mktemp -d "${TMPDIR:-/tmp}/mojotui-type-check.XXXXXX")
cleanup() {
  if [[ -n "${type_check_dir:-}" && -d "$type_check_dir" ]]; then
    rm -rf -- "$type_check_dir"
  fi
}
trap cleanup EXIT

for fixture in tests/compile_fail/*.mojo; do
  artifact="$type_check_dir/$(basename "${fixture%.mojo}")"
  if mojo build -I . "$fixture" -o "$artifact" >/dev/null 2>&1; then
    printf '%s\n' "Compile-fail fixture unexpectedly succeeded: $fixture" >&2
    exit 1
  fi
done

printf '%s\n' \
  'Strict type policy passed (modern def syntax, nominal APIs, no dynamic escape hatches).'
