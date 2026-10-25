"""Source 3: 他動詞_自動詞.png, a scanned textbook page (8課, transitive and
intransitive verbs). Run: python s03_pairs_textbook.py

This source has NO text layer, so the OPM's Normalizing step cannot run as it does for
a PDF. It needs a Transcribing stage, and that stage is an LM (vision) call, which is
why everything here lands in needs_review rather than passing straight through.

Two independent readings of the page:
- TRANSCRIPTION below: read from the image by Claude (vision), with the furigana
  written out so every kanji carries its reading.
- Windows built-in OCR (winocr.ps1, ja): noisy on small kana and furigana, but
  independent. Every transcribed line is matched against it; a weak match becomes a
  review note naming the line, so a person checks exactly those.
"""

from __future__ import annotations

import json
import subprocess
from difflib import SequenceMatcher
from pathlib import Path

from common import SOURCE_DIR, bundle, ingest, is_kana, write
from conjugate import group
from ruby import kana_of, plain_of  # plain_of: the text as printed, what the OCR read

SOURCE_ID = "s03_pairs_textbook"
FILE = "他動詞_自動詞.png"

# Kanji are written 漢字{かんじ}: base text, then its furigana from the page (ruby.py).
# (transitive phrase, intransitive phrase), in the page's reading order.
TRANSCRIPTION = {
    "title": "8課 他動詞{たどうし}・自動詞{じどうし} Transitive and intransitive verbs",
    "patterns": {
        "transitive": "動作主{どうさしゅ}が／は＋～(目的語{もくてきご})を＋他動詞{たどうし}",
        "intransitive": "～が／は＋自動詞{じどうし}",
    },
    "focus": {
        "transitive": "Focus is on the action or behavior of an agent.",
        "intransitive": "Focus is on the action or behavior.",
    },
    "model": {
        "transitive": "わたしは 火{ひ}を けしました。",
        "intransitive": "火{ひ}が きえました。",
    },
    "pairs": [
        ("電気{でんき}を つける", "電気{でんき}が つく"),
        ("かぎを しめる", "かぎが しまる"),
        ("ごみを おとす", "ごみが おちる"),
        ("いすを ならべる", "いすが ならぶ"),
        ("仕事{しごと}を 見{み}つける", "仕事{しごと}が 見{み}つかる"),
        ("話{はなし}を つづける", "話{はなし}が つづく"),
        ("ねだんを 上{あ}げる", "ねだんが 上{あ}がる"),
        ("ねだんを 下{さ}げる", "ねだんが 下{さ}がる"),
        ("えだを おる", "えだが おれる"),
        ("家{いえ}を こわす", "家{いえ}が こわれる"),
        ("子{こ}どもを 起{お}こす", "子{こ}どもが 起{お}きる"),
        ("パンを やく", "パンが やける"),
        ("車{くるま}を 止{と}める", "車{くるま}が 止{と}まる"),
        ("じゅぎょうを 始{はじ}める", "じゅぎょうが 始{はじ}まる"),
        ("ねこを 家{いえ}に 入{い}れる", "ねこが 家{いえ}に 入{はい}る"),
        ("きっぷを なくす", "きっぷが なくなる"),
        ("自転車{じてんしゃ}を なおす", "自転車{じてんしゃ}が なおる"),
        ("病気{びょうき}を なおす", "病気{びょうき}が なおる"),
        ("名前{なまえ}を かえる", "名前{なまえ}が かわる"),
        ("へやを あたたかく する", "へやが あたたかく なる"),
    ],
    "examples": {
        "transitive": [
            "暑{あつ}いので、まどを 開{あ}けます。",
            "へやに いた 虫{むし}を 外{そと}に 出{だ}しました。",
            "トムは 古{ふる}い おもちゃを 集{あつ}めて います。",
        ],
        "intransitive": [
            "車{くるま}の ドアが 急{きゅう}に 開{あ}きました。",
            "学生{がくせい}は 後{うし}ろの ドアから 出{で}ます。",
            "みんなが 集{あつ}まって、旅行{りょこう}の そうだんを します。",
        ],
    },
}

def _ocr(path: Path) -> list[str]:
    out = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
         str(Path(__file__).parent / "winocr.ps1"), str(path)],
        capture_output=True, check=True)
    data = json.loads(out.stdout.decode("utf-8-sig"))
    return [l["text"].replace(" ", "") for l in data["lines"]]


def _best(line: str, ocr: list[str]) -> tuple[float, str]:
    target = line.replace(" ", "").replace("　", "")
    return max(((SequenceMatcher(None, target, o).ratio(), o) for o in ocr), default=(0, ""))


