"""The strict kanji list: every kanji in every `_ruby` twin is in kanji_n5_n4.json (R1).

Mark ruled on 2026-10-26 that the twins use only the Tanos JLPT N5 and N4 kanji, and that
the pronoun わたし is written 私{わたし}. The list lives in pipeline/jp/kanji_n5_n4.json
with its source and each level's count, so these tests check the file against its own
recorded counts and every twin against the file. A word with any other kanji is written
in hiragana. The one field that prints kanji itself (Mari's verbatim sign in mari.L33.3)
keeps the kanji it prints, since its twin is checked against the printed text.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

JP = Path(__file__).resolve().parents[1]
KANJI_FILE = JP / "kanji_n5_n4.json"
KANJI = re.compile(r"[一-鿿々]")


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
