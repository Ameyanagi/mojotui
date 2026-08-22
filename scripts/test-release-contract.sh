#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
contract_check="${script_dir}/check-release-contract.sh"
release_workflow="${script_dir}/../.github/workflows/release.yml"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/mojotui-release-contract.XXXXXX")"
trap 'rm -rf -- "$fixture_dir"' EXIT

write_metadata() {
  local version="${1:-0.1.1}"
  local mojo="${2:-==1.0.0}"
  local moji="${3:-==0.1.0}"
  local recipe_version="${4:-$version}"
  printf '%s\n' \
    '[workspace]' \
    "version = \"$version\"" \
    '[dependencies]' \
    "mojo = \"$mojo\"" \
    "mojo-moji = \"$moji\"" >"${fixture_dir}/pixi.toml"
  mkdir -p "${fixture_dir}/conda.recipe"
  printf '%s\n' \
    'context:' \
    "  version: \"$recipe_version\"" \
    'requirements:' \
    '  build:' \
    '    - mojo-compiler ==1.0.0' \
    '    - mojo-moji ==0.1.0' \
    '  host:' \
    '    - mojo-compiler ==1.0.0' \
    '    - mojo-moji ==0.1.0' \
    '  run:' \
    '    - mojo-compiler ==1.0.0' \
    '    - mojo-moji ==0.1.0' >"${fixture_dir}/conda.recipe/recipe.yaml"
  printf '## [%s] - 2026-08-22\n' "$version" >"${fixture_dir}/CHANGELOG.md"
}

expect_failure() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "release contract unexpectedly accepted $description" >&2
    exit 1
  fi
}

git -C "$fixture_dir" init --quiet
git -C "$fixture_dir" config user.name 'Mojotui release test'
git -C "$fixture_dir" config user.email 'release-test@example.invalid'
write_metadata
git -C "$fixture_dir" add .
git -C "$fixture_dir" commit --quiet -m 'release fixture'
commit="$(git -C "$fixture_dir" rev-parse HEAD)"
git -C "$fixture_dir" update-ref refs/remotes/origin/main "$commit"
git -C "$fixture_dir" tag --annotate v0.1.1 -m 'annotated release'

run_tag_check() {
  local sha="${1:-$commit}"
  (
    cd "$fixture_dir"
    GITHUB_REF='refs/tags/v0.1.1' \
      GITHUB_REF_NAME='v0.1.1' \
      GITHUB_SHA="$sha" \
      bash "$contract_check"
  )
}

(cd "$fixture_dir" && bash "$contract_check" --metadata-only) >/dev/null
run_tag_check >/dev/null
zero_sha="0000000000000000000000000000000000000000"
expect_failure 'a mismatched tag target' run_tag_check "$zero_sha"

git -C "$fixture_dir" tag --delete v0.1.1 >/dev/null
git -C "$fixture_dir" tag v0.1.1
expect_failure 'a lightweight tag' run_tag_check
git -C "$fixture_dir" tag --delete v0.1.1 >/dev/null
git -C "$fixture_dir" tag --annotate v0.1.1 -m 'annotated release'

write_metadata 0.1.1 '>=1.0'
expect_failure 'an inexact workspace compiler' bash -c "cd '$fixture_dir' && bash '$contract_check' --metadata-only"
write_metadata 0.1.1 ==1.0.0 ==0.1.0 0.1.2
expect_failure 'a recipe version mismatch' bash -c "cd '$fixture_dir' && bash '$contract_check' --metadata-only"
write_metadata
perl -0pi -e 's/mojo-moji ==0\.1\.0/mojo-moji/' "${fixture_dir}/conda.recipe/recipe.yaml"
expect_failure 'an inexact recipe dependency' bash -c "cd '$fixture_dir' && bash '$contract_check' --metadata-only"

if ! grep -Fq 'GH_REPO: ${{ github.repository }}' "$release_workflow"; then
  echo 'release publisher must set GH_REPO before running outside a Git checkout' >&2
  exit 1
fi

echo 'release contract tests passed (metadata, exact dependencies, annotated tag, target, ancestry, and repository context)'
