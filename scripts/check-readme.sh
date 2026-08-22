#!/usr/bin/env bash
set -euo pipefail

snippet_dir='.pixi/readme-snippets'
manifest="$snippet_dir/locations.tsv"
mkdir -p "$snippet_dir"
find "$snippet_dir" -maxdepth 1 -type f -delete

python3 - "$manifest" "$snippet_dir" <<'PY'
from pathlib import Path
import re
import sys

manifest = Path(sys.argv[1])
snippet_dir = Path(sys.argv[2])
lines = Path("README.md").read_text(encoding="utf-8").splitlines(keepends=True)
opening_pattern = re.compile(r"^[ \t]*(`{3,}|~{3,})[ \t]*mojo[ \t]*(?:\r?\n)?$")
locations = []
line_index = 0

while line_index < len(lines):
    opening = opening_pattern.fullmatch(lines[line_index])
    if opening is None:
        line_index += 1
        continue

    fence = opening.group(1)
    marker = re.escape(fence[0])
    closing_pattern = re.compile(
        rf"^[ \t]*{marker}{{{len(fence)},}}[ \t]*(?:\r?\n)?$"
    )
    readme_line = line_index + 1
    body = []
    line_index += 1
    while line_index < len(lines) and closing_pattern.fullmatch(
        lines[line_index]
    ) is None:
        body.append(lines[line_index])
        line_index += 1

    if line_index == len(lines):
        raise SystemExit(
            f"Unclosed Mojo fence starting at README.md line {readme_line}."
        )

    ordinal = len(locations) + 1
    snippet = snippet_dir / f"snippet_{ordinal:02d}.mojo"
    snippet.write_text("".join(body), encoding="utf-8")
    locations.append((snippet, readme_line))
    line_index += 1

if not locations:
    raise SystemExit("No fenced Mojo blocks found in README.md.")

manifest.write_text(
    "".join(f"{snippet}\t{line}\n" for snippet, line in locations),
    encoding="utf-8",
)
PY

snippet_count=0
while IFS=$'\t' read -r snippet readme_line; do
  output="${snippet%.mojo}"
  if ! mojo build --Werror -I . "$snippet" -o "$output"; then
    printf '%s\n' \
      "README snippet failed: $snippet (fence starts at README.md line $readme_line)." \
      >&2
    exit 1
  fi
  snippet_count=$((snippet_count + 1))
done < "$manifest"

printf '%s\n' "Compiled $snippet_count fenced Mojo blocks from README.md."
