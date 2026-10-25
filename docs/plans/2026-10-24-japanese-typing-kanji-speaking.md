# Japanese study: typed answers, a kanji option, and speaking practice

**Evidence consumed** — one row per linked artifact:
- PR #66 (`feat/quiet-room-japanese-lessons`, CI green at `a7fa376`) · read
- `lib/components/pages/quiet_room_practice/speech_service.dart` `judge()` / `listenOnce()` at `a7fa376` · read
- `pipeline/jp/s03_pairs_textbook.py` `kana_of()` / `plain_of()` at `a7fa376` · read
- Flutter SDK `text_field.dart` `hintLocales` (local SDK, `C:/src/flutter`) · read
- `pipeline/jp/review/judge_*.json` (judge pass, 356 items, 0 wrong keys) · read
- `docs/plans/2026-10-23-japanese-grammar-sources.md` (superseded by this plan) · read
- WAR run history (`.claude/war/runs/`, `docs/learnings/`) · unread: neither exists in this repo

## Context — the gap / problem

The grammar lessons (Mari's lessons 26 to 50) ship in the phone app with tap-to-choose and
show-answer practice only (verified: `quiet_room_grammar_widget.dart` `_Practice` at `a7fa376`).
Grammar is the area that needs the most practice (user). Mark has a Japanese keyboard on his
phone and wants to type answers, with hiragana by default and kanji on request (user).
Speaking practice exists for vocabulary but not for grammar (verified:
`quiet_room_practice_widget.dart` at `a7fa376`). Android speech recognition often returns
sentences in kanji, which the current checker cannot compare with hiragana: `judge()` returns
a separate "kanji, cannot compare" outcome (verified: `speech_service.dart` `judge()` at `a7fa376`).
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
- **Method:** typed answers with the Japanese keyboard, a kanji version of every sentence behind a toggle, and a per-lesson speaking drill that checks what it can and asks Mark to self-check the rest. Guard the shipped screens with widget tests first.
- **Mechanism latitude:** widget layout, test framework details, how answers are normalized before comparison, sentence order in the speaking drill, and file names for new helpers are implementer's choice; substituting any of these mechanisms while the End states and binding guardrails hold is not a plan deviation and warrants no issue.
- **Binding guardrails:** hiragana is the default display (PIN-4, PIN-7) · katakana for loanwords (PIN-8) · each kanji version's readings equal its hiragana sentence exactly (PIN-5) · no correct answer is ever marked wrong; an uncheckable answer falls back to self-check (PIN-2, PIN-7) · no login (PIN-7) · the app lesson file is only written by `pipeline/jp/publish.py`.
- **End state:**
  1. Widget tests cover the home search, the By use view, a choice question's feedback, and the hidden counter colors · gate: `flutter test`.
  2. Every grammar example, practice prompt, answer, accepted answer and option has a kanji version whose readings equal its hiragana text exactly (PIN-5) · check: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q` (prints `passed`, 0 failed).
  3. A typed answer is accepted in hiragana, in any accepted form, or in its kanji version, and a wrong answer is rejected · check: `flutter test test/grammar_answer_test.dart` (prints `All tests passed!`).
  4. Each fill-in text box requests the Japanese keyboard (`hintLocales` contains ja-JP) · check: `flutter test test/quiet_room_grammar_test.dart` (prints `All tests passed!`).
  5. The 漢字 toggle shows kanji versions, and hiragana is shown by default · check: `flutter test test/quiet_room_grammar_test.dart` (prints `All tests passed!`).
  6. The speaking drill marks a matching hiragana or kanji transcript correct, and routes an uncomparable transcript to self-check, never to wrong · check: `flutter test test/quiet_room_speak_test.dart` (prints `All tests passed!`).
  7. The committed `assets/lessons/jp_grammar.json` equals a fresh publish · check: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q` (prints `passed`).
  8. The judge pass over the kanji versions reports no wrong reading and no katakana misuse left unfixed · backstop: row 3.

## Build order (for /war)

Phase 1 (harden) → Phase 2 (kanji data) → Phase 3 (typing and speaking) → Phase 4 (release).

## Phase 1 — Harden what shipped

### Task 1: Widget tests for the study screens
- Files: `test/quiet_room_japanese_test.dart`, `test/quiet_room_grammar_test.dart`, `test/quiet_room_drills_test.dart`
- Plan slice: pump each screen with the real `assets/lessons/jp_grammar.json`; assert the home search finds "advice" results, the By use view lists a use's patterns, a wrong choice shows its reason, and counter colors stay hidden until a cell is tapped. Turn off Google Fonts runtime fetching in tests (A2).
- Done when: `flutter test`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 2: Retire the old plan and update the lesson doc
- Files: `docs/plans/2026-10-23-japanese-grammar-sources.md`, `docs/japanese-lessons.md`
- Plan slice: mark the old plan superseded by this one, with its five decisions as resolved; update `docs/japanese-lessons.md` to the shipped state, saying hiragana and katakana, never "kana".
- Done when: None — documentation only; reviewed by the auditor seat.
- requiresTest: false
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 3: One command to refresh the fixtures
- Files: `pipeline/jp/refresh_fixtures.py`, `pipeline/jp/tests/test_refresh.py`
- Plan slice: copy each `out/<source>/lesson_bundle.json` into `fixtures/<source>/`, report which changed, and refuse when an `out/` bundle is missing or blocked.
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests/test_refresh.py -q`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 2 — Kanji versions of every sentence

### Task 4: Kanji version support in the validator and publisher
- Files: `pipeline/jp/ruby.py`, `pipeline/jp/publish.py`, `pipeline/jp/tests/test_ruby.py`
- Plan slice: move the `漢字{かんじ}` helpers into `ruby.py` (reading of, surface of); `check_draft()` accepts an optional `ruby` beside every Japanese field and fails when its reading differs from the hiragana text; publishing carries the kanji surface into the app file.
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 5: Draft and judge the kanji versions, then publish
- Files: `pipeline/jp/drafts/L26.json`, `pipeline/jp/drafts/L27.json`, `pipeline/jp/drafts/L28.json`, `pipeline/jp/drafts/L29.json`, `pipeline/jp/drafts/L30.json`, `pipeline/jp/drafts/L31.json`, `pipeline/jp/drafts/L32.json`, `pipeline/jp/drafts/L33.json`, `pipeline/jp/drafts/L34.json`, `pipeline/jp/drafts/L35.json`, `pipeline/jp/drafts/L36.json`, `pipeline/jp/drafts/L37.json`, `pipeline/jp/drafts/L38.json`, `pipeline/jp/drafts/L39.json`, `pipeline/jp/drafts/L40.json`, `pipeline/jp/drafts/L41.json`, `pipeline/jp/drafts/L42.json`, `pipeline/jp/drafts/L43.json`, `pipeline/jp/drafts/L44.json`, `pipeline/jp/drafts/L45.json`, `pipeline/jp/drafts/L46.json`, `pipeline/jp/drafts/L47.json`, `pipeline/jp/drafts/L48.json`, `pipeline/jp/drafts/L49.json`, `pipeline/jp/drafts/L50.json`, `pipeline/jp/review/judge_ruby.json`, `assets/lessons/jp_grammar.json`
- Plan slice: add a `ruby` kanji version to every Japanese field (standard N4 kanji only; leave a word in hiragana when it is normally written in hiragana; katakana for loanwords); run an independent judge pass that writes `judge_ruby.json`; apply its fixes; run `publish.py`.
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q`
- requiresTest: true
- requiresPackaging: false
- deps: [Task 4]
- target repo: superproject

## Phase 3 — Typing and speaking in the app

### Task 8: The per-lesson speaking drill
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`, `lib/components/pages/quiet_room_practice/speech_service.dart`, `lib/flutter_flow/nav/nav.dart`, `test/quiet_room_speak_test.dart`
- Plan slice: a drill (PIN-6) over a lesson's examples and completed practice sentences: play the sentence, listen once, then judge. `judge()` gains an optional kanji surface: a hiragana transcript is compared with the hiragana text, a kanji transcript with the kanji surface, and anything else falls back to "Got it / Missed it" self-check (PIN-2). Register the route.
- Done when: `flutter test test/quiet_room_speak_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 7: Typed answers and the kanji toggle on the grammar screen
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart`, `lib/components/pages/quiet_room_grammar/jp_study_kit.dart`, `test/grammar_answer_test.dart`, `test/quiet_room_grammar_test.dart`
- Plan slice: a text box on each fill-in item with `hintLocales` ja-JP (PIN-3); an answer matcher in `jp_study_kit.dart` that accepts the answer, any accepted form, or its kanji surface; a 漢字 toggle that swaps every sentence to its kanji version; a "Speak this lesson" button that opens Task 8's route (PIN-6).
- Done when: `flutter test test/grammar_answer_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: [Task 8]
- target repo: superproject

## Phase 4 — Release

### Task 9: Version bump
- Files: `pubspec.yaml`
- Plan slice: next free minor version above the live base, with the build number one above the live base.
- Done when: None — version slot only; the build-release CI job is the check.
- requiresTest: false
- requiresPackaging: false
- deps: []
- target repo: superproject

## Deferred validations (backstops)

- Gboard opens in Japanese for the answer box (A1) · why deferred: needs the physical phone · runner: Mark, on the first install of the Phase 4 build.
- Spoken sentences check automatically more often than they fall back (A3) · why deferred: needs real speech recognition · runner: Mark, ten sentences in one lesson after install.
- Kanji versions read correctly, and katakana is used only for loanwords (PIN-8) · why deferred: no tool checks script choice · runner: the Task 5 judge pass, then Mark's spot check of two lessons.

## Notes / conscious deviations

- Task numbers in Phase 3 run 8 then 7 because Task 7 depends on Task 8's route (one phase, two waves).

## Open decisions

None.
