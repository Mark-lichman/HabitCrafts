"""Pipeline evals that run in CI, on committed fixtures.

The extractors need the source PDFs and Mari's exported sheet, which live outside the
repo, so CI cannot re-run them. Their outputs are committed as fixtures
(pipeline/jp/fixtures/<source>/lesson_bundle.json), and everything downstream of
extraction is tested here: the conjugation engine against the tutor's gold, the draft
validator, the catalog, publishing with corrections, and drift between the committed
app file and a fresh publish.

Refresh fixtures after re-running an extractor (refuses a missing or blocked bundle):
    pipeline/.venv/Scripts/python pipeline/jp/refresh_fixtures.py
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

JP = Path(__file__).resolve().parents[1]
os.environ["JP_OUT_DIR"] = str(JP / "fixtures")
sys.path.insert(0, str(JP))
sys.path.insert(0, str(JP.parent))

import pytest  # noqa: E402

from catalog import TYPES, build as build_catalog  # noqa: E402
from conjugate import MARI_DRILLS, conjugate, group  # noqa: E402

FIX = JP / "fixtures"
ASSETS = JP.parents[1] / "assets" / "lessons"


def bundle(source: str) -> dict:
    return json.loads((FIX / source / "lesson_bundle.json").read_text(encoding="utf-8"))


# ───────────── conjugation engine vs the tutor ─────────────

PAST_TO_DIC = {"いった": "いく", "かった": "かう", "あった": "ある", "おきた": "おきる",
               "した": "する", "きた": "くる"}


def mari_rows() -> list[dict]:
    return [i for i in bundle("s05_mari_verb_forms")["items"]
            if not i["section"].startswith("long_short")]


@pytest.mark.parametrize("row", mari_rows(), ids=lambda r: f"{r['dictionary']}-{r['section']}")
def test_engine_matches_every_mari_conjugation(row):
    assert conjugate(row["dictionary"], row["group"])[row["section"]] == row["result"]


def long_short_rows() -> list[dict]:
    return [i for i in bundle("s05_mari_verb_forms")["items"]
            if i["section"].startswith("long_short") and isinstance(i["group"], int)]


@pytest.mark.parametrize("row", long_short_rows(), ids=lambda r: f"{r['short_affirmative']}-{r['section']}")
def test_engine_matches_mari_long_and_short_forms(row):
    past = row["section"].endswith("past")
    dic = PAST_TO_DIC[row["short_affirmative"]] if past else row["short_affirmative"]
    c = conjugate(dic, row["group"])
    stem = c["masu"][:-2]
    assert row["long_affirmative"] == stem + ("ました" if past else "ます")
    assert row["long_negative"] == stem + ("ませんでした" if past else "ません")
    assert row["short_affirmative"] == (c["ta"] if past else dic)
    assert row["short_negative"] == c["nai"][:-1] + ("かった" if past else "い")


def test_gold_set_is_complete():
    # 150 single-form cells + 12 verb rows of 4 long/short forms = 198 conjugations.
    # A smaller number means a fixture lost rows, and the engine tests above would
    # pass on less evidence.
    assert len(mari_rows()) == 150
    assert len(long_short_rows()) == 12


@pytest.mark.parametrize("pattern", list(MARI_DRILLS))
def test_engine_reproduces_mari_checklist_examples(pattern):
    point = next(p for p in bundle("s04_mari_checklist")["items"] if p["pattern"] == pattern)
    given = [s.strip().rstrip("！") for s in point["example"].split("／")]
    assert given == [conjugate(v, group(v).pop())[f] for v, f in MARI_DRILLS[pattern]]


def test_group_agrees_with_lesson_30_hand_labels():
    lessons = json.loads((ASSETS / "jp_lessons.json").read_text(encoding="utf-8"))["lessons"]
    verbs = [i for l in lessons for i in l["items"] if "verbGroup" in i]
    assert verbs
    for v in verbs:
        assert v["verbGroup"] in group(v["dictionary"]), v["dictionary"]
        assert conjugate(v["dictionary"], v["verbGroup"])["masu"] == v["kana"]
        assert conjugate(v["dictionary"], v["verbGroup"])["te"] == v["teForm"]


def test_ambiguous_verbs_never_resolve_silently():
    assert group("かえる") == {1, 2}
    assert group("はいる") == {1}
    assert group("でる") == {2}


# ───────────── catalog ─────────────

def test_catalog_types_and_uses():
    cat = build_catalog()
    known_uses = {u["id"] for u in cat["uses"]}
    by_type = {}
    for e in cat["entries"]:
        assert e["type"] in TYPES
        assert set(e["uses"]) <= known_uses, e["id"]
        if e["type"] == "source_file":
            continue  # data files carry no uses; test_catalog_sources.py covers them
        if e["type"] != "vocabulary":
            assert e["uses"], f"{e['id']} has no uses, so sort by use never finds it"
        by_type[e["type"]] = by_type.get(e["type"], 0) + 1
    assert by_type == {"grammar_point": 89, "particle": 15, "reference_table": 4,
                       "verb_pair": 35, "conjugation": 12, "vocabulary": 25}


# ───────────── publishing ─────────────

@pytest.fixture(scope="module")
def published(tmp_path_factory):
    import publish
    out = tmp_path_factory.mktemp("pub") / "jp_grammar.json"
    doc, skipped = publish.run(out)
    return doc, skipped, out


def test_no_draft_is_skipped(published):
    _, skipped, _ = published
    assert skipped == []


def test_every_lesson_is_drafted_with_four_items(published):
    doc, _, _ = published
    assert [g["lesson"] for g in doc["grammar"]] == list(range(26, 51))
    for g in doc["grammar"]:
        assert g["status"] == "draft"
        for p in g["points"]:
            assert len(p["practice"]) >= 4, p["id"]


def test_reviewed_corrections_are_applied(published):
    doc, _, _ = published
    ex = next(p for g in doc["grammar"] for p in g["points"] if p["id"] == "mari.L42.3")
    assert "みっかも" in ex["example"] and "3にち" not in ex["example"]
    months = next(t for t in doc["reference"] if t["id"] == "months")
    cell = next(c for c in months["cells"] if c["row"] == "11" and c["col"] == "〜か月")
    assert cell["mark"] == "sound_change"
    assert any(v["dictionary"] == "かえる" and v["group"] == 2
               for v in doc["conjugation"]["verbs"])


def test_committed_app_file_matches_a_fresh_publish(published):
    # The app ships assets/lessons/jp_grammar.json. If a draft, a correction or the
    # catalog changed without re-running publish.py, the phone gets stale content.
    _, _, out = published
    fresh = json.loads(out.read_text(encoding="utf-8"))
    committed = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    assert committed == fresh, "run: python pipeline/jp/publish.py, then commit the asset"


# ───────────── mastery data (plan Task 4) ─────────────

KANJI = re.compile(r"[一-鿿々]")


def hiragana_strings(doc: dict):
    """Every string the app shows in hiragana mode, with a readable place. The `_ruby`
    twins are the kanji mode, the reference tables print a counter's written form, and a
    textbook pair's `kanji_*` sentences are its kanji mode, so none of those is here."""
    for g in doc["grammar"]:
        for p in g["points"]:
            yield f"{p['id']} example", p["example"]
            for i, e in enumerate(p.get("examples", [])):
                yield f"{p['id']} ex{i}", e["jp"]
            for i, q in enumerate(p.get("practice", [])):
                for s in [q.get("prompt", ""), q.get("answer", ""), *q.get("accepted", []),
                          *q.get("options", []), *q.get("why_wrong", {})]:
                    yield f"{p['id']} p{i}", s
    for pa in doc["particles"]:
        c = pa["cloze"]
        for s in [pa["expression"], pa["example"], c["prompt"], c["answer"], *c["accepted"]]:
            yield pa["id"], s
        for i, x in enumerate(pa.get("sentences", [])):
            for s in [x["prompt"], x["answer"], *x["accepted"]]:
                yield f"{pa['id']} sentence {i}", s
    for i, pr in enumerate(doc["pairs"]):
        yield f"pair {i}", pr["ex_transitive"]
        yield f"pair {i}", pr["ex_intransitive"]
    for e in doc["catalog"]:
        if e["type"] in ("grammar_point", "particle"):
            for s in e["search"]:
                yield f"catalog {e['id']}", s


