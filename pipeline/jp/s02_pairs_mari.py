"""Source 2: Mari's transitive / intransitive table (し_と_うし__か__.pdf, made in
Canva, author 中川真梨). Run: python s02_pairs_mari.py

Shape: a vector table with a real text layer, 4 columns (intransitive, transitive,
English, two example sentences). Rows are found from the verb in column 1; every
other line joins the row whose center is nearest.

Validating does more than check kana. Each example must contain the ます form that
conjugate.py derives for its verb, with が for the intransitive and を for the
transitive. That catches a pair printed in swapped columns, and it RESOLVES the
verb group where the dictionary form alone cannot (the example shows the ます form).
"""

from __future__ import annotations

import fitz

from common import SOURCE_DIR, bundle, ingest, is_kana, nfc, write
from conjugate import group, masu_candidates

SOURCE_ID = "s02_pairs_mari"
FILE = "し_と_うし__か__.pdf"


def _lines(page) -> list[dict]:
    out = []
    for b in page.get_text("dict")["blocks"]:
        for l in b.get("lines", []):
            t = nfc("".join(s["text"] for s in l["spans"]))
            if t:
                x0, y0, x1, y1 = l["bbox"]
                out.append({"text": t, "cx": (x0 + x1) / 2, "cy": (y0 + y1) / 2})
    return out


def resolve_group(dic: str, example: str) -> tuple[int | None, bool]:
    """Pick the group whose ます form the example actually uses."""
    hits = [g for g, m in masu_candidates(dic).items() if m in example]
    if len(hits) == 1:
        return hits[0], len(group(dic)) > 1
    return None, False


def run() -> dict:
    raw = ingest(SOURCE_DIR / FILE, SOURCE_ID)
    doc = fitz.open(raw["origin"])
    pages = [_lines(p) for p in doc]
    write(SOURCE_ID, "canonical_lines", pages)

    # Column edges from the header row on page 1.
    hdr = {l["text"]: l for l in pages[0]}
    cols = sorted(hdr[k]["cx"] for k in ("じどうし（～が）", "たどうし（～を）", "English", "example"))
    edges = [(a + b) / 2 for a, b in zip(cols, cols[1:])]
    # The header ends at its lowest line ("intransitive"), not at a fixed y. A fixed
    # cutoff silently dropped the first example sentence on the first run.
    header_bottom = max(hdr[k]["cy"] for k in ("intransitive", "transitive")) + 4

    def col(x):
        return sum(x > e for e in edges)

    items, notes = [], []
    for pno, lines in enumerate(pages, start=1):
        body = [l for l in lines if not (pno == 1 and l["cy"] <= header_bottom)]
        rows = sorted((l for l in body if col(l["cx"]) == 0), key=lambda l: l["cy"])
        cells = [{0: [r["text"]], 1: [], 2: [], 3: []} for r in rows]
        for l in body:
            c = col(l["cx"])
            if c == 0:
                continue
            k = min(range(len(rows)), key=lambda k: abs(rows[k]["cy"] - l["cy"]))
            cells[k][c].append(l)
        for k, c in enumerate(cells):
            eng = " ".join(x["text"] for x in sorted(c[2], key=lambda x: x["cy"]))
            ex = [x["text"] for x in sorted(c[3], key=lambda x: x["cy"])]
            items.append({
                "id": f"{SOURCE_ID}.{pno}.{k + 1}",
                "intransitive": c[0][0],
                "transitive": c[1][0]["text"] if c[1] else "",
                "gloss": eng.replace("( ", "(").replace(" )", ")"),
                "example_intransitive": ex[0] if ex else "",
                "example_transitive": ex[1] if len(ex) > 1 else "",
                "extra_lines": ex[2:] + [x["text"] for x in c[1][1:]],
            })
    write(SOURCE_ID, "mined", {"items": items})

    failures = []
    for it in items:
        for f in ("intransitive", "transitive", "example_intransitive", "example_transitive"):
            if not is_kana(it[f].replace("。", "")):
                failures.append({"item_id": it["id"], "check": "kana_only", "detail": f"{f}: {it[f]!r}"})
        if it["extra_lines"]:
            failures.append({"item_id": it["id"], "check": "one_line_per_cell",
                             "detail": str(it["extra_lines"])})
        for side, particle in (("intransitive", "が"), ("transitive", "を")):
            ex = it[f"example_{side}"]
            g, was_ambiguous = resolve_group(it[side], ex)
            if g is None:
                failures.append({"item_id": it["id"], "check": "example_uses_verb",
                                 "detail": f"{it[side]} not found as a ます form in {ex!r}"})
                continue
            it[f"{side}_group"] = g
            if was_ambiguous:
                notes.append(f"{it[side]}: group {g} decided by the example {ex!r}")
            if particle not in ex:
                notes.append(f"{it['id']}: {side} example has no {particle}: {ex!r}")

    # The same pair can appear twice with two senses (つく / つける). Keep both, say so.
    seen: dict[tuple, str] = {}
    for it in items:
        key = (it["intransitive"], it["transitive"])
        if key in seen:
            notes.append(f"pair {key[0]} / {key[1]} appears twice: "
                         f"{seen[key]!r} and {it['gloss']!r} (two senses, both kept)")
        seen[key] = it["gloss"]

    return bundle(SOURCE_ID, raw, items, failures, notes,
                  author=doc.metadata.get("author"), made_with=doc.metadata.get("creator"))


if __name__ == "__main__":
    b = run()
    print(b["state"], b["item_count"], "items")
    for f in b["validation"]["failures"]:
        print("FAIL", f)
    for n in b["review_notes"]:
        print("NOTE", n)
    for it in b["items"]:
        print(it["intransitive"], it.get("intransitive_group"), "|", it["transitive"],
              it.get("transitive_group"), "|", it["gloss"], "|", it["example_intransitive"],
              "/", it["example_transitive"])
