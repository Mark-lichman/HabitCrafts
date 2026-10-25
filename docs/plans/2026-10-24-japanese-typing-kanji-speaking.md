# Japanese study: typed answers, a kanji option, and speaking practice

**Evidence consumed** — one row per linked artifact:
- PR #66 (`feat/quiet-room-japanese-lessons`, CI green at `a7fa376`) · read
- `lib/components/pages/quiet_room_practice/speech_service.dart` `judge()` / `listenOnce()` at `a7fa376` · read
- red-team run 2026-10-24 (11 probes, report in `docs/red-team/`) · read
- `pipeline/jp/s03_pairs_textbook.py` `kana_of()` / `plain_of()` at `a7fa376` · read
- Flutter SDK `text_field.dart` `hintLocales` (local SDK, `C:/src/flutter`) · read
- `pipeline/jp/review/judge_*.json` (judge pass over 356 items: 11 findings, none a wrong answer key, all applied) · read
- `docs/plans/2026-10-23-japanese-grammar-sources.md` (superseded by this plan) · read
- WAR run history (`.claude/war/runs/`, `docs/learnings/`) · unread: neither exists in this repo

## Context — the gap / problem

The grammar lessons (Mari's lessons 26 to 50) ship in the phone app with tap-to-choose and
show-answer practice only (verified: `quiet_room_grammar_widget.dart` `_Practice` at `a7fa376`).
Grammar is the area that needs the most practice (user). Mark has a Japanese keyboard on his
phone and wants to type answers, with hiragana by default and kanji on request (user).
Speaking practice exists for vocabulary but not for grammar (verified:
`quiet_room_practice_widget.dart` at `a7fa376`). Android speech recognition often returns sentences in kanji. `judge()` already compares a kanji transcript with a `kanjiForms` list: an exact match is `correct`, a partial match is `close`, and a transcript it cannot compare is `unverified` (verified: `speech_service.dart` `judge()` at `a7fa376`, and the red-team run of 2026-10-24). The grammar lessons have no kanji versions to pass it yet.
The new study screens have no widget tests; the 12 Flutter tests cover streak logic only
(verified: `test/streak_test.dart` at `a7fa376`).

## Pivotal constraints

- Hiragana is the default display for Japanese words. Katakana is used for foreign loanwords (user).
- No login: the app opens on Japanese study when signed out (verified: `nav.dart` `_initialize` at `a7fa376`).
- Grammar content is LM-drafted and must pass the deterministic validator and an independent
  judge pass before it ships (verified: `publish.py` `check_draft()` at `a7fa376`).
- The app's lesson file is generated; a drift test fails CI if it differs from a fresh publish
  (verified: `pipeline/jp/tests/test_pipeline.py` `test_committed_app_file_matches_a_fresh_publish` at `a7fa376`).

## Resolved design tree

| # | Decision | Resolution | Source | Landing class |
|---|----------|------------|--------|---------------|
| D1 | Scope | widget tests and hardening first, then typed answers, the kanji option, and speaking | (user) Q1 | PIN-1→context |
| D2 | Spoken-answer check | hybrid: compare a hiragana transcript; compare a kanji transcript with the kanji version; otherwise show what was heard and fall back to self-check | (user) Q2 | PIN-2→slice (T8) ‡ |
| D3 | Typed answers | a text box per fill-in item that asks the keyboard for Japanese (`hintLocales` ja-JP) | (user) Q3 | PIN-3→slice (T7) |
| D4 | Kanji option | every grammar sentence gets a kanji version written `漢字{かんじ}`; a 漢字 toggle shows it; hiragana stays the default | (user) Q3 | PIN-4→guardrail ‡ |
| D5 | Kanji integrity | swapping each kanji for its bracketed reading must equal the hiragana sentence exactly, checked in CI | (user) Q3 · (verified: `kana_of()` at `a7fa376`) | PIN-5→end-state |
| D6 | Speaking surface | one "Speak this lesson" drill per grammar lesson, opened from a button on the lesson | (user) Q3 | PIN-6→slice (T8, T7) |
| D7 | Floor | hiragana default · readings match exactly · no correct answer marked wrong · no login | (user) Q4 | PIN-7→guardrail ‡ |
| D8 | Script rule | katakana for loanwords, hiragana for Japanese words | (user) Q4 | PIN-8→backstop |
| D9 | Kanji twin shape | every Japanese field gets a `_ruby` twin; lists get parallel twin lists; a hiragana-only word repeats its hiragana; a missing twin fails validation | (user) red-team Q1 | PIN-9→end-state |
| D10 | Close speech result | shown as Close in amber, the heard text with its matching part highlighted, then self-check | (user) red-team Q2 | PIN-10→guardrail ‡ |
| D11 | Reading format | one bracket per kanji word, okurigana outside: `買{か}い物{もの}` | (user) red-team Q3 · (verified: red-team probe, `kana_of('買い物{かいもの}')` returns `かいものい物`) | PIN-11→guardrail |
| D12 | OPM enforcement | a guard test keeps `STAGE_IO`, the diagram and the OPL text in step; every pipeline module registers its stage | (user) | PIN-12→guardrail ‡ |
| D13 | Lesson doc counts | the doc points to the catalog; the catalog lists each data file with live counts, findable by the app search | (user) red-team Q5 | PIN-13→guardrail |

## Assumptions ledger

| ID | Assumption | Basis | Blast radius if wrong | Check |
|----|-----------|-------|----------------------|-------|
| A1 | Gboard opens its Japanese layout when a field sets `hintLocales: [ja-JP]` | Android `EditorInfo.hintLocales` contract; Flutter passes it through `TextInputPlugin.java` | the keyboard opens in English; typing still works after a manual switch | backstop row 1 |
| A2 | Widget tests can render the study screens with Google Fonts runtime fetching turned off | [assumed: `GoogleFonts.config.allowRuntimeFetching = false` in the tests — if wrong: font load errors fail the tests] | Phase 1 tests error | End state 1 |
| A3 | Speech recognition returns the same kanji as the drafted kanji version for short sentences | [assumed: common N4 words have one standard spelling — if wrong: more answers fall back to self-check, none marked wrong] | fewer automatic checks | backstop row 2 |
| A4 | An LM drafting pass can supply correct kanji with readings for all 89 points | the s03 transcription used the same format without errors | wrong readings | End state 2 (exact match) + the judge pass |

## Non-goals / deferred

- Grammar and vocabulary for lessons 1 to 25 (needs the slide-deck table extractor; a separate plan).
- An on-device reading dictionary for open speech checking (Q2 option D).
- Firestore sync of self-check marks.

## New domain terms · Recommended ADRs

- **Kanji version (ruby):** a sentence written `漢字{かんじ}`, kanji followed by its reading in braces.
- ADR: none recommended.

## Commander's Intent

- **Purpose:** five-minute grammar lessons that Mark practices fully inside the app: read, type, and speak each pattern.
- **Method:** typed answers with the Japanese keyboard, a kanji version of every sentence behind a toggle, and a per-lesson speaking drill that checks what it can and asks Mark to self-check the rest. Guard the shipped screens with widget tests first. Keep the OPM in step with the code by a test, and make the data files findable through the app's catalog search.
- **Mechanism latitude:** widget layout, test framework details, how answers are normalized before comparison, sentence order in the speaking drill, how the matching part of a Close transcript is highlighted, and file names for new helpers are implementer's choice; substituting any of these mechanisms while the End states and binding guardrails hold is not a plan deviation and warrants no issue.
- **Binding guardrails:** hiragana is the default display (PIN-4, PIN-7) · katakana for loanwords (PIN-8) · each kanji version's readings equal its hiragana sentence exactly, one bracket per kanji word with okurigana outside (PIN-5, PIN-11) · no correct answer is ever marked wrong; an uncheckable or Close answer goes to self-check (PIN-2, PIN-7, PIN-10) · no login (PIN-7) · the app lesson file is only written by `pipeline/jp/publish.py` · every pipeline stage appears in `STAGE_IO`, the OPM diagram and its OPL text (PIN-12) · the lesson doc restates no count that a data file defines (PIN-13).
- **End state:**
  1. Widget tests cover the home search, the By use view, a choice question's feedback, and the hidden counter colors · gate: `/c/src/flutter/bin/flutter test`.
  2. Every Japanese field in every draft (example, prompt, answer, each accepted answer, each option) has a `_ruby` twin, and each twin's reading equals its hiragana text exactly (PIN-5, PIN-9) · check: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q` (prints `passed`, 0 failed).
  3. A typed answer is accepted in hiragana, in any accepted form, or in its kanji version, and a wrong answer is rejected · check: `/c/src/flutter/bin/flutter test test/grammar_answer_test.dart` (prints `All tests passed!`).
  4. Each fill-in text box requests the Japanese keyboard (`hintLocales` contains ja-JP) · check: `/c/src/flutter/bin/flutter test test/quiet_room_grammar_test.dart` (prints `All tests passed!`).
  5. The 漢字 toggle shows kanji versions, and hiragana is shown by default · check: `/c/src/flutter/bin/flutter test test/quiet_room_grammar_test.dart` (prints `All tests passed!`).
  6. The speaking drill marks an exact hiragana or kanji match correct, shows a Close result in amber with the matching part of the heard text highlighted and then self-check, and routes an uncomparable transcript to self-check, never to wrong (PIN-10) · check: `/c/src/flutter/bin/flutter test test/quiet_room_speak_test.dart` (prints `All tests passed!`).
  7. The committed `assets/lessons/jp_grammar.json` equals a fresh publish · check: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q` (prints `passed`).
  8. `pipeline/jp/review/judge_ruby.json` exists, and every finding in it is marked `applied` · check: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests/test_judge_applied.py -q` (prints `passed`).
  9. Every `STAGE_IO` stage has a process box in the OPM diagram generator and an OPL sentence, every diagram process has a `STAGE_IO` entry, and every registered pipeline module names a stage that `STAGE_IO` holds (PIN-12) · check: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests/test_opm_sync.py -q` (prints `passed`).
  10. The catalog holds one source-file entry per data file (its role, origin and live counts), the app search finds it by name, and `docs/japanese-lessons.md` points to the catalog with no restated count (PIN-13) · check: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests/test_catalog_sources.py -q` (prints `passed`).

## Build order (for /war)

Phase 1 (harden) → Phase 2 (foundations: kanji validator, OPM sync, source catalog) → Phase 3 (kanji data) → Phase 4 (typing and speaking) → Phase 5 (release).

## Phase 1 — Harden what shipped

### Task 1: Widget tests for the study screens
- Files: `test/quiet_room_japanese_test.dart`, `test/quiet_room_grammar_test.dart`, `test/quiet_room_drills_test.dart`
- Plan slice: pump each screen with the real `assets/lessons/jp_grammar.json`; assert the home search finds "advice" results, the By use view lists a use's patterns, a wrong choice shows its reason, and counter colors stay hidden until a cell is tapped. The red-team pumped `QuietRoomJapaneseWidget` in a bare `MaterialApp` and it rendered, so A2 is confirmed; add `SharedPreferences.setMockInitialValues({})` for the screens that read it.
- Done when: `/c/src/flutter/bin/flutter test`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 2: Retire the old plan and point the lesson doc at the catalog
- Files: `docs/plans/2026-10-23-japanese-grammar-sources.md`, `docs/japanese-lessons.md`
- Plan slice: mark the old plan superseded by this one, with its five decisions as resolved. Rewrite `docs/japanese-lessons.md` to the shipped state, saying hiragana and katakana, never "kana". De-mirror every count a data file defines (word counts, lesson lists, point and item counts): the doc names the catalog (`catalog` in `assets/lessons/jp_grammar.json`, built by `pipeline/jp/catalog.py`) as where the live counts are, and says the app's search finds each data file by name (PIN-13). The source-file entries are defined-but-not-yet-emitted; produced in Task 10.
- Done when: None — documentation only; the de-mirror is checked by Task 10's test, which scans this doc for restated counts.
- requiresTest: false
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 3: One command to refresh the fixtures
- Files: `pipeline/jp/refresh_fixtures.py`, `pipeline/jp/tests/test_refresh.py`
- Plan slice: copy each `out/<source>/lesson_bundle.json` into `fixtures/<source>/`, report which changed, and refuse when an `out/` bundle is missing or its `state` is `blocked`. `out/` is gitignored, so the test builds a temporary `out/` tree.
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests/test_refresh.py -q`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 2 — Foundations: kanji validator, OPM sync, source catalog

### Task 6: Keep the OPM in step with the code
- Files: `pipeline/extraction_schemas.py`, `pipeline/jp/stages.py`, `pipeline/jp/tests/test_opm_sync.py`, `docs/opm-lesson-extraction.md`, `docs/opm-lesson-extraction.gen.js`, `docs/opm-lesson-extraction.drawio`
- Plan slice: add this plan's stages to `STAGE_IO`, the diagram generator and the OPL text: Kanji Drafting (LM), Kanji Validating (deterministic), Judging (LM, the judge pass), Answer Checking and Speech Checking (deterministic, in the app). Add `stages.py`, a registry from each `pipeline/jp` module to its OPM stage; it pre-registers `ruby.py` (defined-but-not-yet-emitted; produced in Task 4). Add the guard test: every `STAGE_IO` stage has a process box in the generator and an OPL sentence, every generator process has a `STAGE_IO` entry, and every `pipeline/jp/*.py` file on disk is registered or listed as a helper. Regenerate the `.drawio` from the generator (PIN-12).
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests/test_opm_sync.py -q`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 4: Kanji twin support in the validator and publisher
- Files: `pipeline/jp/ruby.py`, `pipeline/jp/s03_pairs_textbook.py`, `pipeline/jp/publish.py`, `pipeline/jp/tests/test_ruby.py`
- Plan slice: move the `漢字{かんじ}` helpers out of `s03_pairs_textbook.py` into `ruby.py`, and import them back there. Reading-of replaces every bracket; a bracket's base must be kanji only (and 々), so `買{か}い物{もの}` passes and `買い物{かいもの}` is rejected (PIN-11). `check_draft()` validates a `_ruby` twin beside every Japanese field: `jp_ruby`, `prompt_ruby`, `answer_ruby`, and parallel `accepted_ruby` / `options_ruby` lists; `why_wrong` stays keyed by the hiragana option (PIN-9). Twins are required only when `publish.REQUIRE_RUBY` is true; it ships false here, and Task 5 flips it. Publishing carries the twins into the app file. Test the red-team's cases, including `買い物{かいもの}`.
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q`
- requiresTest: true
- requiresPackaging: false
- deps: [Task 6]
- target repo: superproject

### Task 10: Catalog the data files and find them in the app
- Files: `pipeline/jp/catalog.py`, `pipeline/jp/tests/test_catalog_sources.py`, `lib/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart`, `assets/lessons/jp_grammar.json`, `docs/japanese-lessons.md`
- Plan slice: Cataloging adds one `source_file` entry per data file (the five extraction bundles, the drafts, `uses.json`, `corrections.json`, `jp_lessons.json`): its role, its origin (for example "Mari's N4 sheet"), and counts computed live from the file. Its open target is a search for that source, which the home screen applies to its search box. The test checks that every data file has an entry with live counts, and that `docs/japanese-lessons.md` restates none of those counts (PIN-13). Run `publish.py` to regenerate the app file.
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 3 — Kanji versions of every sentence

### Task 5: Draft and judge the kanji twins, then publish
- Files: `pipeline/jp/drafts/L26.json`, `pipeline/jp/drafts/L27.json`, `pipeline/jp/drafts/L28.json`, `pipeline/jp/drafts/L29.json`, `pipeline/jp/drafts/L30.json`, `pipeline/jp/drafts/L31.json`, `pipeline/jp/drafts/L32.json`, `pipeline/jp/drafts/L33.json`, `pipeline/jp/drafts/L34.json`, `pipeline/jp/drafts/L35.json`, `pipeline/jp/drafts/L36.json`, `pipeline/jp/drafts/L37.json`, `pipeline/jp/drafts/L38.json`, `pipeline/jp/drafts/L39.json`, `pipeline/jp/drafts/L40.json`, `pipeline/jp/drafts/L41.json`, `pipeline/jp/drafts/L42.json`, `pipeline/jp/drafts/L43.json`, `pipeline/jp/drafts/L44.json`, `pipeline/jp/drafts/L45.json`, `pipeline/jp/drafts/L46.json`, `pipeline/jp/drafts/L47.json`, `pipeline/jp/drafts/L48.json`, `pipeline/jp/drafts/L49.json`, `pipeline/jp/drafts/L50.json`, `pipeline/jp/review/judge_ruby.json`, `pipeline/jp/publish.py`, `pipeline/jp/tests/test_judge_applied.py`, `assets/lessons/jp_grammar.json`
- Plan slice: add a `_ruby` twin to every Japanese field (standard N4 kanji only; a word normally written in hiragana repeats its hiragana; katakana for loanwords; one bracket per kanji word). Run an independent judge pass that writes `judge_ruby.json`, apply its fixes, and mark each finding `applied`. Flip `publish.REQUIRE_RUBY` to true. Add the test that every judge finding is `applied`. Run `publish.py`.
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 4 — Typing and speaking in the app

### Task 8: The per-lesson speaking drill
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`, `lib/components/pages/quiet_room_practice/speech_service.dart`, `lib/flutter_flow/nav/nav.dart`, `test/quiet_room_speak_test.dart`
- Plan slice: a drill (PIN-6) over a lesson's examples and completed practice sentences: play the sentence, listen once, then judge. Reuse `judge()`'s existing `kanjiForms` parameter, passing the sentence's kanji surface. `correct` marks it right. `close` shows a Close result in amber, with the heard text shown and its matching part highlighted, then "Got it" / "Missed it" (PIN-10). `unverified` and `wrong` on an uncomparable transcript also go to self-check, never to a wrong mark (PIN-2). Update the stale header comment in `speech_service.dart`. Register the route.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_speak_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 7: Typed answers and the kanji toggle on the grammar screen
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart`, `lib/components/pages/quiet_room_grammar/jp_study_kit.dart`, `test/grammar_answer_test.dart`, `test/quiet_room_grammar_test.dart`
- Plan slice: a text box on each fill-in item with `hintLocales` ja-JP (PIN-3); an answer matcher in `jp_study_kit.dart` that accepts the answer, any accepted form, or a kanji twin's surface; a 漢字 toggle that swaps every sentence to its kanji twin, with hiragana the default; a "Speak this lesson" button that opens Task 8's route (PIN-6). Add the hintLocales and toggle widget tests to `test/quiet_room_grammar_test.dart` (created in Task 1).
- Done when: `/c/src/flutter/bin/flutter test test/grammar_answer_test.dart test/quiet_room_grammar_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: [Task 8]
- target repo: superproject

## Phase 5 — Release

### Task 9: Version bump
- Files: `pubspec.yaml`
- Plan slice: the next free minor version above the live base, with a build number one above the live base (resolved from `pubspec.yaml` at land time, never a literal written here). The phone install is an update, so the build number must rise.
- Done when: None — version slot only; the build-release CI job is the check.
- requiresTest: false
- requiresPackaging: false
- deps: []
- target repo: superproject

## Deferred validations (backstops)

- Gboard opens in Japanese for the answer box (A1) · why deferred: needs the physical phone · runner: Mark, on the first install of the Phase 5 build.
- Spoken sentences check automatically more often than they fall back (A3) · why deferred: needs real speech recognition · runner: Mark, ten sentences in one lesson after install.
- Kanji twins read naturally, and katakana is used only for loanwords (PIN-8) · why deferred: End state 8 proves every judge finding was applied, but no command judges script choice itself · runner: Mark's spot check of two lessons after install.

## Notes / conscious deviations

- Task numbers follow the order tasks were added, not run order. Phase 2 runs Task 6 first, then Task 4 (it registers in Task 6's `stages.py`); Task 10 runs alongside. Phase 4 runs Task 8, then Task 7.
- Red-team 2026-10-24 decisions are pins PIN-9 to PIN-13 (rows D9 to D13).
- `publish.REQUIRE_RUBY` ships false in Task 4 so the validator lands before the data; Task 5 flips it in the same task that adds every twin.

## Open decisions

None.