def test_no_hiragana_mode_string_holds_a_kanji():
    doc = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    bad = [(where, s) for where, s in hiragana_strings(doc) if KANJI.search(s)]
    assert bad == [], f"kanji in hiragana mode: {bad}"
    sign = next(p for g in doc["grammar"] for p in g["points"] if p["id"] == "mari.L33.3")
    assert sign["example"].startswith("「たちいりきんし」")


def test_every_particle_has_a_cloze_probe():
    doc = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    s04 = bundle("s04_mari_checklist")
    assert [pa["id"] for pa in doc["particles"]] == [pa["id"] for pa in s04["particles"]]
    for pa in doc["particles"]:
        c = pa["cloze"]
        assert c["prompt"].count("＿＿") == 1, pa["id"]
        assert c["answer"] and c["answer"] not in c["prompt"], pa["id"]
        # Filled in, the cloze gives back the particle's own example.
        assert any(c["prompt"].replace("＿＿", a) == pa["example"]
                   for a in [c["answer"], *c["accepted"]]), pa["id"]
        verbatim = pa["expression"] in pa["example"]
        assert c["from"] == ("example" if verbatim else "particle_clozes.json"), pa["id"]


def _hand_clozes(tmp_path, monkeypatch, edit) -> None:
    """Point publish.CLOZES at a copy of particle_clozes.json after `edit` changed it."""
    import publish
    doc = json.loads(publish.CLOZES.read_text(encoding="utf-8"))
    edit(doc["clozes"])
    path = tmp_path / "particle_clozes.json"
    path.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(publish, "CLOZES", path)


