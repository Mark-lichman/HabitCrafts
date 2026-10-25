"""Kanji twins: the 漢字{かんじ} helpers in ruby.py and the twin checks in publish.py.

Covers the red-team's cases (PIN-5, PIN-9, PIN-11): one bracket per kanji word with
okurigana outside, `買い物{かいもの}` rejected, a `_ruby` twin beside every Japanese
draft field, why_wrong keyed by the hiragana option, and twins carried into the app
file.
"""

from __future__ import annotations

import copy
import json
import os
import shutil
import sys
from pathlib import Path

JP = Path(__file__).resolve().parents[1]
os.environ["JP_OUT_DIR"] = str(JP / "fixtures")
sys.path.insert(0, str(JP))
sys.path.insert(0, str(JP.parent))

import pytest  # noqa: E402

import publish  # noqa: E402
import ruby  # noqa: E402
import s03_pairs_textbook  # noqa: E402
import stages  # noqa: E402
from ruby import kana_of, plain_of, ruby_errors  # noqa: E402

FIX = JP / "fixtures"


# ───────────── reading-of and the bracket rule ─────────────

def test_okurigana_outside_the_brackets_passes():
    assert kana_of("買{か}い物{もの}") == "かいもの"
    assert ruby_errors("買{か}い物{もの}", "かいもの") == []


def test_bracket_over_okurigana_is_rejected():
    # The red-team probe: the old kana_of read this as かいものい物.
    assert kana_of("買い物{かいもの}") != "かいもの"
    errs = ruby_errors("買い物{かいもの}", "かいもの")
    assert errs and "no reading" in errs[0]


def test_reading_of_replaces_every_bracket():
    assert kana_of("電気{でんき}を つけて、本{ほん}を 読{よ}みます。") == "でんきを つけて、ほんを よみます。"
    assert plain_of("電気{でんき}を 読{よ}みます。") == "電気を 読みます。"


def test_repeat_mark_belongs_to_the_base():
    assert ruby_errors("人々{ひとびと}が 来{き}ました。", "ひとびとが きました。") == []


@pytest.mark.parametrize("bad, kana, why", [
    ("か{か}います", "かいます", "does not follow a kanji"),
    ("{か}います", "かいます", "does not follow a kanji"),
    ("買{}います", "かいます", "no reading"),
    ("買{買}います", "かいます", "holds a kanji"),
    ("買います", "かいます", "no reading"),
    ("買{う}います", "かいます", "is not the hiragana"),
    ("買{か}いました", "かいます", "is not the hiragana"),
])
def test_bad_twins_are_rejected(bad, kana, why):
    errs = ruby_errors(bad, kana)
    assert errs and why in errs[0], errs


def test_hiragana_word_repeats_its_hiragana_and_katakana_stays():
    assert ruby_errors("あした パンを 食{た}べる。", "あした パンを たべる。") == []
    assert ruby_errors("ありがとう", "ありがとう") == []


def test_s03_imports_the_helpers_from_ruby():
    assert s03_pairs_textbook.kana_of is ruby.kana_of
    assert s03_pairs_textbook.plain_of is ruby.plain_of
    assert not hasattr(s03_pairs_textbook, "RUBY")


def test_s03_transcription_reads_the_same_as_its_bundle():
    # The move must not change any textbook reading already extracted and committed.
    items = json.loads((FIX / "s03_pairs_textbook" / "lesson_bundle.json")
                       .read_text(encoding="utf-8"))["items"]
    by_id = {i["id"]: i for i in items}
    for n, (tr, intr) in enumerate(s03_pairs_textbook.TRANSCRIPTION["pairs"], start=1):
        it = by_id[f"s03_pairs_textbook.{n}"]
        assert kana_of(tr) == it["transitive_kana"]
        assert kana_of(intr) == it["intransitive_kana"]
    for side in ("transitive", "intransitive"):
        for n, ex in enumerate(s03_pairs_textbook.TRANSCRIPTION["examples"][side], start=1):
            assert kana_of(ex) == by_id[f"s03_pairs_textbook.ex.{side}.{n}"]["kana"]


def test_publish_claims_kanji_validating_for_its_twin_checks():
    # The twin checks run in publish.check_draft (check_twin, twin_errors), so the
    # registry names KanjiValidating on publish.py as well as on ruby.py (PIN-12).
    assert publish.ruby_errors is ruby.ruby_errors
    assert "KanjiValidating" in stages.STAGES["publish.py"]
    assert "KanjiValidating" in stages.STAGES["ruby.py"]


