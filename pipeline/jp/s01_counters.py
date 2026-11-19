"""Source 1: number.pdf, three quick-reference tables (counters, months and dates,
lengths of time). Run: python s01_counters.py

Classifying is fixed for this source: docKind = language lesson, shape = reference
table. Mining is deterministic: the table IS the answer key, so there is nothing for
an LM to mine. The risk is the OCR layer, so Validating cross-checks every reading
against an independent rule derivation and reports each disagreement for review.
"""

from __future__ import annotations

import re

import fitz

from common import SOURCE_DIR, bundle, ingest, is_kana, write
from image_table import normalize_page

SOURCE_ID = "s01_number"
DATA = ("regular", "sound_change", "special")

# Number readings the rule derivation starts from.
NUM = {"1": "いち", "2": "に", "3": "さん", "4": "よん", "5": "ご", "6": "ろく",
       "7": "なな", "8": "はち", "9": "きゅう", "10": "じゅう", "何": "なん",
       "11": "じゅういち", "12": "じゅうに"}
# Native-count readings, used by つ and as alternates elsewhere.
ALT_NUM = {"4": ("よ", "し"), "7": ("しち",), "9": ("く",)}

GEMINATE = {"1": "いっ", "6": "ろっ", "8": "はっ", "10": "じゅっ"}
H_TO_P = {"は": "ぱ", "ひ": "ぴ", "ふ": "ぷ", "へ": "ぺ", "ほ": "ぽ"}
H_TO_B = {"は": "ば", "ひ": "び", "ふ": "ぶ", "へ": "べ", "ほ": "ぼ"}
K_ROW = set("かきくけこ")
S_ROW = set("さしすせそ")
T_ROW = set("たちつてと")


def derive(n: str, counter: str) -> set[str]:
    """An INDEPENDENT reading for (number, counter), from the sound-change rules.

    It is not meant to be complete. Its job is to disagree with the OCR loudly, so a
    person looks at exactly the cells where two derivations differ.
    """
    head, rest = counter[0], counter[1:]
    base = {NUM[n] + counter} | {a + counter for a in ALT_NUM.get(n, ())}
    if head in "はひふへほ":
        if n in GEMINATE:
            return {GEMINATE[n] + H_TO_P[head] + rest}
        if n in ("3", "何"):
            # 3 and 何 voice: さんぼん, さんびき, さんばい. 分 is the exception (さんぷん).
            first = H_TO_P if counter == "ふん" else H_TO_B
            return {NUM[n] + first[head] + rest}
        if n == "4" and counter == "ふん":
            return {"よんぷん"}
        return base
    # 6 geminates only before k (ろっこ, ろっかい). Before s and t it stays ろく (ろくさつ).
    if head in K_ROW and n in GEMINATE or head in S_ROW | T_ROW and n in ("1", "8", "10"):
        if counter == "さい" and n == "1":
            return {"いっさい"}
        return {GEMINATE[n] + counter} | ({NUM[n] + counter} if n == "8" else set())
    if counter == "かい_floor" and n in ("3", "何"):
        return {NUM[n] + "がい"}
    return base


def _text(cell) -> tuple[str, list[str]]:
    main, alt = [], []
    for line in cell["lines"]:
        t = line["text"]
        m = re.fullmatch(r"[（(](.+)[）)]", t)
        (alt if m else main).append(m.group(1) if m else t)
    return "".join(main), alt


def _grid(page: dict, table: str, x_min: float = 0, x_max: float = 9999) -> tuple[list, list]:
    cells = [c for c in page["cells"] if x_min <= c["x"] < x_max]
    labels = [c for c in cells if c["fill"].startswith("header") and c["x"] < x_min + 60]
    top = min(l["y"] for l in labels)
    # A column header can come back as several cells (one per text line), so merge
    # every header cell above the first row that shares the column's left edge.
    heads: dict[float, list] = {}
    for c in cells:
        if c["fill"].startswith("header") and c["x"] >= x_min + 60 and c["y"] < top:
            key = next((k for k in heads if abs(k - c["x"]) <= 4), c["x"])
            heads.setdefault(key, []).extend(c["lines"])
    items, notes = [], []
    for c in cells:
        if c["fill"] not in DATA:
            continue
        row = min(labels, key=lambda l: abs(l["y"] - c["y"]))
        col = next((x for x in heads if abs(x - c["x"]) <= 4), None)
        if abs(row["y"] - c["y"]) > 20 or col is None:
            notes.append(f"{table}: cell at ({c['x']},{c['y']}) has no row or column header")
            continue
        hl = [l["text"] for l in sorted(heads[col], key=lambda l: l["y"])]
        reading, alt = _text(c)
        # The months headers have no kana line (〜月 / month name), so a second line
        # is the reading only if it is kana.
        has_kana = len(hl) > 1 and is_kana(hl[1].replace("…", "").split("(")[0])
        items.append({
            "table": table, "number": _text(row)[0], "col": col, "row_y": row["y"],
            "counter": {"written": hl[0], "kana": hl[1] if has_kana else "",
                        "gloss": " ".join(hl[2:] if has_kana else hl[1:])},
            "reading": reading, "alt": alt, "mark": c["fill"],
        })
    return items, notes


