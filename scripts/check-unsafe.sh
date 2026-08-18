#!/usr/bin/env bash
set -euo pipefail

unsafe_pattern='UnsafePointer|DTypePointer|external_call|OwnedDLHandle|unsafe_[[:alnum:]_]*'
allowlist_file='scripts/unsafe-allowlist.txt'

if matches=$(rg -n "$unsafe_pattern" mojotui \
  --glob '*.mojo' --glob '!mojotui/platform/**'); then
  printf '%s\n' "Unsafe or FFI operation found outside mojotui/platform:" >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

platform_files=$(rg -l "$unsafe_pattern" mojotui/platform --glob '*.mojo' || true)
for platform_file in $platform_files; do
  if ! rg -q "^${platform_file}$" "$allowlist_file"; then
    printf '%s\n' "Platform boundary file is not allowlisted: $platform_file" >&2
    exit 1
  fi
done

while IFS= read -r allowed_file; do
  if [[ -z "$allowed_file" || "$allowed_file" == \#* ]]; then
    continue
  fi
  if [[ ! -f "$allowed_file" ]]; then
    printf '%s\n' "Unsafe allowlist entry does not exist: $allowed_file" >&2
    exit 1
  fi
done < "$allowlist_file"

ffi_file='mojotui/platform/posix.mojo'
ffi_calls=$(rg -o 'external_call\[' "$ffi_file" | wc -l | tr -d ' ')
safety_notes=$(rg -o '# SAFETY:' "$ffi_file" | wc -l | tr -d ' ')
if [[ "$safety_notes" -lt "$ffi_calls" ]]; then
  printf '%s\n' \
    "$ffi_file has $ffi_calls FFI calls but only $safety_notes SAFETY notes." >&2
  exit 1
fi

printf '%s\n' \
  "Unsafe boundary check passed ($ffi_calls documented FFI calls in 1 allowlisted file)."
