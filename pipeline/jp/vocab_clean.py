"""Vocabulary clean-up: rewrites assets/lessons/jp_lessons.json in place.
Run after any re-extraction of the word list: python vocab_clean.py

The extractor that read the Langoal word-list sheets is not committed, so its defects
are fixed here, in one pass that is a no-op on its own output (idempotent):

- A hyphen in a reading (`-`, `－`, `‐`) is the long-vowel mark ー misread.
- A bracketed or parenthesised part of a reading (`すいます[たばこを]`, `(お)さけ`) is
  context, not the word: it moves to a `context` field and the reading keeps the head
  word. A reading whose bracket holds only a particle (`さわります[に]`) keeps its verb.
- A leading gloss token followed by a comma is the sheet's printed romaji when it equals
  the item's own reading in Hepburn romaji (`jisho, dictionary`); that token is dropped.
  The match is strict, so an English first meaning (`watch, clock`) always stays.
- `ふくしゅうします` is a group 3 verb (する verb), so its group is not uncertain.
- Every item gets an `id`, its image stem (`L30_02`). Identical-duplicate cards keep
  their own ids and pictures (PIN-16): nothing is merged.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

ASSET = Path(__file__).resolve().parents[2] / "assets" / "lessons" / "jp_lessons.json"

HYPHENS = str.maketrans({"-": "ー", "－": "ー", "‐": "ー"})
# One bracketed or parenthesised part of a reading, half or full width.
BRACKET = re.compile(r"[\[［(（]([^\]］)）]*)[\]］)）]")
# Verbs whose group the ます form leaves open but the dictionary form settles.
GROUP_SETTLED = {"ふくしゅうします"}

# ───────────── Hepburn romaji of a kana reading ─────────────

_BASE = {
    "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
    "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
    "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
    "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
    "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
    "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
    "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
    "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
    "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
    "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
    "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
    "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
    "や": "ya", "ゆ": "yu", "よ": "yo",
    "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
    "わ": "wa", "ゐ": "i", "ゑ": "e", "を": "o", "ん": "n", "ゔ": "vu",
    "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
}
_YOUON = {"ゃ": "a", "ゅ": "u", "ょ": "o"}
# Small vowels after a consonant kana write a loanword sound: ティ ti, フォ fo, ウィ wi.
_SMALL_VOWEL = {"ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o"}


def _hiragana(text: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


def romaji(kana: str) -> str:
    """Hepburn romaji of a kana string, long vowels written out (ー repeats the vowel).
    Anything that is not kana passes through, so brackets and spaces survive."""
    s = _hiragana(kana)
    out: list[str] = []
    geminate = False
    i = 0
    while i < len(s):
        c, nxt = s[i], s[i + 1] if i + 1 < len(s) else ""
        if c == "っ":
            geminate = True
            i += 1
            continue
        if c == "ー":
            vowel = next((ch for ch in reversed("".join(out)) if ch in "aeiou"), "")
            out.append(vowel)
            i += 1
            continue
        syl = _BASE.get(c)
        if syl is None:
            out.append(c)
            i += 1
            continue
        step = 1
        if nxt in _YOUON and c not in "あいうえおん":
            head = syl[:-1]  # き -> k, し -> sh, ち -> ch, じ -> j
            syl = (head if head.endswith(("sh", "ch", "j")) else head + "y") + _YOUON[nxt]
            step = 2
        elif nxt in _SMALL_VOWEL and c not in "あいうえおん":
            head = {"ち": "ch", "し": "sh", "じ": "j", "つ": "ts", "ふ": "f", "て": "t",
                    "で": "d", "う": "w"}.get(c, syl[:-1])
            syl = head + _SMALL_VOWEL[nxt]
            step = 2
        if geminate:
            syl = ("t" if syl.startswith("ch") else syl[0]) + syl
            geminate = False
        out.append(syl)
        i += step
    return "".join(out)


_MACRON = str.maketrans({"ā": "aa", "ī": "ii", "ū": "uu", "ē": "ee", "ō": "oo",
                         "â": "aa", "î": "ii", "û": "uu", "ê": "ee", "ô": "oo"})


def _norm(latin: str) -> str:
    """One spelling for the variants a printed romaji uses: macrons and doubled vowels,
    おう written ou or ō, を written wo, っち written cch or tch, ん before b/p/m as m."""
    s = unicodedata.normalize("NFC", latin.lower()).translate(_MACRON)
    s = re.sub(r"[\s'’\-.~〜]", "", s)
    s = s.replace("ou", "oo").replace("wo", "o").replace("tch", "cch")
    return re.sub(r"m(?=[bpm])", "n", s)


def _split(token: str) -> tuple[str, str | None]:
    """`torimasu(shashinwo)` -> (`torimasu`, `shashinwo`); no parenthesis -> (token, None)."""
    m = re.fullmatch(r"(.*?)[(\[]([^)\]]*)[)\]]", token.strip())
    return (m.group(1), m.group(2)) if m and m.group(1) else (token, None)


def is_own_romaji(token: str, kana: str, context: str | None = None) -> bool:
    """True when `token` is the item's reading in Hepburn romaji.

    `kana` is the reading as printed (it may still carry its bracket) or the head word,
    with its bracket in `context`. Three spellings count: the whole reading
    (`(o)shōgatsu` for `(お)しょうがつ`, `jōzu(na)` for `じょうず[な]`); the head alone
    (`jisho`); and the head with the context's romaji in parentheses, where the sheet's
    kana kept only the context's particle (`sanposhimasu(kōenwo)` for `さんぽします[〜を]`).
    """
    m = BRACKET.search(kana)
    if m:
        head = BRACKET.sub("", kana).strip()
        context = m.group(1)
    else:
        head = kana
    head = head.rstrip("。")
    whole = romaji(f"({context}){head}" if context and kana.startswith(("(", "（", "[", "［"))
                   else f"{head}({context})" if context else head)
    t = _norm(re.sub(r"[()\[\]]", "", token))
    if not t or not re.fullmatch(r"[a-z]+", t):
        return False
    if t == _norm(re.sub(r"[()\[\]]", "", whole)) or t == _norm(romaji(head)):
        return True
    t_head, t_paren = _split(token)
    if t_paren is None or not context:
        return False
    tail = _norm(romaji(context))
    return _norm(t_head) == _norm(romaji(head)) and bool(tail) and _norm(t_paren).endswith(tail)


# ───────────── the pass ─────────────

def clean_item(item: dict) -> dict:
    out = dict(item)
    kana = out["kana"].translate(HYPHENS)
    parts = [re.sub(r"\s+", "", p) for p in BRACKET.findall(kana)]
    if parts:
        head = BRACKET.sub("", kana).strip()
        context = "・".join(p for p in parts if p)
        out["kana"], printed = head, kana
        if context:
            out["context"] = context
    else:
        out["kana"], printed = kana, kana
    gloss = out["gloss"]
    if "," in gloss:
        token, rest = gloss.split(",", 1)
        if rest.strip() and is_own_romaji(token, printed if parts else out["kana"],
                                           out.get("context") if not parts else None):
            out["gloss"] = rest.strip()
    if out["kana"] in GROUP_SETTLED and "groupUncertain" in out:
        out["groupUncertain"] = False  # the key stays, as on every other lesson 30 verb
    stem = Path(out["image"]).stem
    lead = {"id": stem, "kana": out["kana"],
            **({"context": out["context"]} if "context" in out else {})}
    return {**lead, **{k: v for k, v in out.items() if k not in lead}}


def clean(doc: dict) -> dict:
    lessons = [{**l, "items": [clean_item(i) for i in l["items"]]} for l in doc["lessons"]]
    ids = [i["id"] for l in lessons for i in l["items"]]
    dups = sorted({i for i in ids if ids.count(i) > 1})
    if dups:
        raise SystemExit(f"vocab_clean: two items share an image stem {dups}")
    return {**doc, "lessons": lessons}


def main(path: Path = ASSET) -> None:
    doc = json.loads(path.read_text(encoding="utf-8"))
    out = clean(doc)
    path.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"wrote {path.name}: {sum(len(l['items']) for l in out['lessons'])} words",
          "(unchanged)" if out == doc else "")


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else ASSET)
