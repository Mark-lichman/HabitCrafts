"""Pipeline evals that run in CI, on committed fixtures.

The extractors need the source PDFs and Mari's exported sheet, which live outside the
repo, so CI cannot re-run them. Their outputs are committed as fixtures
(pipeline/jp/fixtures/<source>/lesson_bundle.json), and everything downstream of
extraction is tested here: the conjugation engine against the tutor's gold, the draft
validator, the catalog, publishing with corrections, and drift between the committed
app file and a fresh publish.

Refresh fixtures after re-running an extractor:
    cp out/<source>/lesson_bundle.json fixtures/<source>/
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

JP = Path(__file__).resolve().parents[1]
os.environ["JP_OUT_DIR"] = str(JP / "fixtures")
sys.path.insert(0, str(JP))
sys.path.insert(0, str(JP.parent))

import pytest  # noqa: E402

from catalog import TYPES, build as build_catalog  # noqa: E402
from conjugate import MARI_DRILLS, conjugate, group  # noqa: E402

FIX = JP / "fixtures"
ASSETS = JP.parents[1] / "assets" / "lessons"


def bundle(source: str) -> dict:
    return json.loads((FIX / source / "lesson_bundle.json").read_text(encoding="utf-8"))


# ───────────── conjugation engine vs the tutor ─────────────

PAST_TO_DIC = {"いった": "いく", "かった": "かう", "あった": "ある", "おきた": "おきる",
               "した": "する", "きた": "くる"}


def mari_rows() -> list[dict]:
    return [i for i in bundle("s05_mari_verb_forms")["items"]
            if not i["section"].startswith("long_short")]


@pytest.mark.parametrize("row", mari_rows(), ids=lambda r: f"{r['dictionary']}-{r['section']}")
def test_engine_matches_every_mari_conjugation(row):
    assert conjugate(row["dictionary"], row["group"])[row["section"]] == row["result"]


def long_short_rows() -> list[dict]:
    return [i for i in bundle("s05_mari_verb_forms")["items"]
            if i["section"].startswith("long_short") and isinstance(i["group"], int)]


@pytest.mark.parametrize("row", long_short_rows(), ids=lambda r: f"{r['short_affirmative']}-{r['section']}")
def test_engine_matches_mari_long_and_short_forms(row):
    past = row["section"].endswith("past")
    dic = PAST_TO_DIC[row["short_affirmative"]] if past else row["short_affirmative"]
    c = conjugate(dic, row["group"])
    stem = c["masu"][:-2]
    assert row["long_affirmative"] == stem + ("ました" if past else "ます")
    assert row["long_negative"] == stem + ("ませんでした" if past else "ません")
    assert row["short_affirmative"] == (c["ta"] if past else dic)
    assert row["short_negative"] == c["nai"][:-1] + ("かった" if past else "い")


def test_gold_set_is_complete():
    # 150 single-form cells + 12 verb rows of 4 long/short forms = 198 conjugations.
    # A smaller number means a fixture lost rows, and the engine tests above would
    # pass on less evidence.
    assert len(mari_rows()) == 150
    assert len(long_short_rows()) == 12


@pytest.mark.parametrize("pattern", list(MARI_DRILLS))
def test_engine_reproduces_mari_checklist_examples(pattern):
    point = next(p for p in bundle("s04_mari_checklist")["items"] if p["pattern"] == pattern)
    given = [s.strip().rstrip("！") for s in point["example"].split("／")]
    assert given == [conjugate(v, group(v).pop())[f] for v, f in MARI_DRILLS[pattern]]


def test_group_agrees_with_lesson_30_hand_labels():
    lessons = json.loads((ASSETS / "jp_lessons.json").read_text(encoding="utf-8"))["lessons"]
    verbs = [i for l in lessons for i in l["items"] if "verbGroup" in i]
    assert verbs
    for v in verbs:
        assert v["verbGroup"] in group(v["dictionary"]), v["dictionary"]
        assert conjugate(v["dictionary"], v["verbGroup"])["masu"] == v["kana"]
        assert conjugate(v["dictionary"], v["verbGroup"])["te"] == v["teForm"]


def test_ambiguous_verbs_never_resolve_silently():
    assert group("かえる") == {1, 2}
    assert group("はいる") == {1}
    assert group("でる") == {2}


# ───────────── catalog ─────────────

def test_catalog_types_and_uses():
    cat = build_catalog()
    known_uses = {u["id"] for u in cat["uses"]}
    by_type = {}
    for e in cat["entries"]:
        assert e["type"] in TYPES
        assert set(e["uses"]) <= known_uses, e["id"]
        if e["type"] != "vocabulary":
            assert e["uses"], f"{e['id']} has no uses, so sort by use never finds it"
        by_type[e["type"]] = by_type.get(e["type"], 0) + 1
    assert by_type == {"grammar_point": 89, "particle": 15, "reference_table": 4,
                       "verb_pair": 35, "conjugation": 12, "vocabulary": 25}


# ───────────── publishing ─────────────

@pytest.fixture(scope="module")
def published(tmp_path_factory):
    import publish
    out = tmp_path_factory.mktemp("pub") / "jp_grammar.json"
    doc, skipped = publish.run(out)
    return doc, skipped, out


def test_no_draft_is_skipped(published):
    _, skipped, _ = published
    assert skipped == []


def test_every_lesson_is_drafted_with_four_items(published):
    doc, _, _ = published
    assert [g["lesson"] for g in doc["grammar"]] == list(range(26, 51))
    for g in doc["grammar"]:
        assert g["status"] == "draft"
        for p in g["points"]:
            assert len(p["practice"]) >= 4, p["id"]


def test_reviewed_corrections_are_applied(published):
    doc, _, _ = published
    ex = next(p for g in doc["grammar"] for p in g["points"] if p["id"] == "mari.L42.3")
    assert "みっかも" in ex["example"] and "3にち" not in ex["example"]
    months = next(t for t in doc["reference"] if t["id"] == "months")
    cell = next(c for c in months["cells"] if c["row"] == "11" and c["col"] == "〜か月")
    assert cell["mark"] == "sound_change"
    assert any(v["dictionary"] == "かえる" and v["group"] == 2
               for v in doc["conjugation"]["verbs"])


def test_committed_app_file_matches_a_fresh_publish(published):
    # The app ships assets/lessons/jp_grammar.json. If a draft, a correction or the
    # catalog changed without re-running publish.py, the phone gets stale content.
    _, _, out = published
    fresh = json.loads(out.read_text(encoding="utf-8"))
    committed = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    assert committed == fresh, "run: python pipeline/jp/publish.py, then commit the asset"


# ───────────── OPM schema ─────────────

def test_opm_stage_graph_composes():
    import extraction_schemas
    extraction_schemas._check()