def _dates(page: dict) -> tuple[list, list]:
    items, notes = [], []
    for c in page["cells"]:
        if c["x"] < 300 or c["fill"] not in DATA + ("header_alt",):
            continue
        lines = [l["text"] for l in c["lines"]]
        m = re.fullmatch(r"(\d+|何)日", lines[0])
        if not m:
            notes.append(f"dates: cell {lines} does not start with N日")
            continue
        items.append({"table": "dates", "number": m.group(1), "col": 0,
                      "row_y": int(m.group(1)) if m.group(1).isdigit() else 99,
                      "counter": {"written": "日", "kana": "", "gloss": "day of the month"},
                      "reading": "".join(lines[1:]), "alt": [],
                      "mark": "regular" if c["fill"] == "header_alt" else c["fill"]})
    return items, notes


EXPECTED = {"counters": 13 * 11, "months": 2 * 13, "dates": 32, "durations": 6 * 11}


def run() -> dict:
    raw = ingest(SOURCE_DIR / "number.pdf", SOURCE_ID)
    doc = fitz.open(raw["origin"])
    pages = [normalize_page(p) for p in doc]
    write(SOURCE_ID, "canonical_table", pages)

    items, notes = [], []
    for table, page, lo, hi in (("counters", pages[0], 0, 9999),
                                ("months", pages[1], 0, 300),
                                ("durations", pages[2], 0, 9999)):
        got, n = _grid(page, table, lo, hi)
        items += got
        notes += n
    got, n = _dates(pages[1])
    items += got
    notes += n
    footnotes = {p["page"]: [l["text"] for l in p["loose_text"] if l["text"].startswith("*")]
                 for p in pages}
    order = {t: n for n, t in enumerate(EXPECTED)}
    items.sort(key=lambda it: (order[it["table"]], it["col"], it["row_y"]))
    for it in items:
        del it["col"], it["row_y"]
    write(SOURCE_ID, "mined", {"items": items, "notes": notes})

    # ── Validating: hard checks block the bundle, soft ones become review notes.
    failures = []
    for i, it in enumerate(items):
        it["id"] = f"{SOURCE_ID}.{it['table']}.{it['counter']['written']}.{it['number']}"
        for r in [it["reading"], *it["alt"]]:
            if not is_kana(r):
                failures.append({"item_id": it["id"], "check": "kana_only", "detail": r})
    for table, want in EXPECTED.items():
        have = sum(1 for it in items if it["table"] == table)
        if have != want:
            failures.append({"item_id": table, "check": "grid_complete",
                             "detail": f"{have} cells, expected {want}"})
    ids = [it["id"] for it in items]
    for dup in {x for x in ids if ids.count(x) > 1}:
        failures.append({"item_id": dup, "check": "unique_id", "detail": "duplicate cell"})

    # The legend is data, so check it too: a regular (grey) cell should read as the
    # plain number plus the plain counter. If it does not, the sheet left a sound
    # change unmarked, and the app would teach it without the warning color.
    plain = {"〜月": "がつ", "〜か月": "かげつ"}
    for it in items:
        kana = plain.get(it["counter"]["written"], it["counter"]["kana"].split("(")[0])
        n = it["number"]
        if it["mark"] != "regular" or not kana or n not in NUM or kana == "ひとつ…":
            continue
        naive = {NUM[n] + kana} | {a + kana for a in ALT_NUM.get(n, ())}
        if it["reading"] not in naive:
            notes.append(f"unmarked change: {it['counter']['written']} {n} = {it['reading']}, "
                         f"plain would be {sorted(naive)[0]}")

    for it in items:
        if it["table"] not in ("counters", "durations"):
            continue
        kana = it["counter"]["kana"].split("(")[0]
        if it["counter"]["written"] == "階":
            kana = "かい_floor"
        # A cell the sheet marks "special" is a word to learn whole (ひとつ, ふつか), so
        # no rule applies. The つ series is native Japanese counting throughout.
        if not kana or it["number"] not in NUM or it["mark"] == "special" or kana == "つ":
            continue
        want = {w.replace("かい_floor", "かい") for w in derive(it["number"], kana)}
        got = {it["reading"], *it["alt"]}
        if not want & got:
            notes.append(f"rule disagrees: {it['counter']['written']} {it['number']}: "
                         f"sheet {sorted(got)}, rule {sorted(want)}")

    return bundle(SOURCE_ID, raw, items, failures, notes, footnotes=footnotes,
                  legend={"sound_change": "the sound of the number or counter changes",
                          "special": "special reading, learn it as a word"})


if __name__ == "__main__":
    b = run()
    print(b["state"], b["item_count"], "items")
    for f in b["validation"]["failures"]:
        print("FAIL", f)
    for n in b["review_notes"]:
        print("NOTE", n)
