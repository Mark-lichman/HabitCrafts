"""The vocabulary clean-up pass (vocab_clean.py), checked against the shipped asset.

assets/lessons/jp_lessons.json is the output of an extractor that is not committed, cleaned
by pipeline/jp/vocab_clean.py. These tests read the shipped file: no reading holds a
hyphen or a bracket, no gloss leads with the printed romaji of its own reading, every
English first meaning survives, every word has its image-stem id, duplicate cards stay
separate (PIN-16), and the pass is a no-op on its own output.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

JP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(JP))

import pytest  # noqa: E402

from vocab_clean import clean, clean_item, is_own_romaji, romaji  # noqa: E402

ASSET = JP.parents[1] / "assets" / "lessons" / "jp_lessons.json"
HYPHEN_OR_BRACKET = re.compile(r"[-－‐\[\]［］()（）]")

# Snapshot of 2026-11-02, taken from the asset before the first clean-up (at 8457ec2):
# every gloss whose first comma-separated token is Latin letters only (the broad pattern:
# Latin letters, macrons, brackets and spaces, then a comma), keyed by word id and
# classified by hand. ROMAJI tokens are the sheet's printed romaji of the reading: they
# must be gone. ENGLISH tokens are first meanings: they must still lead the gloss.
ROMAJI = {
    "L02_01": "jisho", "L02_05": "techō", "L02_10": "shāpupenshiru", "L02_20": "chokorēto",
    "L03_01": "shokudō", "L03_12": "kaisha", "L04_09": "toshokan", "L04_10": "bijutsukan",
    "L05_08": "densha", "L05_16": "kanojo", "L05_19": "tanjōbi",
    "L06_08": "torimasu(shashinwo)", "L06_24": "ocha", "L06_25": "kōcha", "L06_27": "jūsu",
    "L06_33": "shashin", "L06_36": "shukudai", "L07_22": "shatsu", "L09_04": "jōzu(na)",
    "L09_16": "goshujin", "L09_17": "shujin", "L13_09": "shokujishimasu",
    "L13_10": "sanposhimasu(kōenwo)", "L13_18": "bijutsu", "L14_15": "oshiemasu(jūshowo)",
    "L15_12": "haisha", "L16_03": "abimasu(shawāwo)", "L16_26": "jogingu",
    "L16_28": "jinja", "L17_03": "dashimasu(repōtowo)", "L17_12": "shucchōshimasu",
    "L17_16": "daijōbu(na)", "L22_00": "kimasu(shatsuwo)", "L23_05": "demasu(jūsuga)",
    "L23_09": "kiwotsukemasu", "L23_15": "koshō", "L23_21": "chūshajō",
    "L23_22": "(o)shōgatsu", "L24_04": "shōkaishimasu", "L24_07": "iremasu(kōhīwo)",
    "L24_08": "ojīchan", "L24_10": "obāchan", "L26_04": "okuremasu(jikanni)",
    "L26_05": "maniaimasu(jikanni)", "L26_06": "sankashimasu(pāthīni)", "L26_12": "jūdō",
    "L26_14": "basho", "L27_18": "manshon", "L28_12": "chōdoī", "L28_13": "shūkan",
    "L28_24": "shōsetsu", "L28_25": "shōsetsuka", "L28_26": "kashu",
    "L28_31": "oshaberishimasu", "L29_11": "tsukimasu(poketto ga)",
    "L29_12": "hazuremasu(botan ga)", "L29_13": "tomarimasu(kuruma ga)",
    "L29_18": "ochawan", "L30_13": "yoshūshimasu", "L30_14": "fukushūshimasu",
    "L30_16": "jugyō",
}
ENGLISH = {
    "L02_12": "watch", "L02_14": "bag", "L03_13": "house", "L04_03": "take a rest",
    "L04_12": "daytime", "L05_15": "he", "L05_18": "alone", "L06_03": "see",
    "L06_04": "hear", "L06_06": "write", "L06_09": "meet", "L06_10": "a meal",
    "L06_34": "store", "L07_00": "cut", "L07_09": "hand", "L07_21": "flower",
    "L07_23": "present", "L07_24": "baggage", "L07_30": "trip", "L07_31": "souvenir",
    "L08_01": "beautiful", "L08_06": "healthy", "L08_09": "nice", "L08_10": "big",
    "L08_11": "small", "L08_24": "tall", "L08_27": "delicious", "L08_39": "work",
    "L09_06": "cooking", "L09_13": "picture", "L10_00": "exist", "L10_01": "exist",
    "L10_09": "tree", "L10_23": "place to catch taxi", "L10_24": "on", "L10_25": "under",
    "L10_26": "front", "L10_27": "back", "L10_30": "in", "L12_07": "many", "L12_08": "few",
    "L12_18": "autumn", "L12_26": "sea", "L12_31": "maple", "L13_00": "play",
    "L13_02": "go to meet", "L13_14": "wide", "L14_03": "close", "L14_10": "take",
    "L14_13": "speak", "L14_16": "start", "L15_04": "make", "L15_08": "materials",
    "L15_14": "remember", "L16_00": "ride", "L16_04": "put in", "L16_05": "take out",
    "L16_09": "push", "L16_24": "stomach", "L16_25": "foot", "L17_15": "important",
    "L17_18": "question", "L17_21": "cold", "L17_23": "illness", "L22_08": "hat",
    "L23_06": "[a car] move", "L23_16": "road", "L24_12": "sweets", "L25_00": "think",
    "L25_04": "countryside", "L26_07": "apply for", "L26_17": "garbage",
    "L27_00": "keep (a pet)", "L27_02": "run", "L27_06": "[an airport] be made",
    "L27_12": "scenery", "L27_17": "cleaning", "L27_22": "marvelous", "L28_10": "gentle",
    "L28_14": "form", "L29_01": "[a door] close", "L29_03": "[a light] go off",
    "L29_07": "[a glass] break", "L29_08": "[a tree] break", "L29_15": "drop",
    "L29_17": "plate", "L29_25": "things left behind", "L30_00": "post",
    "L30_02": "display", "L30_03": "arrange", "L30_05": "return",
    "L30_08": "put things in order", "L30_12": "consult", "L30_19": "plan",
    "L30_31": "round",
}


def _words() -> list[dict]:
    doc = json.loads(ASSET.read_text(encoding="utf-8"))
    return [w for l in doc["lessons"] for w in l["items"]]


@pytest.fixture(scope="module")
def words() -> dict[str, dict]:
    return {w.get("id", w["image"]): w for w in _words()}


def _first(gloss: str) -> str:
    return gloss.split(",")[0].strip()


def test_no_reading_holds_a_hyphen_or_a_bracket(words):
    bad = [(i, w["kana"]) for i, w in words.items() if HYPHEN_OR_BRACKET.search(w["kana"])]
    assert bad == []
    bad = [(i, w["context"]) for i, w in words.items()
           if "context" in w and (not w["context"] or HYPHEN_OR_BRACKET.search(w["context"]))]
    assert bad == []


@pytest.mark.parametrize("wid, kana, context", [
    ("L02_16", "コンピューター", None),       # was コンピュ-タ-
    ("L06_02", "すいます", "たばこを"),         # was すいます[たばこを]
    ("L23_04", "さわります", "に"),             # only a bracketed particle: the verb stays
    ("L06_29", "さけ", "お"),                   # was (お)さけ
    ("L08_14", "いい", "よい"),                 # was いい (よい)
    ("L14_17", "ふります", "あめが"),           # was ふります[あめ が]
    ("L22_10", "おめでとう。", "ございます"),   # was おめでとう(ございます)。
])
def test_the_head_word_keeps_the_reading_and_the_rest_is_context(words, wid, kana, context):
    assert words[wid]["kana"] == kana
    assert words[wid].get("context") == context


def test_the_printed_romaji_is_gone(words):
    assert len(ROMAJI) + len(ENGLISH) == 156  # the broad pattern's matches in the snapshot
    left = [(i, words[i]["gloss"]) for i, tok in ROMAJI.items() if _first(words[i]["gloss"]) == tok]
    assert left == [], "a printed romaji still leads its gloss"


def test_every_english_first_meaning_the_broad_pattern_matched_is_still_first(words):
    lost = [(i, tok, words[i]["gloss"]) for i, tok in ENGLISH.items()
            if _first(words[i]["gloss"]) != tok]
    assert lost == [], "an English first meaning was stripped as romaji"


def test_no_gloss_begins_with_the_romaji_of_its_own_reading(words):
    bad = [(i, w["gloss"]) for i, w in words.items() if "," in w["gloss"]
           and is_own_romaji(w["gloss"].split(",")[0], w["kana"], w.get("context"))]
    assert bad == []


@pytest.mark.parametrize("token, kana, context", [
    ("jisho", "じしょ", None),
    ("techō", "てちょう", None),
    ("chokorēto", "チョコレート", None),
    ("shucchōshimasu", "しゅっちょうします", None),
    ("chōdoī", "ちょうどいい", None),
    ("kiwotsukemasu", "きをつけます", None),
    ("torimasu(shashinwo)", "とります[しゃしんを]", None),
    ("sanposhimasu(kōenwo)", "さんぽします[〜を]", None),
    ("tsukimasu(poketto ga)", "つきます", "〜が"),
    ("(o)shōgatsu", "(お)しょうがつ", None),
    ("jōzu(na)", "じょうず", "な"),
])
def test_romaji_of_the_reading_is_recognised(token, kana, context):
    assert is_own_romaji(token, kana, context)


@pytest.mark.parametrize("token, kana, context", [
    ("watch", "とけい", None),
    ("work", "しごと", "お"),
    ("tall", "たかい", None),
    ("present", "プレゼント", None),
    ("sanposhimasu(kōenwo)", "あるきます", "〜を"),     # another verb's romaji
    ("torimasu(shashinga)", "とります", "しゃしんを"),  # the context's particle differs
])
def test_english_and_other_words_are_not_romaji(token, kana, context):
    assert not is_own_romaji(token, kana, context)


def test_romaji_spells_long_vowels_and_double_consonants():
    assert romaji("コーヒー") == "koohii"
    assert romaji("きって") == "kitte"
    assert romaji("しゅっちょう") == "shutchou"
    assert romaji("パーティー") == "paatii"


def test_every_word_has_its_image_stem_as_id(words):
    all_words = _words()
    assert len(words) == len(all_words), "two words share an id"
    for w in all_words:
        assert w.get("id") == Path(w["image"]).stem, w["image"]
        assert re.fullmatch(r"L\d\d_\d\d", w["id"]), w["id"]


def test_identical_duplicate_cards_stay_separate(words):
    # PIN-16: an identical duplicate in one lesson keeps its own id and picture.
    for a, b in (("L08_16", "L08_18"), ("L26_00", "L26_01")):
        assert (words[a]["kana"], words[a]["gloss"]) == (words[b]["kana"], words[b]["gloss"])
        assert words[a]["image"] != words[b]["image"]


def test_fukushuu_is_no_longer_group_uncertain(words):
    w = next(w for w in words.values() if w["kana"] == "ふくしゅうします")
    assert w["verbGroup"] == 3 and not w.get("groupUncertain")


def test_the_pass_is_a_no_op_on_its_own_output():
    text = ASSET.read_text(encoding="utf-8").replace("\r\n", "\n")
    doc = json.loads(text)
    assert clean(doc) == doc
    assert json.dumps(clean(doc), ensure_ascii=False, indent=1) == text.rstrip("\n")


def test_the_pass_cleans_a_raw_item_once():
    raw = {"kana": "とります[しゃしんを]", "gloss": "torimasu(shashinwo), take (a photo)",
           "image": "assets/lessons/img/L06_08.webp"}
    once = clean_item(raw)
    assert once == {"id": "L06_08", "kana": "とります", "context": "しゃしんを",
                    "gloss": "take (a photo)", "image": raw["image"]}
    assert clean_item(once) == once
    hyphen = clean_item({"kana": "サッカ-", "gloss": "soccer", "image": "x/L06_37.webp"})
    assert hyphen["kana"] == "サッカー" and "context" not in hyphen


def test_a_repeated_id_fails_the_pass():
    doc = {"lessons": [{"lesson": 2, "items": [
        {"kana": "ほん", "gloss": "book", "image": "a/L02_00.webp"},
        {"kana": "ほん", "gloss": "book", "image": "b/L02_00.webp"}]}]}
    with pytest.raises(SystemExit):
        clean(doc)
