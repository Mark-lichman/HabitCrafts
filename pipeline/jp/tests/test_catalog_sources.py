"""Every data file has a catalog entry with live counts, and the lesson doc restates none (PIN-13).

The catalog (pipeline/jp/catalog.py) emits one `source_file` entry per data file: the
five extraction bundles, each draft, uses.json, corrections.json and jp_lessons.json.
Each entry carries its role, its origin and counts computed from the file. These tests
recompute the counts here, straight from the files, so a hand-typed count in the
catalog fails. They also scan docs/japanese-lessons.md for any of those counts: a
number copied into prose goes stale without failing anything else.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

JP = Path(__file__).resolve().parents[1]
os.environ["JP_OUT_DIR"] = str(JP / "fixtures")
sys.path.insert(0, str(JP))

import pytest  # noqa: E402

from catalog import SOURCE_BUNDLES, build as build_catalog  # noqa: E402

REPO = JP.parents[1]
ASSETS = REPO / "assets" / "lessons"
DOC = REPO / "docs" / "japanese-lessons.md"


def _read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def expected_counts() -> dict[str, dict[str, int]]:
    """Counts per data file, keyed by the catalog's `file` path, computed independently."""
    out: dict[str, dict[str, int]] = {}
    for src in SOURCE_BUNDLES:
        b = _read(JP / "fixtures" / src / "lesson_bundle.json")
        c = {"items": len(b["items"])}
        if src == "s04_mari_checklist":
            c |= {"particles": len(b["particles"]), "lessons": len(b["lessons"])}
        out[f"pipeline/jp/fixtures/{src}/lesson_bundle.json"] = c
    for f in sorted((JP / "drafts").glob("*.json")):
        d = _read(f)
        if isinstance(d, list):
            c = {"points": len(d)}
        else:
            c = {"points": len(d["points"]),
                 "examples": sum(len(p.get("examples", [])) for p in d["points"]),
                 "practice items": sum(len(p.get("practice", [])) for p in d["points"])}
        out[f"pipeline/jp/drafts/{f.name}"] = c
    u = _read(JP / "uses.json")
    out["pipeline/jp/uses.json"] = {"uses": len(u["uses"]), "points tagged": len(u["points"]),
                                    "particles tagged": len(u.get("particles", {}))}
    r = _read(JP / "corrections.json")
    out["pipeline/jp/corrections.json"] = {"approved sources": len(r["approved_sources"]),
                                           "corrections": len(r["corrections"])}
    v = _read(ASSETS / "jp_lessons.json")
    out["assets/lessons/jp_lessons.json"] = {
        "lessons": len(v["lessons"]), "words": sum(len(l["items"]) for l in v["lessons"]),
        "missing lessons": len(v.get("missingLessons", []))}
    return out


@pytest.fixture(scope="module")
def sources() -> list[dict]:
    return [e for e in build_catalog()["entries"] if e["type"] == "source_file"]


def test_every_data_file_has_one_entry(sources):
    files = [e["file"] for e in sources]
    assert len(files) == len(set(files)), "two entries name the same file"
    assert sorted(files) == sorted(expected_counts())


def test_every_entry_carries_live_counts(sources):
    want = expected_counts()
    for e in sources:
        assert e["counts"] == want[e["file"]], e["file"]
        for k, n in e["counts"].items():
            assert f"{n} {k}" in e["summary"], f"{e['file']}: summary omits {n} {k}"


def test_every_entry_has_role_origin_and_a_search_target(sources):
    for e in sources:
        assert e["role"] and e["origin"] and e["source"] == e["origin"], e["file"]
        name = e["file"].rsplit("/", 1)[-1]
        # Findable by name: the home search matches the title and the search terms.
        assert any(name in s for s in [e["title"], *e["search"]]), e["file"]
        assert e["open"]["screen"] == "search" and e["open"]["query"], e["file"]


