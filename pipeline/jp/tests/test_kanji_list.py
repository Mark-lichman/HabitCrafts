"""The strict kanji list: every kanji in every `_ruby` twin is in kanji_n5_n4.json (R1).

Mark ruled on 2026-10-26 that the twins use only the Tanos JLPT N5 and N4 kanji, and that
the pronoun わたし is written 私{わたし}. A later ruling that day added 分 as a recorded operator
addition, so わかる is written 分{わ}かる. The list lives in pipeline/jp/kanji_n5_n4.json
with its source and each level's count, and the Tanos pages it was read from are committed
under pipeline/jp/tanos/, so these tests check the file against its own recorded counts,
each level against the archived page's kanji table, and every twin against the file. A
word with any other kanji is written in hiragana. The one field that prints kanji itself (Mari's verbatim sign in mari.L33.3)
keeps the kanji it prints, since its twin is checked against the printed text.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

import pytest

JP = Path(__file__).resolve().parents[1]
KANJI_FILE = JP / "kanji_n5_n4.json"
KANJI = re.compile(r"[一-鿿々]")
# One row of the archived Tanos kanji table: the first cell links the kanji to its sentences.
SNAPSHOT_ROW = re.compile(r'<tr><td><a [^>]*kanjiid=\d+">([一-鿿]) </a></td>')


def _list() -> dict:
    return json.loads(KANJI_FILE.read_text(encoding="utf-8"))


def _allowed() -> set[str]:
    k = _list()
    return set(k["N5"]) | set(k["N4"]) | set(k.get("operator_additions", {}))


def _twins():
    """Every twin string, with its hiragana field and a readable place."""
    for f in sorted((JP / "drafts").glob("L*.json")):
        for p in json.loads(f.read_text(encoding="utf-8"))["points"]:
            for kind, items in (("ex", p.get("examples", [])), ("p", p.get("practice", []))):
                for i, o in enumerate(items):
                    for key, twin in o.items():
                        if not key.endswith("_ruby"):
                            continue
                        field = key[:-5]
                        if isinstance(twin, list):
                            for j, s in enumerate(twin):
                                yield f"{p['id']} {kind}{i} {field}[{j}]", s, o[field][j]
                        else:
                            yield f"{p['id']} {kind}{i} {field}", twin, o.get(field, "")


def test_the_list_names_its_source_and_counts():
    k = _list()
    assert k["source"] and k["source_urls"]["N5"] and k["source_urls"]["N4"]
    assert k["retrieved"]
    for level in ("N5", "N4"):
        kanji = k[level]
        assert all(KANJI.fullmatch(c) for c in kanji), f"{level} holds a non-kanji"
        assert len(set(kanji)) == len(kanji), f"{level} lists a kanji twice"
        assert len(kanji) == k["counts"][level], f"{level} count is not the recorded count"
    assert not set(k["N5"]) & set(k["N4"]), "a kanji is listed at both levels"


@pytest.mark.parametrize("level", ["N5", "N4"])
def test_each_level_is_the_archived_tanos_page_table(level):
    # The oracle is the Tanos page itself, archived byte for byte under pipeline/jp/tanos/:
    # its kanji table, one row per kanji, is the list. A kanji added to or dropped from
    # the file, or a changed snapshot, fails here.
    k = _list()
    snap = k["primary_snapshots"][level]
    assert snap["url"].startswith("https://web.archive.org/web/")
    assert k["source_urls"][level] in snap["url"], f"{level}: snapshot is not of the source URL"
    raw = (JP.parents[1] / snap["file"]).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == snap["sha256"], f"{snap['file']} changed"
    rows = SNAPSHOT_ROW.findall(raw.decode("utf-8"))
    assert rows, f"{snap['file']}: no kanji table rows"
    assert "".join(rows) == k[level], f"{level} is not the archived page's table"


def test_operator_additions_are_reasoned_and_not_already_listed():
    k = _list()
    for c, why in k.get("operator_additions", {}).items():
        assert KANJI.fullmatch(c) and why, c
        assert c not in k["N5"] + k["N4"], f"{c} is already in the Tanos lists"


def test_watashi_kanji_is_allowed():
    # Ruling (1): 私 stays, so it is either in the lists or a recorded addition.
    assert "私" in _allowed()


def test_every_twin_kanji_is_in_the_list():
    ok = _allowed()
    bad = []
    for where, twin, kana in _twins():
        # A field that prints kanji (mari.L33.3's sign) may keep exactly those kanji.
        outside = {c for c in KANJI.findall(twin) if c not in ok and c not in kana}
        if outside:
            bad.append(f"{where}: {''.join(sorted(outside))} in {twin!r}")
    assert bad == [], f"{len(bad)} twins use kanji outside kanji_n5_n4.json:\n" + "\n".join(bad)


@pytest.mark.parametrize("pronoun", ["わたしは", "わたしが", "わたしに", "わたしの", "わたしを",
                                     "わたしも", "わたし＿"],
                         ids=["wa", "ga", "ni", "no", "wo", "mo", "blank"])
def test_watashi_is_written_in_kanji(pronoun):
    # Ruling (1): the pronoun わたし is 私{わたし} in every twin; hiragana fields keep わたし.
    left = [w for w, twin, _ in _twins() if pronoun in twin]
    assert left == [], f"twins still write the pronoun in hiragana: {left}"


# A form of the verb わかる: わから, わかり, わかる, わかっ, or the conditional わかれば.
# 若{わか}い and わかれる (to part) do not match.
BARE_WAKARU = re.compile(r"わか(?:[らりるっ]|れば)")


def test_wakaru_kanji_is_an_operator_addition():
    # Ruling of 2026-10-26 (PIN-14): 分 is on neither Tanos page, so it is a recorded
    # operator addition with its reason.
    k = _list()
    assert "分" not in k["N5"] + k["N4"]
    assert k["operator_additions"].get("分") == (
        "operator ruling 2026-10-26: わかる is written 分かる")


def test_wakaru_is_written_with_its_kanji():
    # Ruling of 2026-10-26 (PIN-14): every form of わかる in a twin is 分{わ}かる, one
    # bracket with the okurigana outside; the hiragana fields keep わかる.
    left = [f"{w}: {twin!r}" for w, twin, _ in _twins() if BARE_WAKARU.search(twin)]
    assert left == [], f"{len(left)} twins write わかる in hiragana:\n" + "\n".join(left)
    assert any("分{わ}か" in twin for _, twin, _ in _twins()), "no twin writes 分{わ}かる"
