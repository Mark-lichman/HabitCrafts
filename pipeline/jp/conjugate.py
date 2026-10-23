"""Deterministic verb conjugation, from the dictionary form.

Used two ways:
- Validating: a transitive pair's example sentence must contain the ます form this
  engine derives, which catches a pair printed in the wrong columns.
- Grammar Item Generating (transform drills): "たべる → potential?" needs a correct
  answer, and an LM is the wrong tool for a closed rule system.

Source 5 (Mari's Verb Forms Summary) is the gold set this engine is tested against.

Group is the hard part. A verb ending in -iru / -eru is group 2 unless it is on the
exception list, and the dictionary form alone cannot always decide (かえる is
"return", group 1, and "change", group 2). group() returns every group that fits,
and callers must resolve an ambiguous verb from evidence (an example sentence) or
mark it uncertain. Never guess.
"""

from __future__ import annotations

# Group 1 verbs that LOOK like group 2 (-iru / -eru). Homographs with a real group 2
# reading (かえる, きる, いる, へる) are in AMBIGUOUS instead, so they never resolve silently.
GODAN_IRU_ERU = {
    "はいる", "はしる", "しる", "しゃべる", "まいる", "ける", "いじる", "まじる",
    "すべる", "てる", "ねじる", "あせる", "ひねる", "かぎる", "にぎる", "せびる",
    "ちる", "みなぎる", "よみがえる",
}
AMBIGUOUS = {"かえる", "きる", "いる", "へる", "える"}

I_ROW = set("いきしちにひみりぎじぢびぴ")
E_ROW = set("えけせてねへめれげぜでべぺ")

# u-column ending -> (a, i, e, o) columns for group 1.
ROWS = {
    "う": "わいえお", "く": "かきけこ", "ぐ": "がぎげご", "す": "さしせそ",
    "つ": "たちてと", "ぬ": "なにねの", "ぶ": "ばびべぼ", "む": "まみめも",
    "る": "らりれろ",
}
TE = {"う": "って", "つ": "って", "る": "って", "む": "んで", "ぶ": "んで", "ぬ": "んで",
      "く": "いて", "ぐ": "いで", "す": "して"}


def group(dic: str) -> set[int]:
    """Every group the dictionary form allows. One member means it is decided."""
    if dic.endswith("する") or dic == "くる" or dic.endswith("てくる"):
        return {3}
    if not dic.endswith("る"):
        return {1}
    if dic in AMBIGUOUS:
        return {1, 2}
    if dic in GODAN_IRU_ERU:
        return {1}
    if len(dic) >= 2 and (dic[-2] in I_ROW or dic[-2] in E_ROW):
        return {2}
    return {1}


def conjugate(dic: str, g: int) -> dict[str, str]:
    """All forms in Mari's summary, for one verb in one group."""
    if g == 3:
        if dic.endswith("くる"):
            p = dic[:-2]
            return {
                "masu": p + "きます", "te": p + "きて", "ta": p + "きた", "nai": p + "こない",
                "potential": p + "こられる", "volitional": p + "こよう",
                "conditional": p + "くれば", "imperative": p + "こい",
                "prohibitive": p + "くるな", "passive": p + "こられる",
                "causative": p + "こさせる", "causative_passive": p + "こさせられる",
            }
        p = dic[:-2]
        return {
            "masu": p + "します", "te": p + "して", "ta": p + "した", "nai": p + "しない",
            "potential": p + "できる", "volitional": p + "しよう",
            "conditional": p + "すれば", "imperative": p + "しろ",
            "prohibitive": p + "するな", "passive": p + "される",
            "causative": p + "させる", "causative_passive": p + "させられる",
        }
    if g == 2:
        s = dic[:-1]
        return {
            "masu": s + "ます", "te": s + "て", "ta": s + "た", "nai": s + "ない",
            "potential": s + "られる", "volitional": s + "よう", "conditional": s + "れば",
            "imperative": s + "ろ", "prohibitive": dic + "な", "passive": s + "られる",
            "causative": s + "させる", "causative_passive": s + "させられる",
        }
    stem, end = dic[:-1], dic[-1]
    a, i, e, o = ROWS[end]
    te = "って" if dic.endswith("いく") else TE[end]  # いく is the one te-form exception
    # す verbs take the long causative passive (はなさせられる); the rest contract.
    cp = stem + a + ("せられる" if end == "す" else "される")
    return {
        "masu": stem + i + "ます", "te": stem + te, "ta": stem + te[:-1] + ("だ" if te[-1] == "で" else "た"),
        "nai": "ない" if dic == "ある" else stem + a + "ない", "potential": stem + e + "る", "volitional": stem + o + "う",
        "conditional": stem + e + "ば", "imperative": stem + e, "prohibitive": dic + "な",
        "passive": stem + a + "れる", "causative": stem + a + "せる", "causative_passive": cp,
    }


def masu_candidates(dic: str) -> dict[int, str]:
    return {g: conjugate(dic, g)["masu"] for g in sorted(group(dic))}
