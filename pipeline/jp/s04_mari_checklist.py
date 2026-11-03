"""Source 4: Mari's "N4 Grammar_Markさん" Google Sheet, tabs Checklist, particle and
Progress Summary. Run: python s04_mari_checklist.py <path to the exported .xlsx>

This source changes the OPM. Mari is a tutor, and the checklist is HER curriculum:
lesson -> grammar points -> pattern, example, goal. So the grammar points are not
MINED from text (SD1 Mining); they are GIVEN by a person, the same way Reviewing is.
The extraction is deterministic, and the LM has no job here.

Checks that need no LM:
- the Progress Summary tab counts items per lesson. Those counts must equal the
  checklist rows per lesson: two tables in one workbook that must agree.
- the "form" lessons list example conjugations (いこう／たべよう／しよう／こよう).
  conjugate.py must produce exactly those, which tests the engine against Mari.
- each pattern names the verb forms it needs (てForm, ないForm ...). Those become
  prerequisites, which the OPM's Scoping step asked for and never had.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import openpyxl

from common import bundle, ingest, is_kana, nfc, write
from conjugate import MARI_DRILLS as FORM_DRILLS, conjugate, group
from s01_counters import NUM as NUMBERS

SOURCE_ID = "s04_mari_checklist"

# Pattern slot -> conjugate.py form. Order matters: longest names first.
SLOTS = [
    ("ふつうForm", "plain"), ("ふつうFrom", "plain"), ("じしょForm", "dictionary"),
    ("ますForm", "masu"), ("ますけい", "masu"), ("てForm", "te"), ("ないForm", "nai"),
    ("たForm", "ta"), ("かのうどうし", "potential"), ("いこうけい", "volitional"),
    ("じょうけんけい", "conditional"), ("めいれいけい", "imperative"),
    ("きんしけい", "prohibitive"), ("うけみけい", "passive"), ("Passive Form", "passive"),
    ("しえきけい", "causative"), ("（さ）せます", "causative"),
]

# Lessons whose example cell is a list of conjugations, to test the engine with.


def _sheet_rows(ws):
    """Rows with merged cells filled in from their top-left cell."""
    fill = {}
    for rng in ws.merged_cells.ranges:
        v = ws.cell(rng.min_row, rng.min_col).value
        for r in range(rng.min_row, rng.max_row + 1):
            for c in range(rng.min_col, rng.max_col + 1):
                fill[(r, c)] = v
    for r in range(1, ws.max_row + 1):
        yield r, [fill.get((r, c), ws.cell(r, c).value) for c in range(1, ws.max_column + 1)]


def _txt(v) -> str:
    return nfc(str(v)) if v is not None else ""


def run(xlsx: Path) -> dict:
    raw = ingest(xlsx, SOURCE_ID)
    wb = openpyxl.load_workbook(xlsx)

    ws = wb["Checklist "]
    links = {}
    for row in ws.iter_rows():
        for c in row:
            if c.hyperlink and c.hyperlink.target:
                links[c.row] = c.hyperlink.target
    points, notes, failures = [], [], []
    lesson_link = {}
    for r, v in _sheet_rows(ws):
        if r == 1 or not _txt(v[2]):
            continue
        m = re.search(r"だい(\d+)か", _txt(v[0]))
        lesson = int(m.group(1)) if m else None
        if r in links:
            lesson_link[lesson] = links[r]
        pattern = _txt(v[2])
        forms = []
        for slot, form in SLOTS:
            if slot in pattern and form not in forms:
                forms.append(form)
        points.append({
            "id": f"mari.L{lesson}.{int(v[1])}", "lesson": lesson, "no": int(v[1]),
            "pattern": pattern, "example": _txt(v[3]), "goal": _txt(v[4]),
            "requires_forms": forms,
            # Mari's own tracking columns. Empty today; kept so the app can mirror them.
            "after_class": _txt(v[6]), "can_use_it": _txt(v[7]), "review_needed": _txt(v[8]),
            "notes": _txt(v[9]),
        })
    for p in points:
        p["resource"] = {"kind": "canva", "label": f"Mari's notes, lesson {p['lesson']}",
                         "url": lesson_link.get(p["lesson"])}

    particles = []
    for r, v in _sheet_rows(wb["particle"]):
        if r == 1 or not _txt(v[0]):
            continue
        particles.append({"id": f"mari.particle.{r - 1}", "expression": _txt(v[0]),
                          "meaning": _txt(v[1]), "example": _txt(v[2])})
    # Link each particle row to the checklist lesson that teaches it, if one does.
    for pa in particles:
        key = pa["expression"].split("（")[0].split("〜")[0]
        hits = sorted({p["lesson"] for p in points if key and key in p["pattern"]})
        pa["taught_in"] = hits

    # Progress Summary holds formulas like =COUNTA('Checklist '!C2:C4). Read both the
    # cached value and the range: a range that drifted off its lesson's rows counts
    # the wrong items, and the cached number alone would hide that.
    cached = openpyxl.load_workbook(xlsx, data_only=True)["Progress Summary"]
    rows_of = {}
    for p_row, p in zip([r for r, v in _sheet_rows(ws) if r > 1 and _txt(v[2])], points):
        rows_of.setdefault(p["lesson"], []).append(p_row)
    progress, ranges = {}, {}
    for r, v in _sheet_rows(wb["Progress Summary"]):
        m = re.search(r"だい(\d+)か", _txt(v[0]))
        if not m:
            continue
        lesson = int(m.group(1))
        progress[lesson] = cached.cell(r, 2).value
        f = re.search(r"C(\d+):C(\d+)", _txt(v[1]))
        if f:
            ranges[lesson] = (int(f.group(1)), int(f.group(2)))
    write(SOURCE_ID, "mined", {"points": points, "particles": particles, "progress": progress})

    # ── Validating
    for p in points:
        for k in ("pattern", "example", "goal"):
            if not p[k]:
                failures.append({"item_id": p["id"], "check": "field_present", "detail": k})
        if not p["resource"]["url"]:
            failures.append({"item_id": p["id"], "check": "lesson_has_notes_link", "detail": ""})
        ex = re.sub(r"[0-9０-９。、！？「」／・\s]", "", p["example"])
        if ex and not is_kana(ex):
            notes.append(f"{p['id']}: example has kanji or Latin, check the app can show it: "
                         f"{p['example']!r}")
        if "ふつうFrom" in p["pattern"]:
            notes.append(f"{p['id']}: typo in the sheet, ふつうFrom for ふつうForm "
                         f"(read as plain form)")
    counted = {}
    for p in points:
        counted[p["lesson"]] = counted.get(p["lesson"], 0) + 1
    for lesson in sorted(set(counted) | set(progress)):
        if counted.get(lesson) != progress.get(lesson):
            failures.append({"item_id": f"L{lesson}", "check": "progress_count_agrees",
                             "detail": f"checklist {counted.get(lesson)}, "
                                       f"Progress Summary {progress.get(lesson)}"})
    for lesson, rows in rows_of.items():
        want = (min(rows), max(rows))
        if ranges.get(lesson) != want:
            failures.append({"item_id": f"L{lesson}", "check": "progress_formula_range",
                             "detail": f"formula counts rows {ranges.get(lesson)}, "
                                       f"lesson is rows {want}"})
    lessons = sorted(counted)
    if lessons != list(range(lessons[0], lessons[-1] + 1)):
        failures.append({"item_id": "lessons", "check": "contiguous", "detail": str(lessons)})

    # Mari's example conjugations against the engine.
    for p in points:
        drill = FORM_DRILLS.get(p["pattern"])
        if not drill:
            continue
        given = [s.strip().rstrip("！") for s in p["example"].split("／")]
        derived = [conjugate(v, group(v).pop())[form] for v, form in drill]
        if given != derived:
            failures.append({"item_id": p["id"], "check": "engine_matches_mari",
                             "detail": f"sheet {given}, engine {derived}"})
        else:
            notes.append(f"{p['id']}: engine reproduces Mari's examples {given}")
    # Cross-source: a digit written before a kana counter (3にち) hides the reading.
    # Source 1's tables know the real one. If it is not just number + counter, the
    # learner will say it wrong, so flag it.
    s01 = Path(__file__).parent / "out" / "s01_number" / "lesson_bundle.json"
    if s01.exists():
        import json
        table = {}
        for it in json.loads(s01.read_text(encoding="utf-8"))["items"]:
            kana = it["counter"]["kana"].split("(")[0]
            if kana and it["table"] in ("counters", "durations"):
                table.setdefault((it["number"], kana), it["reading"])
        for src in [*points, *particles]:
            for n, ctr in re.findall(r"(\d+)(にち|ほん|ひき|はい|ぷん|ふん|さつ|かい|こ|にん)",
                                     src["example"]):
                ctr_key = {"ぷん": "ふん"}.get(ctr, ctr)
                reading = table.get((n, ctr_key))
                if reading and reading != NUMBERS.get(n, "") + ctr:
                    notes.append(f"{src['id']}: {n}{ctr} in {src['example']!r} reads {reading}. "
                                 f"Write it in kana so the app does not teach the wrong sound.")

    unchecked = [p["pattern"] for p in points
                 if p["pattern"] not in FORM_DRILLS and "／" in p["example"]
                 and is_kana(p["example"].replace("／", "").replace("！", ""))
                 and " " not in p["example"]]
    if unchecked:
        notes.append(f"conjugation lists not yet checked against the engine: {unchecked}")

    return bundle(SOURCE_ID, raw, points, failures, notes, particles=particles,
                  lessons=lessons, notes_links=lesson_link)


if __name__ == "__main__":
    b = run(Path(sys.argv[1]))
    print(b["state"], b["item_count"], "grammar points,", len(b["particles"]), "particles,",
          "lessons", b["lessons"][0], "to", b["lessons"][-1])
    for f in b["validation"]["failures"]:
        print("FAIL", f)
    for n in b["review_notes"]:
        print("NOTE", n)
    for pa in b["particles"]:
        print("particle", pa["expression"], "->", pa["taught_in"])
    from collections import Counter
    print(Counter(f for p in b["items"] for f in p["requires_forms"]))
