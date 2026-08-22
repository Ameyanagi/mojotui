#!/usr/bin/env bash
set -euo pipefail

package_name='mojo-mojotui'
version="$(sed -n 's/^version = "\([^"]*\)"$/\1/p' pixi.toml)"
artifacts="$({
  find output -type f -name "${package_name}-${version}-*.conda" \
    ! -path 'output/broken/*' ! -path 'output/test/*' -print
})"
count="$(printf '%s\n' "$artifacts" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
[[ "$count" -eq 1 ]] || {
  echo "expected one ${package_name}-${version} artifact; found $count" >&2
  exit 1
}

extract_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mojotui-package.XXXXXX")"
trap 'rm -rf -- "$extract_dir"' EXIT
pixi run rattler-build package extract "$artifacts" --dest "$extract_dir" >/dev/null
index_json="$extract_dir/info/index.json"
[[ -f "$index_json" ]] || {
  echo "package is missing info/index.json" >&2
  exit 1
}

grep -Fq '"name": "mojo-mojotui"' "$index_json"
grep -Fq "\"version\": \"$version\"" "$index_json"
compiler_dependencies="$(grep -o '"mojo-compiler[^"]*"' "$index_json" || true)"
moji_dependencies="$(grep -o '"mojo-moji[^"]*"' "$index_json" || true)"
[[ "$compiler_dependencies" == '"mojo-compiler ==1.0.0"' ]] || {
  echo "expected exact runtime mojo-compiler ==1.0.0; found ${compiler_dependencies:-none}" >&2
  exit 1
}
[[ "$moji_dependencies" == '"mojo-moji ==0.1.0"' ]] || {
  echo "expected exact runtime mojo-moji ==0.1.0; found ${moji_dependencies:-none}" >&2
  exit 1
}

echo "package metadata passed for ${package_name} ${version}"