def test_a_particle_with_no_cloze_fails_the_publish(tmp_path, monkeypatch):
    import copy
    import publish
    s04 = copy.deepcopy(bundle("s04_mari_checklist"))
    hand = next(pa for pa in s04["particles"] if pa["expression"] not in pa["example"])
    hand["id"] = "mari.particle.99"
    with pytest.raises(SystemExit, match="no such particle"):
        publish.particle_clozes(s04)
    s04 = copy.deepcopy(bundle("s04_mari_checklist"))
    hand = next(pa for pa in s04["particles"] if pa["expression"] not in pa["example"])
    hand["example"] = hand["expression"] + "です。"  # now blankable: the hand cloze is stale
    with pytest.raises(SystemExit, match="stale"):
        publish.particle_clozes(s04)
    # The guard A15 rests on: a hand-cloze particle whose cloze is missing from the file.
    _hand_clozes(tmp_path, monkeypatch, lambda clozes: clozes.pop("mari.particle.13"))
    with pytest.raises(SystemExit, match="has no cloze for it"):
        publish.particle_clozes(bundle("s04_mari_checklist"))


def test_a_hand_cloze_that_does_not_fill_back_to_its_example_fails(tmp_path, monkeypatch):
    import publish
    _hand_clozes(tmp_path, monkeypatch,
                 lambda clozes: clozes["mari.particle.13"].update(prompt="やすい＿＿、かいます。"))
    with pytest.raises(SystemExit, match="filled in is not its example"):
        publish.particle_clozes(bundle("s04_mari_checklist"))


def test_a_cloze_that_shows_its_answer_fails():
    import copy
    import publish
    s04 = copy.deepcopy(bundle("s04_mari_checklist"))
    pa = next(pa for pa in s04["particles"] if pa["expression"] == "でも")
    pa["example"] = "でもでも わかります。"  # blanking the first leaves the second in view
    with pytest.raises(SystemExit, match="one blank and must not show its answer"):
        publish.particle_clozes(s04)


def test_a_cloze_that_is_not_kana_fails():
    import copy
    import publish
    s04 = copy.deepcopy(bundle("s04_mari_checklist"))
    pa = next(pa for pa in s04["particles"] if pa["expression"] == "として")
    pa["expression"], pa["example"] = "通訳として", "通訳として はたらいて います。"
    with pytest.raises(SystemExit, match="cloze not kana"):
        publish.particle_clozes(s04)


def test_an_unknown_required_form_fails_the_publish():
    import publish
    with pytest.raises(SystemExit, match="maps to no conjugation idea"):
        publish.prereqs({"id": "x", "requires_forms": ["bogus"]})


def test_catalog_search_terms_are_the_corrected_text():
    # catalog.build() without bundles applies the s04 corrections itself, so a search
    # term is the text the app shows: the printed sign of mari.L33.3 reads in hiragana.
    entry = next(e for e in build_catalog()["entries"]
                 if e["type"] == "grammar_point" and e["id"] == "mari.L33.3")
    assert entry["search"][0].startswith("「たちいりきんし」")
    assert not any(KANJI.search(s) for s in entry["search"]), entry["search"]


