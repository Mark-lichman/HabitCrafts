"""The kanji-twin judge pass: every finding in review/judge_ruby.json is applied.

The judge read every `_ruby` twin in the drafts and wrote its findings to
`pipeline/jp/review/judge_ruby.json`. Each finding names a twin by point, item, field
and list index, and gives the fix. A finding is closed only when it is marked `applied`
and the draft holds its fix at that place, so a later draft edit that undoes a fix fails
here (PIN-5, PIN-11). A finding the judge got wrong moves to `dismissed` with a `why`,
and the draft must still hold its `current` text, so a finding cannot hide there unfixed.

A later finding may change a twin an earlier finding already fixed (the strict kanji
list of 2026-10-26 rewrote 都合{つごう}, for one). Findings at one place form a chain in
file order: each later finding's `current` is the earlier one's `fix`, and only the last
fix must be in the draft.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

JP = Path(__file__).resolve().parents[1]
JUDGE = JP / "review" / "judge_ruby.json"
FIELDS = {"jp", "prompt", "answer", "accepted", "options"}


def _judge() -> dict:
    assert JUDGE.exists(), f"missing {JUDGE.relative_to(JP)}: run the kanji-twin judge pass"
    return json.loads(JUDGE.read_text(encoding="utf-8"))


def _findings() -> list[dict]:
    return _judge()["findings"] if JUDGE.exists() else []


def _dismissed() -> list[dict]:
    return _judge().get("dismissed", []) if JUDGE.exists() else []


def _drafts() -> dict[str, dict]:
    points = {}
    for f in sorted((JP / "drafts").glob("L*.json")):
        for p in json.loads(f.read_text(encoding="utf-8"))["points"]:
            points[p["id"]] = p
    return points


def _place(f: dict) -> tuple:
    return f["point_id"], f["where"], f["field"], f["index"]


def _twin_at(points: dict, f: dict):
    p = points[f["point_id"]]
    where = f["where"]
    obj = p["examples"][int(where[2:])] if where.startswith("ex") else p["practice"][int(where[1:])]
    twin = obj[f"{f['field']}_ruby"]
    return twin if f["index"] is None else twin[f["index"]]


def test_judge_file_names_its_scope():
    j = _judge()
    assert j["scope"] == "kanji twins"
    assert isinstance(j["findings"], list)
    # The judge read the drafts as they were before its fixes, so it checked every twin.
    assert j["items_checked"] > 0


def test_every_finding_is_applied():
    open_ = [f for f in _judge()["findings"] if f.get("status") != "applied"]
    assert open_ == [], f"{len(open_)} judge findings are not applied"


@pytest.mark.parametrize("finding", _findings(),
                         ids=lambda f: f"{f['point_id']}-{f['where']}-{f['field']}-{f['index']}")
def test_each_applied_fix_is_in_the_draft(finding):
    assert finding["field"] in FIELDS
    assert finding["fix"] != finding["current"]
    later = [f for f in _findings()[_findings().index(finding) + 1:] if _place(f) == _place(finding)]
    if later:
        # Superseded: the next finding at this place starts from this fix.
        assert later[0]["current"] == finding["fix"], (
            f"{_place(finding)}: a later finding does not start from this fix")
    else:
        assert _twin_at(_drafts(), finding) == finding["fix"]


@pytest.mark.parametrize("entry", _dismissed(),
                         ids=lambda f: f"{f['point_id']}-{f['where']}-{f['field']}-{f['index']}")
def test_each_dismissed_entry_is_reasoned_and_unchanged(entry):
    # A dismissal needs a reason, and the draft keeps the text the judge saw: moving an
    # unfixed finding here would pass only with a written `why` and no silent edit.
    assert entry["status"] == "dismissed"
    assert entry.get("why"), f"dismissed entry {entry['point_id']} has no why"
    assert _twin_at(_drafts(), entry) == entry["current"]
