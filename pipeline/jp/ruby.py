"""Kanji twin helpers: the `漢字{かんじ}` format and its checks (OPM Kanji Validating).

A kanji version writes each kanji word as its base, then its reading in braces. The
base is kanji only (and 々), one bracket per kanji word, with okurigana outside:
`買{か}い物{もの}`. Replacing every bracket with its reading must give the hiragana
text exactly (PIN-5, PIN-11).

`買い物{かいもの}` is rejected: the bracket's base is the kanji run 物 right before
the brace, so the okurigana い stays outside and 買 is left with no reading.
"""

from __future__ import annotations

import re

KANJI = "一-鿿々"
# One bracket: the kanji run right before `{`, then the reading.
RUBY = re.compile(rf"([{KANJI}]+)\{{([^{{}}]+)\}}")
BRACE = re.compile(r"\{[^{}]*\}")
HAS_KANJI = re.compile(rf"[{KANJI}]")


def kana_of(text: str) -> str:
    """Replace every 漢字{かな} bracket with its reading."""
    return RUBY.sub(lambda m: m.group(2), text)


def plain_of(text: str) -> str:
    """The text as printed, without furigana."""
    return BRACE.sub("", text)


def ruby_errors(ruby: str, kana: str) -> list[str]:
    """Why `ruby` is not a valid kanji version of the hiragana text `kana` (empty: valid)."""
    errs = []
    for m in BRACE.finditer(ruby):
        before = ruby[:m.start()]
        if not before or not HAS_KANJI.fullmatch(before[-1]):
            errs.append(f"bracket {m.group()} does not follow a kanji")
        elif not m.group()[1:-1]:
            errs.append(f"bracket after {before[-1]!r} has no reading")
        elif HAS_KANJI.search(m.group()[1:-1]):
            errs.append(f"reading {m.group()} holds a kanji")
    if errs:
        return errs
    reading = kana_of(ruby)
    left = HAS_KANJI.findall(reading)
    if left:
        errs.append(f"kanji with no reading: {''.join(left)!r} in {ruby!r}")
    elif reading != kana:
        errs.append(f"reading {reading!r} is not the hiragana {kana!r}")
    return errs
