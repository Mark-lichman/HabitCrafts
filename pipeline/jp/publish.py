"""Publishing: approved bundles + reviewed corrections -> assets/lessons/jp_grammar.json.
Run after s01..s05: python publish.py

Only sources listed in corrections.json "approved_sources" are published. Each
correction is applied by item id and field, and the publish FAILS if a correction's
"from" no longer matches: a correction written against an older extraction must not
silently land on the wrong cell.

Grammar mini-lessons come from drafts/L<n>.json. Those are LM drafts (OPM Drafting and
Grammar Item Generating), so they ship with status "draft" until a person reviews them,
and the app says so. A draft that fails validation is left out, with the reason printed.

Each Japanese draft field carries a `_ruby` twin, its kanji version written
`漢字{かんじ}` (see ruby.py). A present twin is always checked, and passes through to the
app file. A missing twin fails validation while REQUIRE_RUBY is true, as it ships.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from common import OUT_DIR, is_kana
from catalog import build as build_catalog
from conjugate import conjugate, group
from ruby import kana_of, plain_of, ruby_errors

HERE = Path(__file__).parent
ASSET = HERE.parents[1] / "assets" / "lessons" / "jp_grammar.json"
DRAFTS = HERE / "drafts"
# Every draft carries its twins, so a missing one fails the draft (PIN-9). The twins
# passed a judge pass whose findings are in review/judge_ruby.json.
REQUIRE_RUBY = True
FORMS = ["masu", "te", "ta", "nai", "potential", "volitional", "conditional",
         "imperative", "prohibitive", "passive", "causative", "causative_passive"]
JP_PUNCT = re.compile(r"[。、！？「」／・＿\s0-9０-９ー〜～（）()]")


def load(source: str) -> dict:
    return json.loads((OUT_DIR / source / "lesson_bundle.json").read_text(encoding="utf-8"))


def apply_corrections(bundles: dict, review: dict) -> list[dict]:
    applied = []
    for c in review["corrections"]:
        items = bundles[c["source"]]["items"]
        it = next((i for i in items if i["id"] == c["item"]), None)
        if it is None:
            raise SystemExit(f"correction target missing: {c['item']}")
        cur = it.get(c["field"])
        if isinstance(c["from"], str) and isinstance(cur, str) and c["from"] in cur and c["from"] != cur:
            it[c["field"]] = cur.replace(c["from"], c["to"])
        elif cur == c["from"]:
            it[c["field"]] = c["to"]
        else:
            raise SystemExit(f"correction is stale: {c['item']}.{c['field']} is {cur!r}, "
                             f"expected {c['from']!r}")
        applied.append({k: c[k] for k in ("item", "field", "from", "to", "why")})
    return applied


def kana_ok(s: str) -> bool:
    s = JP_PUNCT.sub("", s)
    return not s or is_kana(s)


def twin_errors(ruby: str, kana: str) -> list[str]:
    """ruby_errors(), except for a field that itself holds kanji (Mari's verbatim
    「立入禁止」 in mari.L33.3): its reading cannot equal the field, so the twin must
    read every kanji and print as the field (plain_of(ruby) == kana)."""
    if kana_ok(kana):
        return ruby_errors(ruby, kana)
    errs = ruby_errors(ruby, kana_of(ruby))  # bracket form, and no kanji left unread
    if not errs and plain_of(ruby) != kana:
        errs.append(f"printed text {plain_of(ruby)!r} is not the field {kana!r}")
    return errs


def check_twin(owner: str, obj: dict, field: str) -> list[str]:
    """Check the `<field>_ruby` twin of one Japanese field (a string or a list of strings).

    A list field gets a parallel twin list of strings. A twin whose field is absent is
    checked against the empty value, so a stray twin is never passed through unchecked.
    why_wrong is not twinned: it stays keyed by the hiragana option (PIN-9). A
    kanji-bearing field is matched on its printed text (see twin_errors).
    """
    twin = f"{field}_ruby"
    kana = obj.get(field, [] if field in ("accepted", "options") else "")
    if twin not in obj:
        return [f"{owner}: missing {twin}"] if REQUIRE_RUBY else []
    ruby = obj[twin]
    if isinstance(kana, list):
        if (not isinstance(ruby, list) or len(ruby) != len(kana)
                or not all(isinstance(r, str) for r in ruby)):
            return [f"{owner}: {twin} must be a list of strings parallel to {field}"]
        pairs_ = list(zip(ruby, kana))
    else:
        if not isinstance(ruby, str):
            return [f"{owner}: {twin} must be a string"]
        pairs_ = [(ruby, kana)]
    return [f"{owner}: {twin} {e}" for r, k in pairs_ for e in twin_errors(r, k)]


def check_draft(d: dict, mari: dict) -> list[str]:
    errs = []
    for p in d.get("points", []):
        pid = p.get("id")
        if pid not in mari:
            errs.append(f"{pid}: not one of Mari's points")
            continue
        ex = p.get("examples", [])
        if len(ex) != 2 or ex[0].get("jp") != mari[pid]["example"]:
            errs.append(f"{pid}: first example must be Mari's, verbatim")
        pr = p.get("practice", [])
        if len(pr) < 2:
            errs.append(f"{pid}: needs at least 2 practice items")
        prompts = [q.get("prompt") for q in pr]
        if len(set(prompts)) != len(prompts):
            errs.append(f"{pid}: two practice items share a prompt")
        for e in ex:
            if not kana_ok(e.get("jp", "")) and pid != "mari.L33.3":
                errs.append(f"{pid}: example not kana: {e.get('jp')!r}")
            errs += check_twin(pid, e, "jp")
        for q in pr:
            for field in ("prompt", "answer", "accepted",
                          *(("options",) if "options" in q or "options_ruby" in q else ())):
                errs += check_twin(pid, q, field)
            ans, prompt = q.get("answer", ""), q.get("prompt", "")
            if "＿＿" not in prompt:
                errs.append(f"{pid}: prompt has no blank")
            if not ans or ans in prompt.replace("＿＿", "|"):
                errs.append(f"{pid}: answer missing or leaked into the prompt")
            for s in [prompt, ans, *q.get("accepted", []), *q.get("options", [])]:
                if not kana_ok(s):
                    errs.append(f"{pid}: practice not kana: {s!r}")
            if q.get("kind") == "choose":
                opts = q.get("options", [])
                if len(opts) != 3 or opts.count(ans) != 1 or len(set(opts)) != 3:
                    errs.append(f"{pid}: choose needs 3 distinct options, answer once")
                wrong = set(q.get("why_wrong", {}))
                if wrong and (ans in wrong or not wrong <= set(opts)):
                    errs.append(f"{pid}: why_wrong must explain only the wrong options")
            if re.search(r"\d(にち|ほん|ひき|はい|ふん|ぷん|さつ|かい|こ|にん|か)", prompt + ans):
                errs.append(f"{pid}: digit before a kana counter hides the reading")
    return errs


def reference(b: dict) -> list[dict]:
    titles = {"counters": "Counters", "months": "Months", "durations": "Lengths of time",
              "dates": "Dates"}
    out = []
    for t in ("counters", "months", "dates", "durations"):
        its = [i for i in b["items"] if i["table"] == t]
        cols = list(dict.fromkeys(i["counter"]["written"] for i in its))
        out.append({
            "id": t, "title": titles[t],
            "columns": [next({"written": c, "kana": i["counter"]["kana"], "gloss": i["counter"]["gloss"]}
                             for i in its if i["counter"]["written"] == c) for c in cols],
            "rows": list(dict.fromkeys(i["number"] for i in its)),
            "cells": [{"row": i["number"], "col": i["counter"]["written"], "reading": i["reading"],
                       "alt": i["alt"], "mark": i["mark"]} for i in its],
        })
    return out


def pairs(s02: dict, s03: dict) -> list[dict]:
    out = []
    for it in s02["items"]:
        out.append({"transitive": it["transitive"], "intransitive": it["intransitive"],
                    "transitive_group": it.get("transitive_group"),
                    "intransitive_group": it.get("intransitive_group"),
                    "gloss": it["gloss"], "ex_transitive": it["example_transitive"],
                    "ex_intransitive": it["example_intransitive"], "source": "Mari"})
    for it in s03["items"]:
        if "transitive_verb" not in it:
            continue
        out.append({"transitive": it["transitive_verb"], "intransitive": it["intransitive_verb"],
                    "transitive_group": it.get("transitive_group"),
                    "intransitive_group": it.get("intransitive_group"),
                    "gloss": "", "ex_transitive": it["transitive_kana"] + "。",
                    "ex_intransitive": it["intransitive_kana"] + "。",
                    "kanji_transitive": plain_of(it["transitive"]) + "。",
                    "kanji_intransitive": plain_of(it["intransitive"]) + "。",
                    "kind": it.get("kind", "verb"), "source": "Textbook 8課"})
    return out


def drill(s02: dict, s03: dict, review: dict) -> dict:
    verbs: dict[str, int] = {}
    for it in s02["items"] + [i for i in s03["items"] if "transitive_verb" in i]:
        for side in ("transitive", "intransitive"):
            v = it.get(f"{side}_verb", it.get(side))
            g = it.get(f"{side}_group")
            if v and " " not in v and g:
                verbs.setdefault(v, g)
    lesson30 = json.loads((ASSET.parent / "jp_lessons.json").read_text(encoding="utf-8"))
    for l in lesson30["lessons"]:
        for i in l["items"]:
            if i.get("dictionary") and len(group(i["dictionary"])) == 1:
                verbs.setdefault(i["dictionary"], i["verbGroup"])
    return {"forms": FORMS,
            "verbs": [{"dictionary": v, "group": g, **conjugate(v, g)} for v, g in sorted(verbs.items())]}


def run(out: Path = ASSET) -> tuple[dict, list[str]]:
    review = json.loads((HERE / "corrections.json").read_text(encoding="utf-8"))
    bundles = {s: load(s) for s in review["approved_sources"]}
    for s, b in bundles.items():
        if b["state"] != "needs_review":
            raise SystemExit(f"{s} is {b['state']}, not publishable")
    applied = apply_corrections(bundles, review)

    s04 = bundles["s04_mari_checklist"]
    mari = {p["id"]: p for p in s04["items"]}
    lessons, skipped = {}, []
    for f in sorted(DRAFTS.glob("L*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        errs = check_draft(d, mari)
        if errs:
            skipped += [f"{f.name}: {e}" for e in errs]
            continue
        lessons[d["lesson"]] = d
    # Cataloging runs before Publishing: every item's type and uses come from it, so the
    # app's search and sort read the same catalog the pipeline checked.
    catalog = build_catalog()
    cat_uses = {e["id"]: e["uses"] for e in catalog["entries"]}
    missing = set(mari) - set(cat_uses)
    if missing:
        raise SystemExit(f"catalog: grammar points with no entry {sorted(missing)}")
    grammar = []
    for n in s04["lessons"]:
        pts = [p for p in s04["items"] if p["lesson"] == n]
        d = lessons.get(n, {})
        drafted = {p["id"]: p for p in d.get("points", [])}
        grammar.append({
            "lesson": n, "title": d.get("title", ""),
            "status": "draft" if d else "outline",
            "points": [{"id": p["id"], "pattern": p["pattern"], "goal": p["goal"],
                        "uses": cat_uses[p["id"]],
                        "example": p["example"], **{k: v for k, v in drafted.get(p["id"], {}).items()
                                                     if k not in ("id",)}} for p in pts],
        })

    doc = {
        "note": "Grammar from Mari's N4 checklist (lessons 26 to 50), with short lessons drafted "
                "for review. Reference tables, verb pairs and conjugations are extracted and checked.",
        "reviewed": {"by": review["reviewed_by"], "at": review["reviewed_at"], "corrections": applied},
        "types": catalog["types"],
        "uses": catalog["uses"],
        "catalog": catalog["entries"],
        "grammar": grammar,
        "particles": [{k: p[k] for k in ("expression", "meaning", "example", "taught_in")}
                      for p in s04["particles"]],
        "reference": reference(bundles["s01_number"]),
        "pairs": pairs(bundles["s02_pairs_mari"], bundles["s03_pairs_textbook"]),
        "conjugation": drill(bundles["s02_pairs_mari"], bundles["s03_pairs_textbook"], review),
    }
    out.write_text(json.dumps(doc, ensure_ascii=False, indent=1), encoding="utf-8")
    drafted = sum(1 for g in grammar if g["status"] == "draft")
    print(f"wrote {out.name}: {len(grammar)} lessons ({drafted} drafted), "
          f"{len(doc['pairs'])} pairs, {len(doc['conjugation']['verbs'])} drill verbs, "
          f"{len(applied)} corrections")
    for s in skipped:
        print("SKIP", s)
    return doc, skipped


if __name__ == "__main__":
    run()
