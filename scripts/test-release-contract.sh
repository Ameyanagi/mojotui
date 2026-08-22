#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
contract_check="${script_dir}/check-release-contract.sh"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/mojotui-release-contract.XXXXXX")"

cleanup() {
  if [[ -n "${fixture_dir:-}" && -d "$fixture_dir" ]]; then
    rm -rf -- "$fixture_dir"
  fi
}
trap cleanup EXIT

printf '%s\n' \
  '[workspace]' \
  'name = "mojotui"' \
  'version = "0.1.0"' \
  '' \
  '[dependencies]' \
  'mojo = "==1.0.0"' > "${fixture_dir}/pixi.toml"

git -C "$fixture_dir" init --quiet
git -C "$fixture_dir" config user.name 'Mojotui release test'
git -C "$fixture_dir" config user.email 'release-test@example.invalid'
git -C "$fixture_dir" add pixi.toml
git -C "$fixture_dir" commit --quiet -m 'release fixture'
git -C "$fixture_dir" tag --annotate v0.1.0 -m 'annotated release'
git -C "$fixture_dir" tag --annotate v0.1.1 -m 'wrong release version'

run_contract_check() {
  local ref_name="$1"
  (
    cd "$fixture_dir"
    GITHUB_REF="refs/tags/${ref_name}" \
      GITHUB_REF_NAME="$ref_name" \
      bash "$contract_check"
  )
}

expect_failure() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '%s\n' "Release contract unexpectedly accepted ${description}." >&2
    exit 1
  fi
}

run_contract_check v0.1.0 >/dev/null
expect_failure 'a mismatched version tag' run_contract_check v0.1.1

git -C "$fixture_dir" tag --delete v0.1.0 >/dev/null
git -C "$fixture_dir" tag v0.1.0
expect_failure 'a lightweight tag' run_contract_check v0.1.0

git -C "$fixture_dir" tag --delete v0.1.0 >/dev/null
git -C "$fixture_dir" tag --annotate v0.1.0 -m 'annotated release'
printf '%s\n' \
  '[workspace]' \
  'name = "mojotui"' \
  'version = "0.1.0"' \
  '' \
  '[dependencies]' \
  'mojo = "==1.0.1"' > "${fixture_dir}/pixi.toml"
expect_failure 'a different exact compiler version' run_contract_check v0.1.0

printf '%s\n' \
  '[workspace]' \
  'name = "mojotui"' \
  'version = "0.1.0"' \
  '' \
  '[dependencies]' \
  'mojo = ">=1.0"' > "${fixture_dir}/pixi.toml"
expect_failure 'an inexact compiler requirement' run_contract_check v0.1.0

printf '%s\n' \
  'Release contract tests passed (annotated stable-1.0.0 accepted; version, tag type, and compiler guards rejected invalid fixtures).'
