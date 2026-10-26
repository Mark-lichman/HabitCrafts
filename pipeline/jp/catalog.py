"""Cataloging: every extracted item gets a lesson TYPE and its USES, at extraction time.
Run after s01..s05: python catalog.py   (publish.py runs it too)

Why a stage of its own: search and sort in the app must not guess what a piece of
content is. The type comes from which extractor produced it (deterministic). The
uses come from uses.json (Use Tagging, an LM judgment kept as reviewable data).

Output: out/catalog/catalog.json, one entry per findable thing:
  {id, type, source, lesson?, title, summary, uses[], search, from[], open: {screen, params}}

`from` lists the data files an entry came from. Each data file has a `source_file`
entry of its own: its role, its origin and counts computed from the file at build
time, so the counts live here and nowhere in prose (PIN-13). Opening a `source_file`
entry searches for its key, and the home search matches `from`, so the result is the
file and everything that came from it.
"""

from __future__ import annotations

import json
from pathlib import Path

from common import OUT_DIR, write

HERE = Path(__file__).parent
ASSETS = HERE.parents[1] / "assets" / "lessons"
DRAFTS = HERE / "drafts"

TYPES = {
    "grammar_point": "Grammar",
    "particle": "Particle",
    "reference_table": "Numbers and counters",
    "verb_pair": "Verb pair",
    "conjugation": "Conjugation",
    "vocabulary": "Vocabulary",
    "source_file": "Data file",
}