def test_open_query_finds_the_file_and_what_came_from_it(sources):
    # The home screen applies the open query to its search box, which matches an
    # entry's `from` list. The query must at least find the file's own entry.
    entries = build_catalog()["entries"]
    for e in sources:
        q = e["open"]["query"]
        hits = [x for x in entries if q in x.get("from", [])]
        assert e in hits, e["file"]
    by_file = {e["file"]: e for e in sources}
    checklist = by_file["pipeline/jp/fixtures/s04_mari_checklist/lesson_bundle.json"]
    q = checklist["open"]["query"]
    grammar = [x for x in entries if x["type"] == "grammar_point" and q in x.get("from", [])]
    assert len(grammar) == checklist["counts"]["items"]


def test_published_app_file_carries_the_source_entries(sources):
    committed = _read(ASSETS / "jp_grammar.json")
    shipped = [e for e in committed["catalog"] if e["type"] == "source_file"]
    assert shipped == sources, "run: python pipeline/jp/publish.py, then commit the asset"
    assert any(t["id"] == "source_file" for t in committed["types"])


# ───────────── the lesson doc (PIN-13) ─────────────

def _prose_numbers(text: str) -> list[tuple[int, str, str]]:
    """Integers in the doc's prose, each with the words after it and its line.

    Code fences and inline code are skipped: a path or a date is not a count. A number
    glued to a word character (L26, s04, 8課, 3.3) is part of a name, not a count.
    """
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    found = []
    for line in text.splitlines():
        prose = re.sub(r"`[^`]*`", "", line)
        for m in re.finditer(r"(?<![\w.{/])\d+(?![\w.}/])", prose):
            found.append((int(m.group()), prose[m.end():].lower(), line.strip()))
    return found


COUNT_NOUNS = ("item", "particle", "lesson", "point", "example", "practice", "use",
               "source", "correction", "word", "missing", "file", "draft", "verb", "pair")


def _restates(n: int, after: str, counts: set[int]) -> bool:
    """A count is restated when the number is one, and it is either large enough not to be
    an ordinal in prose ("Task 5", "sources 1 and 2") or it is followed by a counted noun."""
    if n not in counts:
        return False
    nxt = " ".join(re.findall(r"[a-z]+", after)[:2])
    return n >= 10 or any(nxt.startswith(w) or f" {w}" in nxt for w in COUNT_NOUNS)


def test_lesson_doc_points_to_the_catalog():
    doc = DOC.read_text(encoding="utf-8")
    assert "pipeline/jp/catalog.py" in doc and "`catalog`" in doc
    assert "not yet emitted" not in doc, "delete the Task 10 callout: the entries are emitted"
    # The data-file table names every cataloged file.
    for f in expected_counts():
        name = f.rsplit("/", 1)[-1]
        if f.startswith("pipeline/jp/drafts/L"):
            name = "L<n>.json"
        elif f.endswith("lesson_bundle.json"):
            name = f.split("/")[-2]
        assert name in doc, f"the data-file table does not name {f}"


def test_lesson_doc_restates_no_count():
    counts = {n for c in expected_counts().values() for n in c.values()}
    restated = [(n, line) for n, after, line in _prose_numbers(DOC.read_text(encoding="utf-8"))
                if _restates(n, after, counts)]
    assert not restated, f"docs/japanese-lessons.md restates catalog counts: {restated}"


def test_the_doc_scan_catches_a_restated_count():
    # The scan above must be able to fail: a copied count in prose is caught, whether
    # it is large or small and followed by what it counts.
    counts = {n for c in expected_counts().values() for n in c.values()}
    words = expected_counts()["assets/lessons/jp_lessons.json"]["words"]
    small = min(n for n in counts if n > 1)
    for text in (f"The vocabulary has {words} words.", f"It holds {small} items."):
        assert any(_restates(n, a, counts) for n, a, _ in _prose_numbers(text)), text
    assert not any(_restates(n, a, counts) for n, a, _ in _prose_numbers(
        "Run sources 1 and 2 before 3 and 4. See `docs/plans/2026-10-24-x.md`."))