# ───────────── check_draft: a _ruby twin beside every Japanese field ─────────────

@pytest.fixture(scope="module")
def mari():
    # Mari's points as publish.run() sees them: with the reviewed corrections applied.
    review = json.loads((JP / "corrections.json").read_text(encoding="utf-8"))
    bundles = {s: publish.load(s) for s in review["approved_sources"]}
    publish.apply_corrections(bundles, review)
    return {p["id"]: p for p in bundles["s04_mari_checklist"]["items"]}


def _draft(n: int = 26) -> dict:
    return json.loads((JP / "drafts" / f"L{n}.json").read_text(encoding="utf-8"))


def drop_twins(d: dict) -> dict:
    """A copy of the draft with every `_ruby` key removed, whatever the committed state."""
    d = copy.deepcopy(d)
    for p in d["points"]:
        for o in [*p["examples"], *p["practice"]]:
            for k in [k for k in o if k.endswith("_ruby")]:
                del o[k]
    return d


def add_twins(d: dict) -> dict:
    """Give every Japanese field a twin that repeats its hiragana (always valid)."""
    d = copy.deepcopy(d)
    for p in d["points"]:
        for e in p["examples"]:
            e["jp_ruby"] = e["jp"]
        for q in p["practice"]:
            q["prompt_ruby"] = q["prompt"]
            q["answer_ruby"] = q["answer"]
            q["accepted_ruby"] = list(q.get("accepted", []))
            if "options" in q:
                q["options_ruby"] = list(q["options"])
    return d


def test_drafts_without_twins_pass_while_twins_are_optional(mari, monkeypatch):
    monkeypatch.setattr(publish, "REQUIRE_RUBY", False)
    # drop_twins pins the 'twin absent, flag false' branch whatever the committed drafts hold.
    assert publish.check_draft(drop_twins(_draft()), mari) == []