def test_every_point_carries_its_form_prereqs():
    import publish
    doc = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    conj = {e["id"] for e in doc["catalog"] if e["type"] == "conjugation"}
    forms = {p["id"]: p.get("requires_forms") or [] for p in bundle("s04_mari_checklist")["items"]}
    points = [p for g in doc["grammar"] for p in g["points"]]
    assert len(points) == len(forms)
    for p in points:
        assert set(p["prereqs"]) <= conj, p["id"]
        want = [x for f in forms[p["id"]] for x in publish.FORM_PREREQS[f]]
        assert p["prereqs"] == list(dict.fromkeys(want)), p["id"]
    by_id = {p["id"]: p["prereqs"] for p in points}
    te = next(i for i, f in forms.items() if f == ["te"])
    assert by_id[te] == ["conj.te"]
    plain = next(i for i, f in forms.items() if f == ["plain"])
    assert by_id[plain] == ["conj.nai", "conj.ta"]


def test_published_words_are_one_per_word_of_the_vocabulary():
    doc = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    vocab = json.loads((ASSETS / "jp_lessons.json").read_text(encoding="utf-8"))
    want = [(w["id"], w["kana"], w["gloss"], l["lesson"], w.get("verbGroup"))
            for l in vocab["lessons"] for w in l["items"]]
    got = [(w["id"], w["reading"], w["gloss"], w["lesson"], w["verbGroup"]) for w in doc["words"]]
    assert got == want


# ───────────── OPM schema ─────────────

def test_opm_stage_graph_composes():
    import extraction_schemas
    extraction_schemas._check()


def test_every_particle_has_its_english():
    doc = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    for p in doc["particles"]:
        assert p["example_en"].strip(), p["id"]
        assert p["example_en_reviewed"] is False, "flip only after Mark reviews the English"


def test_a_particle_with_no_english_fails_the_publish(tmp_path, monkeypatch):
    import publish
    doc = json.loads(publish.PARTICLE_EN.read_text(encoding="utf-8"))
    doc["english"].pop("mari.particle.1")
    f = tmp_path / "particle_english.json"
    f.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(publish, "PARTICLE_EN", f)
    with pytest.raises(SystemExit, match="no English for"):
        publish.run(tmp_path / "jp_grammar.json")


# ───────────── particle sentences (plan Task 8, PIN-4) ─────────────

def _particle_sentences(tmp_path, monkeypatch, edit) -> None:
    """Point publish.PARTICLE_SENTENCES at a copy of the committed particle_sentences.json
    after `edit` changed its `sentences` map. Each call starts from the committed file, so
    one test's edits never stack."""
    import publish
    doc = json.loads((JP / "particle_sentences.json").read_text(encoding="utf-8"))
    edit(doc["sentences"])
    path = tmp_path / "particle_sentences.json"
    path.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(publish, "PARTICLE_SENTENCES", path)


def test_every_particle_has_three_particle_sentences():
    # End state 7: the lesson example's cloze first, then the two drafted sentences.
    doc = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    src = json.loads((JP / "particle_sentences.json").read_text(encoding="utf-8"))
    prompts = []
    for pa in doc["particles"]:
        ss = pa["sentences"]
        assert len(ss) == 3, pa["id"]
        first = ss[0]
        assert {k: first[k] for k in ("prompt", "answer", "accepted", "from")} == pa["cloze"]
        assert first["english"] == pa["example_en"], pa["id"]
        assert [s["from"] for s in ss[1:]] == ["particle_sentences.json"] * 2, pa["id"]
        assert [{k: s[k] for k in ("prompt", "answer", "accepted", "english")}
                for s in ss[1:]] == src["sentences"][pa["id"]], pa["id"]
        for s in ss:
            assert s["prompt"].count("＿＿") == 1 and s["answer"] == pa["cloze"]["answer"]
            assert s["english"].strip(), pa["id"]
            assert not KANJI.search(s["prompt"] + s["answer"] + "".join(s["accepted"]))
        prompts += [s["prompt"] for s in ss]
    assert len(prompts) == len(set(prompts)), "two particle sentences share a prompt"


def test_particle_sentences_are_marked_unreviewed():
    # PIN-4: each sentence carries the review flag of the file its English came from,
    # and the drafted ones ship unreviewed.
    doc = json.loads((ASSETS / "jp_grammar.json").read_text(encoding="utf-8"))
    en = json.loads((JP / "particle_english.json").read_text(encoding="utf-8"))
    for pa in doc["particles"]:
        first, *drafted = pa["sentences"]
        assert first["reviewed"] is bool(en.get("reviewed")), pa["id"]
        for s in drafted:
            assert s["reviewed"] is False, "flip only after Mark reviews the sentences"


