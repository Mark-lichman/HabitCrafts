"""Apply Mark's kanji rulings of 2026-10-26 to every `_ruby` twin, and log each change.
Run once: python review/apply_kanji_rulings.py [--dry-run]

1. The pronoun わたし is written 私{わたし}. The hiragana fields do not change.
2. Strict list: a twin uses only the kanji in kanji_n5_n4.json (plus its recorded
   operator additions). A word with any other kanji is written in hiragana, all of it,
   so 間{ま}に合{あ}います becomes まにあいます. WORDS names the multi-bracket words
   by hand; every other out-of-list bracket is one word and gives up its reading.

Each changed twin gets one finding in judge_ruby.json, marked applied. A twin that an
earlier finding already fixed gets a later finding whose `current` is that fix, so the
chain of findings at one place ends at the text the draft holds. Re-running is safe:
a twin that already obeys both rulings is left alone.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

JP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(JP))

from ruby import RUBY, kana_of  # noqa: E402

KANJI_FILE = JP / "kanji_n5_n4.json"
JUDGE = JP / "review" / "judge_ruby.json"

# A word written with more than one bracket, okurigana between: the whole word goes to
# hiragana when any of its kanji is outside the list.
WORDS = ("間{ま}に合{あ}",)

# わたし as the pronoun (also in わたしたち), not a form of わたす (to hand over):
# わたします, わたして, わたした.
WATASHI = re.compile(r"(?<![{ぁ-ゖ])わたし(?![ぁ-ゖ]*})(?!ま|て|た(?!ち))")


def allowed() -> set[str]:
    k = json.loads(KANJI_FILE.read_text(encoding="utf-8"))
    return set(k["N5"]) | set(k["N4"]) | set(k.get("operator_additions", {}))


def strict(text: str, ok: set[str]) -> str:
    for w in WORDS:
        if w in text and not set(re.sub(r"\{[^{}]*\}|[ぁ-ゖ]", "", w)) <= ok:
            text = text.replace(w, kana_of(w))
    return RUBY.sub(lambda m: m.group(0) if set(m.group(1)) <= ok else m.group(2), text)


def watashi(text: str) -> str:
    return WATASHI.sub("私{わたし}", text)


def twins(points: list[dict]):
    """Every twin as (point, where, field, index, owner object)."""
    for p in points:
        for kind, items in (("ex", p.get("examples", [])), ("p", p.get("practice", []))):
            for i, o in enumerate(items):
                for key in list(o):
                    if not key.endswith("_ruby"):
                        continue
                    field = key[:-5]
                    if isinstance(o[key], list):
                        for j in range(len(o[key])):
                            yield p, f"{kind}{i}", field, j, o
                    else:
                        yield p, f"{kind}{i}", field, None, o


def _get(o: dict, field: str, idx):
    v = o[f"{field}_ruby"]
    return v if idx is None else v[idx]


def _set(o: dict, field: str, idx, value: str) -> None:
    if idx is None:
        o[f"{field}_ruby"] = value
    else:
        o[f"{field}_ruby"][idx] = value


def main(dry: bool) -> None:
    ok = allowed()
    judge = json.loads(JUDGE.read_text(encoding="utf-8"))
    files = sorted((JP / "drafts").glob("L*.json"))
    drafts = {f: json.loads(f.read_text(encoding="utf-8")) for f in files}
    added = []
    for f, d in drafts.items():
        for p, where, field, idx, o in twins(d["points"]):
            cur = _get(o, field, idx)
            kana = o[field] if idx is None else o[field][idx]
            # A field that itself prints kanji (Mari's verbatim sign in mari.L33.3) keeps
            # its printed kanji: its twin is checked against the printed text.
            if re.search(r"[一-鿿々]", kana):
                continue
            step1 = watashi(cur)
            new = strict(step1, ok)
            if new == cur:
                continue
            assert kana_of(new) == kana_of(cur), (p["id"], cur, new)
            dropped = sorted({c for m in RUBY.finditer(cur) for c in m.group(1)} - ok)
            parts, rules = [], []
            if step1 != cur:
                rules.append("R8")
                parts.append("The pronoun わたし is written 私{わたし} (ruling of 2026-10-26).")
            if new != step1:
                rules.append("R1")
                parts.append(f"{''.join(dropped)} is outside kanji_n5_n4.json, so the word "
                             "is written in hiragana.")
            added.append({"point_id": p["id"], "where": where, "field": field, "index": idx,
                          "rule": "+".join(rules), "current": cur, "fix": new,
                          "detail": " ".join(parts), "by": "operator-ruling",
                          "status": "applied"})
            print(p["id"], where, field, idx, "|", cur, "->", new)
            _set(o, field, idx, new)
    print(f"{len(added)} twins changed")
    if dry:
        return
    for f, d in drafts.items():
        f.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    judge["findings"] += added
    JUDGE.write_text(json.dumps(judge, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main("--dry-run" in sys.argv)