# The five extraction bundles, in stage order. Their committed copies are the fixtures.
SOURCE_BUNDLES = {
    "s01_number": ("counters, months, dates and lengths of time",
                   "number.pdf, a picture of a table with an OCR layer"),
    "s02_pairs_mari": ("transitive and intransitive verb pairs with examples",
                       "Mari's Canva table"),
    "s03_pairs_textbook": ("verb pairs and sentences, printed with kanji",
                           "textbook 8課, a scanned page"),
    "s04_mari_checklist": ("grammar points and particles, by lesson",
                           "Mari's N4 sheet, Checklist and particle tabs"),
    "s05_mari_verb_forms": ("worked conjugations, the gold set for conjugate.py",
                            "Mari's N4 sheet, Verb Forms Summary tab"),
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


def _from(e: dict, corrections: dict, drafted_points: set[str]) -> list[str]:
    """The keys of the data files an item entry came from."""
    t = e["type"]
    if t == "grammar_point":
        keys = ["s04_mari_checklist", "uses.json"]
        if e["id"] in drafted_points:
            keys.append("_points.json")
        if (DRAFTS / f"L{e['lesson']}.json").exists():
            keys.append(f"L{e['lesson']}.json")
    elif t == "particle":
        keys = ["s04_mari_checklist", "uses.json"]
    elif t == "reference_table":
        keys = ["s01_number"]
    elif t == "verb_pair":
        keys = [e["id"].split(".")[0]]
    elif t == "conjugation":
        # publish.drill() builds the verb list from the two pair bundles and the
        # vocabulary file. s05 is the gold set for conjugate.py's tests, not an input.
        keys = ["s02_pairs_mari", "s03_pairs_textbook", "jp_lessons.json"]
    else:  # vocabulary
        keys = ["jp_lessons.json"]
    # A reviewed correction names its item id; a reference table holds many items.
    prefix = f"s01_number.{e['id'].split('.', 1)[1]}." if t == "reference_table" else None
    if any(c["item"] == e["id"] or (prefix and c["item"].startswith(prefix))
           for c in corrections["corrections"]):
        keys.append("corrections.json")
    return keys


def _with_from(e: dict, corrections: dict, drafted_points: set[str]) -> dict:
    out = {k: v for k, v in e.items() if k != "open"}
    return {**out, "from": _from(e, corrections, drafted_points), "open": e["open"]}


def _source_entry(key: str, file: str, title: str, role: str, origin: str,
                  counts: dict[str, int], lesson: int | None = None) -> dict:
    """One data file. Counts are computed by the caller from the file, never typed."""
    said = ", ".join(f"{n} {k}" for k, n in counts.items())
    e = {"id": f"file.{key}", "type": "source_file", "source": origin}
    if lesson is not None:
        e["lesson"] = lesson
    # Counts first: the result card clips the summary at two lines on a phone, and
    # the live counts are the point of the entry. The key often equals the base
    # name, so the search terms are de-duplicated in order.
    return {**e, "title": title, "summary": f"{said}. {role[0].upper()}{role[1:]}.",
            "uses": [], "search": list(dict.fromkeys([file, file.rsplit("/", 1)[-1], key, origin])),
            "file": file, "role": role, "origin": origin, "counts": counts,
            "from": [key], "open": {"screen": "search", "query": key}}


def source_files(uses: dict, corrections: dict, points_file: list, vocab: dict) -> list[dict]:
    out = []
    for src, (role, origin) in SOURCE_BUNDLES.items():
        b = _bundle(src)
        counts = {"items": len(b["items"])}
        if src == "s04_mari_checklist":
            counts |= {"particles": len(b["particles"]), "lessons": len(b["lessons"])}
        out.append(_source_entry(src, f"pipeline/jp/fixtures/{src}/lesson_bundle.json",
                                 f"{src}/lesson_bundle.json", role, origin, counts))
    out.append(_source_entry(
        "_points.json", "pipeline/jp/drafts/_points.json", "_points.json",
        "the grammar points handed to LM Drafting", "Mari's N4 sheet, Checklist tab",
        {"points": len(points_file)}))
    for f in sorted(DRAFTS.glob("L*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        pts = d["points"]
        out.append(_source_entry(
            f.name, f"pipeline/jp/drafts/{f.name}", f.name,
            "a short lesson per grammar point: explanation, second example, practice",
            "LM Drafting, checked by publish.check_draft() and a judge pass",
            {"points": len(pts),
             "examples": sum(len(p.get("examples", [])) for p in pts),
             "practice items": sum(len(p.get("practice", [])) for p in pts)},
            lesson=d["lesson"]))
    out.append(_source_entry(
        "uses.json", "pipeline/jp/uses.json", "uses.json",
        "the uses each grammar point serves", "LM Use Tagging, kept as reviewable data",
        {"uses": len(uses["uses"]), "points tagged": len(uses["points"]),
         "particles tagged": len(uses.get("particles", {}))}))
    kanji = json.loads((HERE / "kanji_n5_n4.json").read_text(encoding="utf-8"))
    out.append(_source_entry(
        "kanji_n5_n4.json", "pipeline/jp/kanji_n5_n4.json", "kanji_n5_n4.json",
        "the only kanji a kanji version may use", kanji["source"],
        {"N5 kanji": len(kanji["N5"]), "N4 kanji": len(kanji["N4"]),
         "operator additions": len(kanji.get("operator_additions", {}))}))
    out.append(_source_entry(
        "corrections.json", "pipeline/jp/corrections.json", "corrections.json",
        "approved sources and reviewed corrections", "Mark's review",
        {"approved sources": len(corrections["approved_sources"]),
         "corrections": len(corrections["corrections"])}))
    out.append(_source_entry(
        "jp_lessons.json", "assets/lessons/jp_lessons.json", "jp_lessons.json",
        "vocabulary, lesson by lesson", "Langoal word-list PDFs",
        {"lessons": len(vocab["lessons"]),
         "words": sum(len(l["items"]) for l in vocab["lessons"]),
         "missing lessons": len(vocab.get("missingLessons", []))}))
    return out


def build(save: bool = False) -> dict:
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

    corrections = json.loads((HERE / "corrections.json").read_text(encoding="utf-8"))
    points_file = json.loads((DRAFTS / "_points.json").read_text(encoding="utf-8"))
    entries = [_with_from(e, corrections, {p["id"] for p in points_file}) for e in entries]
    entries += source_files(uses, corrections, points_file, vocab)

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
    if save:  # only the stage run saves; publish and tests just read it
        write("catalog", "catalog", catalog)
    return catalog


if __name__ == "__main__":
    c = build(save=True)
    from collections import Counter
    print(len(c["entries"]), "entries", dict(Counter(e["type"] for e in c["entries"])))
    untagged = [e["id"] for e in c["entries"] if not e["uses"] and e["type"] not in ("vocabulary", "source_file")]
    print("no uses:", untagged)
