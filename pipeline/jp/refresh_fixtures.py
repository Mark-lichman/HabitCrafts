"""Refresh the committed fixtures from a fresh extractor run.

Copies each out/<source>/lesson_bundle.json into fixtures/<source>/ and reports
which sources changed. It refuses, and copies nothing, if any source's out/ bundle
is missing or its state is "blocked": a blocked bundle failed validation and must
not become the fixture CI tests against.

Run from the repo root after re-running the extractors:
    pipeline/.venv/Scripts/python pipeline/jp/refresh_fixtures.py
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

JP = Path(__file__).resolve().parent
BUNDLE = "lesson_bundle.json"

# One entry per extractor source, as named in out/ and fixtures/.
SOURCES = (
    "s01_number",
    "s02_pairs_mari",
    "s03_pairs_textbook",
    "s04_mari_checklist",
    "s05_mari_verb_forms",
)


class RefreshRefused(Exception):
    """An out/ bundle is missing or blocked, so no fixture was touched."""


def refresh(out_dir: Path, fixtures_dir: Path, sources=SOURCES) -> list[str]:
    """Copy every source's bundle into fixtures_dir. Return the sources that changed.

    All bundles are checked before any copy, so a refusal leaves fixtures as they were.
    """
    problems: list[str] = []
    fresh: dict[str, bytes] = {}
    for source in sources:
        path = Path(out_dir) / source / BUNDLE
        if not path.is_file():
            problems.append(f"{source}: {path} is missing")
            continue
        data = path.read_bytes()
        try:
            state = json.loads(data.decode("utf-8")).get("state")
        except (UnicodeDecodeError, json.JSONDecodeError, AttributeError) as e:
            problems.append(f"{source}: {path} is not a bundle ({e})")
            continue
        if state == "blocked":
            problems.append(f"{source}: state is blocked (fix its validation failures first)")
            continue
        fresh[source] = data
    if problems:
        raise RefreshRefused("; ".join(problems))

    changed: list[str] = []
    for source, data in fresh.items():
        dest = Path(fixtures_dir) / source / BUNDLE
        if dest.is_file() and dest.read_bytes() == data:
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        changed.append(source)
    return changed


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, default=JP / "out", help="extractor output tree")
    ap.add_argument("--fixtures", type=Path, default=JP / "fixtures", help="fixture tree")
    args = ap.parse_args(argv)
    try:
        changed = refresh(args.out, args.fixtures)
    except RefreshRefused as e:
        print(f"refused: {e}", file=sys.stderr)
        return 1
    for source in changed:
        print(f"changed: {source}")
    unchanged = [s for s in SOURCES if s not in changed]
    if unchanged:
        print(f"unchanged: {', '.join(unchanged)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
