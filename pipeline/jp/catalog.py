"""Cataloging: every extracted item gets a lesson TYPE and its USES, at extraction time.
Run after s01..s05: python catalog.py   (publish.py runs it too)

Why a stage of its own: search and sort in the app must not guess what a piece of
content is. The type comes from which extractor produced it (deterministic). The
uses come from uses.json (Use Tagging, an LM judgment kept as reviewable data).

Output: out/catalog/catalog.json, one entry per findable thing:
  {id, type, source, lesson?, title, summary, uses[], search, open: {screen, params}}
"""

from __future__ import annotations

import json
from pathlib import Path

from common import OUT_DIR, write

HERE = Path(__file__).parent
ASSETS = HERE.parents[1] / "assets" / "lessons"

TYPES = {
    "grammar_point": "Grammar",
    "particle": "Particle",
    "reference_table": "Numbers and counters",
    "verb_pair": "Verb pair",
    "conjugation": "Conjugation",
    "vocabulary": "Vocabulary",
}

FORM_LABELS = {
    "masu": "ます form", "te": "て form", "ta": "た form", "nai": "ない form",
    "potential": "potential form", "volitional": "volitional form",
    "conditional": "conditional (ば) form", "imperative": "imperative form",
    "prohibitive": "negative imperative (な)", "passive": "passive form",
    "causative": "causative form", "causative_passive": "causative passive form",
}


def _bundle(source: str) -> dict:
    return json.loads((OUT_DIR / source / "lesson_bundle.json").read_text(encoding="utf-8"))


def build() -> dict:
    uses = json.loads((HERE / "uses.json").read_text(encoding="utf-8"))
    tags = uses["points"]
    entries: list[dict] = []

    s04 = _bundle("s04_mari_checklist")
    for p in s04["items"]:
        entries.append({
            "id": p["id"], "type": "grammar_point", "source": "Mari", "lesson": p["lesson"],
            "title": p["pattern"], "summary": p["goal"], "uses": tags[p["id"]],
            "search": [p["example"]],
            "open": {"screen": "grammar", "lesson": p["lesson"], "point": p["id"]},
        })
    # A particle inherits the uses of the checklist points that teach it.
    for pa in s04["particles"]:
        key = pa["expression"].split("（")[0].split("〜")[0]
        inherited = sorted({u for p in s04["items"] if p["lesson"] in pa["taught_in"]
                            and key in p["pattern"] for u in tags[p["id"]]})
        entries.append({
            "id": pa["id"], "type": "particle", "source": "Mari",
            "lesson": pa["taught_in"][0] if pa["taught_in"] else None,
            "title": pa["expression"], "summary": pa["meaning"],
            # Particles no lesson teaches are tagged directly in uses.json.
            "uses": inherited or uses.get("particles", {}).get(pa["expression"], []),
            "search": [pa["example"]],
            "open": {"screen": "grammar", "lesson": pa["taught_in"][0]} if pa["taught_in"]
            else {"screen": "grammar", "query": key},
        })

    s01 = _bundle("s01_number")
    for table, title, summary in (
            ("counters", "Counters", "Counting things: つ, 個, 人, 本, 枚, 匹, 冊, 台..."),
            ("months", "Months", "Month names and numbers of months"),
            ("dates", "Dates", "Days of the month, 1日 to 31日"),
            ("durations", "Lengths of time", "Minutes, hours, days, weeks, months, years")):
        cols = sorted({i["counter"]["written"] + " " + i["counter"]["gloss"]
                       for i in s01["items"] if i["table"] == table})
        entries.append({
            "id": f"s01.{table}", "type": "reference_table", "source": "number.pdf",
            "title": title, "summary": summary, "uses": ["counting"], "search": cols,
            "open": {"screen": "reference", "table": table},
        })

    for src, who in (("s02_pairs_mari", "Mari"), ("s03_pairs_textbook", "Textbook 8課")):
        for it in _bundle(src)["items"]:
            tv = it.get("transitive_verb", it.get("transitive"))
            iv = it.get("intransitive_verb", it.get("intransitive"))
            if not tv or "ex." in it["id"]:
                continue
            entries.append({
                "id": it["id"], "type": "verb_pair", "source": who,
                "title": f"{iv} / {tv}", "summary": it.get("gloss", ""),
                "uses": ["transitivity"], "search": [iv, tv],
                "open": {"screen": "pairs"},
            })

    for form, label in FORM_LABELS.items():
        entries.append({
            "id": f"conj.{form}", "type": "conjugation", "source": "Mari (verb forms)",
            "title": label, "summary": "Conjugation drill", "uses": ["forms"],
            "search": [form], "open": {"screen": "conjugation", "form": form},
        })

    vocab = json.loads((ASSETS / "jp_lessons.json").read_text(encoding="utf-8"))
    for l in vocab["lessons"]:
        entries.append({
            "id": f"vocab.L{l['lesson']}", "type": "vocabulary", "source": l["source"],
            "lesson": l["lesson"], "title": f"第{l['lesson']}課 words",
            "summary": f"{len(l['items'])} words", "uses": [],
            "search": [w["gloss"] for w in l["items"]] + [w["kana"] for w in l["items"]],
            "open": {"screen": "vocabulary", "lesson": l["lesson"]},
        })

    known = {u["id"] for u in uses["uses"]}
    bad = [(e["id"], u) for e in entries for u in e["uses"] if u not in known]
    if bad:
        raise SystemExit(f"catalog: unknown uses {bad}")
    ids = [e["id"] for e in entries]
    dups = {i for i in ids if ids.count(i) > 1}
    if dups:
        raise SystemExit(f"catalog: duplicate ids {sorted(dups)}")

    catalog = {"types": [{"id": k, "label": v} for k, v in TYPES.items()],
               "uses": uses["uses"], "entries": entries}
    write("catalog", "catalog", catalog)
    return catalog


if __name__ == "__main__":
    c = build()
    from collections import Counter
    print(len(c["entries"]), "entries", dict(Counter(e["type"] for e in c["entries"])))
    untagged = [e["id"] for e in c["entries"] if not e["uses"] and e["type"] != "vocabulary"]
    print("no uses:", untagged)
