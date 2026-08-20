#!/usr/bin/env bash
set -euo pipefail

package_version="$(sed -n 's/^version = "\([^"]*\)"$/\1/p' pixi.toml)"
mojo_requirement="$(sed -n 's/^mojo = "\([^"]*\)"$/\1/p' pixi.toml)"
expected_tag="v${package_version}"
expected_ref="refs/tags/${expected_tag}"

if [[ -z "$package_version" || "$package_version" == *$'\n'* ]]; then
  printf '%s\n' 'Release builds require one workspace version.' >&2
  exit 1
fi

if [[ "${GITHUB_REF_NAME:-}" != "$expected_tag" ]]; then
  printf '%s\n' \
    "Expected tag ${expected_tag}, received ${GITHUB_REF_NAME:-<unset>}." >&2
  exit 1
fi

if [[ "${GITHUB_REF:-}" != "$expected_ref" ]]; then
  printf '%s\n' \
    "Expected release ref ${expected_ref}, received ${GITHUB_REF:-<unset>}." >&2
  exit 1
fi

if [[ ! "$mojo_requirement" =~ ^==[[:alnum:].]+$ ]]; then
  printf '%s\n' 'Release builds require one exact Mojo compiler pin.' >&2
  exit 1
fi

tag_type="$(git cat-file -t "$GITHUB_REF" 2>/dev/null || true)"
if [[ "$tag_type" != 'tag' ]]; then
  printf '%s\n' \
    "Release ref ${GITHUB_REF} must be an annotated or signed tag object; found ${tag_type:-nothing}." >&2
  exit 1
fi

printf '%s\n' \
  "Release contract passed for ${expected_tag} and Mojo ${mojo_requirement}."
