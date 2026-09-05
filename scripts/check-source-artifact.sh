#!/usr/bin/env bash
# Invoke from an extracted artifact after Pixi installs its locked environment.
set -euo pipefail
source_root="$PWD"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/mojotui-source-compile.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT
mojo precompile --Werror --warn-on-unstable-apis mojotui -o "${fixture}/mojotui.mojoc"
cp conda.recipe/test_package.mojo "${fixture}/consumer.mojo"
# No source checkout on the import path: resolve Mojotui from the new .mojoc.
cd "$fixture"
mojo run -I "$fixture" consumer.mojo
echo "extracted source compiled and packaged consumer passed: ${source_root}"