def test_every_committed_draft_passes_under_the_shipped_flag(mari):
    # Holds before Task 5 (twins optional, none present) and after it (twins required,
    # all present). It fails if REQUIRE_RUBY flips before every draft carries valid twins.
    for f in sorted((JP / "drafts").glob("L*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        assert publish.check_draft(d, mari) == [], f.name


def test_missing_twins_fail_when_required(mari, monkeypatch):
    monkeypatch.setattr(publish, "REQUIRE_RUBY", True)
    errs = publish.check_draft(drop_twins(_draft()), mari)
    for field in ("jp_ruby", "prompt_ruby", "answer_ruby", "accepted_ruby", "options_ruby"):
        assert any(f"missing {field}" in e for e in errs), field
    assert publish.check_draft(add_twins(_draft()), mari) == []


def test_kanji_twins_pass(mari, monkeypatch):
    monkeypatch.setattr(publish, "REQUIRE_RUBY", True)
    d = add_twins(_draft())
    ex = d["points"][0]["examples"][0]
    assert ex["jp"] == "あたまが いたいんです。"
    ex["jp_ruby"] = "頭{あたま}が 痛{いた}いんです。"
    assert publish.check_draft(d, mari) == []


def test_kanji_bearing_mari_example_takes_a_twin_on_its_printed_text(mari, monkeypatch):
    # mari.L33.3's first example is Mari's verbatim 「立入禁止」, so no reading can equal
    # the field. Its twin must read every kanji and print as the field.
    monkeypatch.setattr(publish, "REQUIRE_RUBY", True)
    d = add_twins(_draft(33))
    ex = next(p for p in d["points"] if p["id"] == "mari.L33.3")["examples"][0]
    assert ex["jp"] == "「立入禁止」は はいっては いけないという いみです。"
    ex["jp_ruby"] = "「立入禁止{たちいりきんし}」は はいっては いけないという いみです。"
    assert publish.check_draft(d, mari) == []
    ex["jp_ruby"] = "「禁止{きんし}」は はいっては いけないという いみです。"
    errs = publish.check_draft(d, mari)
    assert any("jp_ruby" in e and "printed text" in e for e in errs), errs
    ex["jp_ruby"] = ex["jp"]  # the kanji left unread
    errs = publish.check_draft(d, mari)
    assert any("jp_ruby" in e and "no reading" in e for e in errs), errs


@pytest.mark.parametrize("where, field, value", [
    ("example", "jp_ruby", "頭{あたま}が 痛いんです。"),
    ("example", "jp_ruby", "頭が{あたまが} いたいんです。"),
    ("fill", "prompt_ruby", "今日{きょう}は 仕事{しごと}が 休{やす}み。"),
    ("fill", "answer_ruby", "何{なに}んです"),
    ("choose", "options_ruby", ["静{しず}かだ", "静{しず}か"]),
    ("choose", "options_ruby", ["静{しず}かだ", "静{しず}か", "静{しず}かだ"]),
    ("fill", "accepted_ruby", ["なんです"]),
    ("choose", "options_ruby", "しずかな"),
])
def test_bad_twins_fail_the_draft(mari, monkeypatch, where, field, value):
    monkeypatch.setattr(publish, "REQUIRE_RUBY", False)  # a present twin is always checked
    d = add_twins(_draft())
    p = d["points"][0]
    if where == "example":
        p["examples"][0][field] = value
    elif where == "fill":
        p["practice"][0][field] = value
    else:
        p["practice"][2][field] = value
    errs = publish.check_draft(d, mari)
    assert any(field in e for e in errs), errs


@pytest.mark.parametrize("where, field, value, why", [
    # A null element: without the element guard ruby_errors raises TypeError.
    ("choose", "options_ruby", [None, "静{しず}か", "静{しず}かな"], "list of strings"),
    # A string as long as the options list: iterated, its characters are strings.
    ("choose", "options_ruby", "しずか", "list of strings"),
    # A string as long as the empty accepted list: iterated, it yields nothing.
    ("fill", "accepted_ruby", "", "list of strings"),
    ("fill", "accepted_ruby", [None], "list of strings"),
    # A stray options_ruby on a fill item, which has no options.
    ("fill", "options_ruby", ["何{なに}んです"], "list of strings"),
    ("fill", "prompt_ruby", ["何{なに}んです"], "must be a string"),
])
def test_malformed_twin_shapes_name_the_shape(mari, monkeypatch, where, field, value, why):
    # Each malformed shape is reported with its shape message, so publish.run() skips
    # the draft with a printed reason instead of crashing (module docstring).
    monkeypatch.setattr(publish, "REQUIRE_RUBY", False)
    d = add_twins(_draft())
    p = d["points"][0]
    assert p["practice"][0]["accepted"] == [] and len(p["practice"][2]["options"]) == 3
    (p["practice"][0] if where == "fill" else p["practice"][2])[field] = value
    errs = publish.check_draft(d, mari)
    assert any(field in e and why in e for e in errs), errs


def test_why_wrong_stays_keyed_by_the_hiragana_option(mari, monkeypatch):
    monkeypatch.setattr(publish, "REQUIRE_RUBY", True)
    d = add_twins(_draft())
    q = d["points"][0]["practice"][2]
    q["options_ruby"] = ["静{しず}かだ", "静{しず}か", "静{しず}かな"]
    assert publish.check_draft(d, mari) == []
    q["why_wrong"] = {"静{しず}かだ": "x", "しずか": "y"}
    errs = publish.check_draft(d, mari)
    assert any("why_wrong" in e for e in errs), errs


# ───────────── publishing carries the twins ─────────────

def test_publish_carries_twins_into_the_app_file(tmp_path, monkeypatch):
    drafts = tmp_path / "drafts"
    shutil.copytree(JP / "drafts", drafts)
    d = add_twins(_draft())
    d["points"][0]["examples"][0]["jp_ruby"] = "頭{あたま}が 痛{いた}いんです。"
    (drafts / "L26.json").write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(publish, "DRAFTS", drafts)
    out = tmp_path / "jp_grammar.json"
    doc, skipped = publish.run(out)
    assert skipped == []
    app = json.loads(out.read_text(encoding="utf-8"))
    p = next(p for g in app["grammar"] for p in g["points"] if p["id"] == "mari.L26.1")
    assert p["examples"][0]["jp_ruby"] == "頭{あたま}が 痛{いた}いんです。"
    q = p["practice"][2]
    assert q["options_ruby"] == q["options"] and q["answer_ruby"] == q["answer"]
    assert q["prompt_ruby"] == q["prompt"] and q["accepted_ruby"] == q["accepted"]