def run() -> dict:
    raw = ingest(SOURCE_DIR / FILE, SOURCE_ID)
    ocr = _ocr(Path(raw["origin"]))
    write(SOURCE_ID, "canonical_text", {"transcription": TRANSCRIPTION, "ocr_lines": ocr,
                                        "transcribed_by": "claude-vision"})
    t = TRANSCRIPTION
    items = []
    for n, (tr, intr) in enumerate(t["pairs"], start=1):
        items.append({"id": f"{SOURCE_ID}.{n}", "transitive": tr, "intransitive": intr,
                      "transitive_kana": kana_of(tr), "intransitive_kana": kana_of(intr)})
    for side in ("transitive", "intransitive"):
        for n, ex in enumerate(t["examples"][side], start=1):
            items.append({"id": f"{SOURCE_ID}.ex.{side}.{n}", "side": side, "sentence": ex,
                          "kana": kana_of(ex)})
    write(SOURCE_ID, "mined", {"items": items})

    failures, notes = [], []
    for it in items:
        for k in ("transitive_kana", "intransitive_kana", "kana"):
            if k in it and not is_kana(it[k].replace("。", "").replace("、", "")):
                failures.append({"item_id": it["id"], "check": "ruby_complete",
                                 "detail": f"kanji left without a reading: {it[k]!r}"})
        if "transitive" in it and "を" not in it["transitive"]:
            failures.append({"item_id": it["id"], "check": "transitive_takes_o",
                             "detail": it["transitive"]})
        if "intransitive" in it and "が" not in it["intransitive"]:
            failures.append({"item_id": it["id"], "check": "intransitive_takes_ga",
                             "detail": it["intransitive"]})

    # The verb is the last word of each phrase. あたたかく する / なる is an adjective
    # with する / なる, not a verb pair, so it is kept but labeled as a pattern.
    for it in items:
        if "transitive_kana" not in it:
            continue
        for side in ("transitive", "intransitive"):
            words = it[f"{side}_kana"].split()
            verb = words[-1]
            if words[-2:] in (["あたたかく", "する"], ["あたたかく", "なる"]):
                it["kind"] = "adjective + する / なる"
                verb = " ".join(words[-2:])
            it[f"{side}_verb"] = verb
            gs = group(verb.split()[-1])
            it[f"{side}_group"] = gs.pop() if len(gs) == 1 else None
            if it[f"{side}_group"] is None:
                notes.append(f"{verb}: group cannot be decided from the dictionary form "
                             f"(pair {it['transitive_kana']} / {it['intransitive_kana']}). "
                             f"Marked uncertain.")

    # Independent check: where this page and Mari's table (source 2) share a pair,
    # they must pair the same two verbs.
    mari = Path(__file__).parent / "out" / "s02_pairs_mari" / "lesson_bundle.json"
    if mari.exists():
        mp = json.loads(mari.read_text(encoding="utf-8"))["items"]
        by_tr = {m["transitive"]: m["intransitive"] for m in mp}
        by_in = {m["intransitive"]: m["transitive"] for m in mp}
        shared = 0
        for it in items:
            tv, iv = it.get("transitive_verb"), it.get("intransitive_verb")
            for a, b, table in ((tv, iv, by_tr), (iv, tv, by_in)):
                if a in table:
                    shared += 1
                    if table[a] != b:
                        failures.append({"item_id": it["id"], "check": "agrees_with_mari",
                                         "detail": f"{a} pairs with {b} here, {table[a]} in source 2"})
        notes.append(f"{shared} verb pairings shared with Mari's table (source 2), all checked")

    # Cross-check against the OCR. 0.6 is loose on purpose: the OCR drops small
    # kana and furigana, so a correct line can still score in the 0.6s.
    lines = [p for pair in t["pairs"] for p in pair]
    lines += t["examples"]["transitive"] + t["examples"]["intransitive"]
    weakest = []
    for line in lines:
        score, hit = _best(plain_of(line), ocr)
        weakest.append((score, plain_of(line), hit))
        if score < 0.6:
            notes.append(f"OCR disagrees (score {score:.2f}): transcribed {plain_of(line)!r}, "
                         f"OCR best {hit!r}. Check against the image.")
    weakest.sort()
    return bundle(SOURCE_ID, raw, items, failures, notes,
                  transcribed_by="claude-vision", ocr_engine="Windows.Media.Ocr ja",
                  title=t["title"], patterns=t["patterns"], focus=t["focus"], model=t["model"],
                  ocr_weakest=[{"score": round(s, 2), "line": l, "ocr": o} for s, l, o in weakest[:8]])


if __name__ == "__main__":
    b = run()
    print(b["state"], b["item_count"], "items")
    for f in b["validation"]["failures"]:
        print("FAIL", f)
    for n in b["review_notes"]:
        print("NOTE", n)
    for w in b["ocr_weakest"]:
        print("weak", w)