def test_particle_sentences_with_no_review_flag_publish_unreviewed(tmp_path, monkeypatch):
    import publish
    doc = json.loads(publish.PARTICLE_SENTENCES.read_text(encoding="utf-8"))
    doc.pop("reviewed", None)
    path = tmp_path / "particle_sentences.json"
    path.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(publish, "PARTICLE_SENTENCES", path)
    out = publish.particles(bundle("s04_mari_checklist"))
    assert all(s["reviewed"] is False for p in out for s in p["sentences"][1:])


def test_stale_particle_sentences_fail_the_publish(tmp_path, monkeypatch):
    import publish
    s04 = bundle("s04_mari_checklist")
    _particle_sentences(tmp_path, monkeypatch,
                        lambda ss: ss.update({"mari.particle.99": ss["mari.particle.2"]}))
    with pytest.raises(SystemExit, match="no such particle"):
        publish.particles(s04)
    _particle_sentences(tmp_path, monkeypatch, lambda ss: ss.pop("mari.particle.2"))
    with pytest.raises(SystemExit, match="needs 2 sentences"):
        publish.particles(s04)
    _particle_sentences(tmp_path, monkeypatch, lambda ss: ss["mari.particle.2"].pop())
    with pytest.raises(SystemExit, match="needs 2 sentences"):
        publish.particles(s04)
    # A sentence written for another answer than the particle's cloze is stale.
    _particle_sentences(tmp_path, monkeypatch,
                        lambda ss: ss["mari.particle.2"][0].update(answer="について"))
    with pytest.raises(SystemExit, match="stale"):
        publish.particles(s04)
    # A sentence that drops a spelling the particle's cloze accepts is stale too.
    _particle_sentences(tmp_path, monkeypatch,
                        lambda ss: ss["mari.particle.13"][0].update(accepted=[]))
    with pytest.raises(SystemExit, match="stale"):
        publish.particles(s04)
    # A drafted sentence that repeats the lesson example adds no variety.
    ex = next(c for p, c in zip(s04["particles"], publish.particle_clozes(s04))
              if p["id"] == "mari.particle.2")
    _particle_sentences(tmp_path, monkeypatch,
                        lambda ss: ss["mari.particle.2"][0].update(prompt=ex["prompt"]))
    with pytest.raises(SystemExit, match="repeats"):
        publish.particles(s04)


def test_leaking_particle_sentences_fail_the_publish(tmp_path, monkeypatch):
    import publish
    s04 = bundle("s04_mari_checklist")
    for edit in ({"prompt": "つうやくとして ＿＿ はたらいて います。"},  # shows its answer
                 {"prompt": "つうやく はたらいて います。"},           # no blank
                 {"prompt": "つうやく＿＿ ＿＿ はたらいて います。"}):  # two blanks
        _particle_sentences(tmp_path, monkeypatch,
                            lambda ss, e=edit: ss["mari.particle.2"][0].update(e))
        with pytest.raises(SystemExit, match="one blank and must not show its answer"):
            publish.particles(s04)
    _particle_sentences(tmp_path, monkeypatch,
                        lambda ss: ss["mari.particle.1"][0].update(
                            prompt="この ほんは に よって＿＿ かかれました。"))
    with pytest.raises(SystemExit, match="one blank and must not show its answer"):
        publish.particles(s04)


def test_particle_sentences_that_are_not_kana_or_lack_english_fail(tmp_path, monkeypatch):
    import publish
    s04 = bundle("s04_mari_checklist")
    _particle_sentences(tmp_path, monkeypatch,
                        lambda ss: ss["mari.particle.2"][0].update(prompt="通訳＿＿ はたらいて います。"))
    with pytest.raises(SystemExit, match="not kana"):
        publish.particles(s04)
    _particle_sentences(tmp_path, monkeypatch,
                        lambda ss: ss["mari.particle.2"][0].update(english=" "))
    with pytest.raises(SystemExit, match="no English"):
        publish.particles(s04)


def test_particle_sentences_carry_their_judge_pass():
    # Plan Task 8: the drafts were checked by an independent judge pass, recorded in the
    # file. Its last round read every sentence and left no finding open.
    src = json.loads((JP / "particle_sentences.json").read_text(encoding="utf-8"))
    judge = src["judge"]
    assert judge["judge"] == "independent-lm"
    total = sum(len(v) for v in src["sentences"].values())
    last = judge["rounds"][-1]
    assert last["checked"] == total and last["findings"] == []
    for r in judge["rounds"]:
        for f in r["findings"]:
            assert f["particle"] in src["sentences"] and f["applied"], f
