#!/usr/bin/env python3
"""Generate safe Unicode terminal-width lookup code from Unicode 17 data."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import urllib.request
from collections.abc import Iterable
from pathlib import Path


UNICODE_VERSION = "17.0.0"
SOURCES = {
    "EastAsianWidth.txt": (
        f"https://www.unicode.org/Public/{UNICODE_VERSION}/ucd/EastAsianWidth.txt",
        "ea7ce50f3444a050333448dffef1cadd9325af55cbb764b4a2280faf52170a33",
    ),
    "DerivedGeneralCategory.txt": (
        "https://www.unicode.org/Public/"
        f"{UNICODE_VERSION}/ucd/extracted/DerivedGeneralCategory.txt",
        "d62e5bab70ca74f099343f71224fa051cb1fdd61a1ab45c0488c44cfc0b6102e",
    ),
    "emoji-data.txt": (
        f"https://www.unicode.org/Public/{UNICODE_VERSION}/ucd/emoji/emoji-data.txt",
        "2cb2bb9455cda83e8481541ecf5b6dfda66a3bb89efa3fa7c5297eccf607b72b",
    ),
    "PropList.txt": (
        f"https://www.unicode.org/Public/{UNICODE_VERSION}/ucd/PropList.txt",
        "130dcddcaadaf071008bdfce1e7743e04fdfbc910886f017d9f9ac931d8c64dd",
    ),
}
OUTPUT = Path(__file__).resolve().parent.parent / "mojotui/text/_unicode_width_data.mojo"
PROPERTY_RE = re.compile(
    r"^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*([A-Za-z_]+)"
)

Interval = tuple[int, int]


def fetch(name: str) -> str:
    url, expected_digest = SOURCES[name]
    with urllib.request.urlopen(url, timeout=30) as response:
        payload = response.read()
    actual_digest = hashlib.sha256(payload).hexdigest()
    if actual_digest != expected_digest:
        raise RuntimeError(
            f"checksum mismatch for {name}: expected {expected_digest}, "
            f"received {actual_digest}"
        )
    return payload.decode("utf-8")


def properties(text: str) -> dict[str, list[Interval]]:
    result: dict[str, list[Interval]] = {}
    for line in text.splitlines():
        match = PROPERTY_RE.match(line)
        if match is None:
            continue
        start = int(match.group(1), 16)
        end = int(match.group(2) or match.group(1), 16)
        result.setdefault(match.group(3), []).append((start, end))
    return result


def merge(intervals: Iterable[Interval]) -> list[Interval]:
    merged: list[Interval] = []
    for start, end in sorted(intervals):
        if merged and start <= merged[-1][1] + 1:
            previous_start, previous_end = merged[-1]
            merged[-1] = (previous_start, max(previous_end, end))
        else:
            merged.append((start, end))
    return merged


def emit_branch(intervals: list[Interval], indent: str) -> list[str]:
    if not intervals:
        return [indent + "return False"]

    middle = len(intervals) // 2
    start, end = intervals[middle]
    lines = [indent + f"if value < 0x{start:X}:"]
    lines.extend(emit_branch(intervals[:middle], indent + "    "))
    lines.append(indent + f"if value > 0x{end:X}:")
    lines.extend(emit_branch(intervals[middle + 1 :], indent + "    "))
    lines.append(indent + "return True")
    return lines


def emit_lookup(name: str, intervals: list[Interval]) -> list[str]:
    lines = [f"def {name}(value: Int) -> Bool:", "    if value < 0:", "        return False"]
    lines.extend(emit_branch(intervals, "    "))
    return lines


def generate() -> str:
    east_asian = properties(fetch("EastAsianWidth.txt"))
    categories = properties(fetch("DerivedGeneralCategory.txt"))
    emoji = properties(fetch("emoji-data.txt"))
    properties_list = properties(fetch("PropList.txt"))

    zero_width = merge(
        categories.get("Mn", [])
        + categories.get("Me", [])
        + categories.get("Cf", [])
        + [(0x1160, 0x11FF)]
    )
    wide = merge(
        east_asian.get("W", [])
        + east_asian.get("F", [])
        + emoji.get("Emoji_Presentation", [])
    )
    ambiguous = merge(east_asian.get("A", []))
    emoji_codepoints = merge(emoji.get("Emoji", []))
    whitespace = merge(properties_list.get("White_Space", []))

    lines = [
        '"""Generated Unicode terminal-width lookup tables. Do not edit."""',
        "",
        f'# Unicode version: {UNICODE_VERSION}',
        "# Sources and SHA-256 digests:",
    ]
    for name, (url, digest) in SOURCES.items():
        lines.append(f"# - {url}")
        lines.append(f"#   {digest}  {name}")
    lines.extend(
        [
            "",
            "def unicode_data_version() -> String:",
            f'    return "{UNICODE_VERSION}"',
            "",
        ]
    )

    for name, intervals in (
        ("is_zero_width", zero_width),
        ("is_wide", wide),
        ("is_ambiguous", ambiguous),
        ("is_emoji", emoji_codepoints),
        ("is_whitespace", whitespace),
    ):
        lines.extend(emit_lookup(name, intervals))
        lines.append("")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check", action="store_true", help="fail if the generated file is stale"
    )
    args = parser.parse_args()

    generated = generate()
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != generated:
            print(f"generated Unicode data is stale: {OUTPUT}", file=sys.stderr)
            return 1
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generated)
    print(f"generated {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
