"""Tests for refresh_fixtures.py: copy out/<source>/lesson_bundle.json into fixtures/.

out/ is gitignored, so each test builds a temporary out/ tree and a temporary
fixtures/ tree, and never touches the committed fixtures.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

JP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(JP))

import pytest  # noqa: E402

import refresh_fixtures  # noqa: E402
from refresh_fixtures import RefreshRefused, SOURCES, refresh  # noqa: E402


def _bundle(source: str, state: str = "needs_review", n: int = 1) -> dict:
    return {"source_id": source, "state": state, "item_count": n, "items": []}


def _write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")


@pytest.fixture
def trees(tmp_path: Path) -> tuple[Path, Path]:
    out, fix = tmp_path / "out", tmp_path / "fixtures"
    for s in SOURCES:
        _write(out / s / "lesson_bundle.json", _bundle(s))
        _write(fix / s / "lesson_bundle.json", _bundle(s))
    return out, fix


def test_sources_match_the_committed_fixtures():
    on_disk = sorted(p.name for p in (JP / "fixtures").iterdir() if p.is_dir())
    assert sorted(SOURCES) == on_disk


def test_unchanged_bundles_report_nothing_changed(trees):
    out, fix = trees
    assert refresh(out, fix) == []


def test_copies_bundles_and_reports_which_changed(trees):
    out, fix = trees
    changed = SOURCES[1]
    _write(out / changed / "lesson_bundle.json", _bundle(changed, n=7))
    assert refresh(out, fix) == [changed]
    copied = (fix / changed / "lesson_bundle.json").read_bytes()
    assert copied == (out / changed / "lesson_bundle.json").read_bytes()
    assert json.loads(copied)["item_count"] == 7


def test_a_new_fixture_folder_counts_as_changed(tmp_path):
    out, fix = tmp_path / "out", tmp_path / "fixtures"
    for s in SOURCES:
        _write(out / s / "lesson_bundle.json", _bundle(s))
    assert refresh(out, fix) == list(SOURCES)
    for s in SOURCES:
        assert (fix / s / "lesson_bundle.json").exists()


def test_refuses_a_missing_bundle_and_copies_nothing(trees):
    out, fix = trees
    missing, other = SOURCES[0], SOURCES[2]
    (out / missing / "lesson_bundle.json").unlink()
    _write(out / other / "lesson_bundle.json", _bundle(other, n=9))
    before = (fix / other / "lesson_bundle.json").read_bytes()
    with pytest.raises(RefreshRefused, match=missing):
        refresh(out, fix)
    assert (fix / other / "lesson_bundle.json").read_bytes() == before
    assert (fix / missing / "lesson_bundle.json").exists()


def test_refuses_a_blocked_bundle_and_copies_nothing(trees):
    out, fix = trees
    blocked, other = SOURCES[3], SOURCES[4]
    _write(out / blocked / "lesson_bundle.json", _bundle(blocked, state="blocked", n=5))
    _write(out / other / "lesson_bundle.json", _bundle(other, n=9))
    before = {s: (fix / s / "lesson_bundle.json").read_bytes() for s in (blocked, other)}
    with pytest.raises(RefreshRefused, match=f"{blocked}.*blocked"):
        refresh(out, fix)
    for s, data in before.items():
        assert (fix / s / "lesson_bundle.json").read_bytes() == data


def test_main_prints_changed_and_exits_nonzero_on_refusal(trees, capsys):
    out, fix = trees
    changed = SOURCES[0]
    _write(out / changed / "lesson_bundle.json", _bundle(changed, n=3))
    assert refresh_fixtures.main(["--out", str(out), "--fixtures", str(fix)]) == 0
    printed = capsys.readouterr().out
    lines = [ln for ln in printed.splitlines() if ln.startswith("changed: ")]
    assert lines == [f"changed: {changed}"]

    _write(out / changed / "lesson_bundle.json", _bundle(changed, state="blocked"))
    assert refresh_fixtures.main(["--out", str(out), "--fixtures", str(fix)]) == 1
    assert "refused" in capsys.readouterr().err
