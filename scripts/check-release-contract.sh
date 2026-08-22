#!/usr/bin/env bash
set -euo pipefail

metadata_only=false
if [[ "${1:-}" == "--metadata-only" ]]; then
  metadata_only=true
elif [[ $# -ne 0 ]]; then
  echo "usage: $0 [--metadata-only]" >&2
  exit 2
fi

workspace_version="$(sed -n 's/^version = "\([^"]*\)"$/\1/p' pixi.toml)"
recipe_version="$(sed -n 's/^  version: "\([^"]*\)"$/\1/p' conda.recipe/recipe.yaml)"
workspace_mojo="$(sed -n 's/^mojo = "\([^"]*\)"$/\1/p' pixi.toml)"
workspace_moji="$(sed -n 's/^mojo-moji = "\([^"]*\)"$/\1/p' pixi.toml)"

[[ "$workspace_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "release version must be one semantic version; found '${workspace_version:-none}'" >&2
  exit 1
}
[[ "$workspace_version" != "0.0.0" ]] || {
  echo "release version must not be 0.0.0" >&2
  exit 1
}
[[ "$recipe_version" == "$workspace_version" ]] || {
  echo "recipe version '$recipe_version' does not match workspace '$workspace_version'" >&2
  exit 1
}
[[ "$workspace_mojo" == "==1.0.0" ]] || {
  echo "workspace must pin mojo ==1.0.0; found '${workspace_mojo:-none}'" >&2
  exit 1
}
[[ "$workspace_moji" == "==0.1.0" ]] || {
  echo "workspace must pin mojo-moji ==0.1.0; found '${workspace_moji:-none}'" >&2
  exit 1
}

for section in build host run; do
  for expected in "mojo-compiler ==1.0.0" "mojo-moji ==0.1.0"; do
    awk -v wanted="$section" -v expected="$expected" '
      $0 == "requirements:" { in_requirements = 1; next }
      in_requirements && /^[^ ]/ { in_requirements = 0 }
      in_requirements && /^  [[:alnum:]_-]+:$/ {
        current = $1
        sub(/:$/, "", current)
      }
      in_requirements && current == wanted && /^    - / {
        dependency = substr($0, 7)
        name = dependency
        sub(/ .*/, "", name)
        expected_name = expected
        sub(/ .*/, "", expected_name)
        if (name == expected_name) {
          total += 1
          if (dependency == expected) exact += 1
        }
      }
      END { exit !(total == 1 && exact == 1) }
    ' conda.recipe/recipe.yaml || {
      echo "recipe $section must contain exactly '$expected'" >&2
      exit 1
    }
  done
done

escaped_version="${workspace_version//./\\.}"
grep -Eq "^## \[${escaped_version}\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md || {
  echo "CHANGELOG.md needs a dated ${workspace_version} release heading" >&2
  exit 1
}

if $metadata_only; then
  echo "release metadata contract passed for ${workspace_version}"
  exit 0
fi

expected_tag="v${workspace_version}"
expected_ref="refs/tags/${expected_tag}"
[[ "${GITHUB_REF_NAME:-}" == "$expected_tag" ]] || {
  echo "expected tag ${expected_tag}; got ${GITHUB_REF_NAME:-unset}" >&2
  exit 1
}
[[ "${GITHUB_REF:-}" == "$expected_ref" ]] || {
  echo "expected ref ${expected_ref}; got ${GITHUB_REF:-unset}" >&2
  exit 1
}
[[ "$(git cat-file -t "$expected_ref" 2>/dev/null || true)" == "tag" ]] || {
  echo "release ref must be an annotated or signed tag object" >&2
  exit 1
}
tag_commit="$(git rev-parse "${expected_ref}^{commit}")"
[[ "$tag_commit" == "${GITHUB_SHA:-}" ]] || {
  echo "tag target $tag_commit does not match checkout ${GITHUB_SHA:-unset}" >&2
  exit 1
}
git merge-base --is-ancestor "$tag_commit" refs/remotes/origin/main || {
  echo "release commit is not contained in origin/main" >&2
  exit 1
}

echo "release contract passed for ${expected_tag} at ${tag_commit}"
