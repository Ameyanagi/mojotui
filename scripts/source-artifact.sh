#!/usr/bin/env bash
# Shared source handoff for PR smoke tests and releases. Run create in a checkout.
set -euo pipefail

usage() {
  echo 'usage: source-artifact.sh create REF STEM OUTPUT | restore STEM ARCHIVES DESTINATION' >&2
  exit 2
}
[[ $# -eq 4 ]] || usage
operation="$1"
if [[ "$operation" == create ]]; then
  reference="$2"
  stem="$3"
  output="$4"
elif [[ "$operation" == restore ]]; then
  stem="$2"
  output="$3"
  destination="$4"
else
  usage
fi
[[ "$stem" =~ ^mojotui-[A-Za-z0-9._-]+$ ]] || {
  echo "invalid archive stem '$stem'; use mojotui- followed by letters, digits, dots, underscores or hyphens" >&2
  exit 2
}
archive="${stem}.tar.gz"

if [[ "$operation" == create ]]; then
  mkdir -p "$output"
  git archive --format=tar.gz --prefix="${stem}/" \
    --output="${output}/${archive}" "$reference"
  (
    cd "$output"
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$archive" > "${archive}.sha256"
    else
      shasum -a 256 "$archive" > "${archive}.sha256"
    fi
  )
else
  (
    cd "$output"
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum --check "${archive}.sha256"
    else
      shasum -a 256 --check "${archive}.sha256"
    fi
  )
  if [[ -e "$destination" || -L "$destination" ]]; then
    echo "restore destination '$destination' already exists; choose a fresh directory" >&2
    exit 1
  fi
  mkdir "$destination"
  tar -xzf "${output}/${archive}" --strip-components=1 -C "$destination"
  for required in pixi.toml pixi.lock mojotui/__init__.mojo conda.recipe/recipe.yaml conda.recipe/test_package.mojo; do
    test -s "${destination}/${required}" || {
      echo "restored source is missing required file '$required'" >&2
      exit 1
    }
  done
  test ! -e "${destination}/.git"
fi
