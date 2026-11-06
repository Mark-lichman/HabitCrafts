# Japanese study with a tutor: the lesson link, Discuss with Mari, type it + see it + say it, and sentence variety

Confirmed by the operator at both echo-backs on 2026-11-06 (user). A follow-up to the landed
`docs/plans/2026-11-02-jp-mastery-queue.md`, drafted at base `560507a` (the tip of the stacked
PRs #136, #141, #142, #143, #148 and #149).

**Evidence consumed**
- `C:/Users/markl/AppData/Local/Temp/claude/C--Users-markl/ee93c723-f089-4789-bb3d-42de53fc0dc5/scratchpad/ux-review/proposals/index-v3.html` `#lesson-link` (the lesson-link concept, its kind table and the scoring options) · read in full
- issue #88 (2026-10-26) and its diagnosis comment · read
- issues #144, #145, #146, #147 (2026-11-06) · read (written this session from the operator's rulings)
- `lib/components/pages/quiet_room_mastery/mastery_rule.dart` `_meetsRule`, `kTransferProbes`, `ItemDefLike` at `560507a` · read
- `lib/components/pages/quiet_room_mastery/item_catalog.dart` (templates per `ItemKind`) at `560507a` · read
- `lib/components/pages/quiet_room_mastery/session_widget.dart` `standardProbeBuilder` at `560507a` · read
- `lib/components/pages/quiet_room_mastery/lesson_page_widget.dart`, `lessons_path_widget.dart` (routes, `kLastGrammarLessonKey`) at `560507a` · read
- `lib/components/pages/quiet_room_mastery/jp_store.dart` `ItemRecord.note`, `setNote` and `study_export.dart` note lines at `560507a` · read
- `lib/components/pages/quiet_room_practice/speech_service.dart` `_PluginStt.listen` and `pronunciation_service.dart` `PronunciationService` at `560507a` · read
- `firebase/speech_functions/index.js` `scorePronunciation` at `560507a` · read
- `assets/lessons/jp_grammar.json` (89 points × 4 practice rows, 2 examples each; 15 particles, 1 cloze each) at `560507a` · read; counts are dated snapshots
- `C:/Projects/habitcrafts-war/.claude/war/config.json` (gate, testPattern) and `.github/workflows/ci.yml` · read
- `docs/learnings/` (33 lessons, listing) · read; `lm-judge-misses-homophone-kanji-slips`, `azure-scoring-constants-need-a-real-device-run`, `tests-must-not-pin-state-a-later-task-flips` read in full
- open war-followup issues #119, #135 · read (titles); neither touches this scope

## Context — the gap / problem

The landed mastery queue tests recall but gives the learner no way back to the idea he forgot
(user, 2026-11-06). When Mark misses a card he cannot open the lesson behind it and return to the
same card. He also has no way to keep a list of things to raise with his tutor, Mari, and Mari
will not use the app (user).

Mastered today needs four spaced clears, two templates and one production clear where the item has
them (verified: `mastery_rule.dart` `_meetsRule` at `560507a`). Spoken answers never count: the
Say-it track is excluded by `Source.sayIt`, and only words have a scored spoken card (verified:
`item_catalog.dart` at `560507a`). Mark wants type it, see it and say it all required (user).

Speech recognition on the phone fails (verified: issue #88 (2026-10-26)). The comment's diagnosis:
the on-device transcript comes back in kanji outside the N4 list, and `judge()` has no reading
dictionary, so a right answer scores Close. Azure pronunciation scoring already judges the grammar
speak drill by sound against the hiragana (verified: `pronunciation_service.dart`,
`firebase/speech_functions/index.js` at `560507a`).

Each particle has exactly one sentence, its lesson example, and transfer counts no particles, so a
particle can reach Mastered on one memorized sentence (verified: `jp_grammar.json` and
`kTransferProbes` at `560507a`). Grammar points already have 4 practice sentences each.

## Pivotal constraints

- The repo is public: no Azure key and no personal study record in the repo (user, standing rule).
- The study record is append-only; old exports must keep importing (verified: `study_export.dart`
  header counts at `560507a`).
- The phone may be offline; Azure needs the network (verified: `scorePronunciation` is an
  `onCall` function at `560507a`).
- Never install on the phone before the PR CI is all green (user, standing rule).
- App text says hiragana, never the other word for the syllabary (user, standing rule).

## Resolved design tree

| # | Decision | Resolution | Source | Landing class |
|---|----------|------------|--------|---------------|
| D1 | The learner's own lesson upload (#147) | its own later plan; no upload or extraction code exists in `lib/` or `firebase/` | PIN-1 · (user) · (verified: recon at `560507a`) | non-goal |
| D2 | What judges a spoken answer that counts | Azure pronunciation scoring only; the on-device transcript stays for practice that does not count | PIN-2 · (user) | guardrail ‡ |
| D3 | Which kinds get a scored say card | all 6: grammar and particle say the full sentence; word, conjugation, pair and table row say the answer's hiragana | PIN-3 · (user) | PIN-3→slice (T6) |
| D4 | Particle sentence variety | 2 more sentences per particle (30 in all), AI-drafted, judge-checked, shipped marked unreviewed for Mark's review; particle transfer count 2 | PIN-4 · (user) | PIN-4→slice (T8, T9) |
| D5 | The lesson link | "Review the lesson" on every card opens the concept table's target; Back returns to the same unanswered card; a right answer after a review is hinted; a review after the answer is free; opening a lesson writes no attempt; a particle's lesson view hides its example | PIN-5 · (user, 2026-11-06, option A) | PIN-5→guardrail ‡ |
| D6 | Discuss with Mari | Mark's own reminder list, reachable from Today; a mark changes no grade and no schedule; Mari never needs the app | PIN-6 · (user) | PIN-6→guardrail ‡ |
| D7 | Mastered needs type, see and say | a typed, a recognition and a spoken clear among the counting clears, wherever the kind has that card; particles gain a multiple-choice card | PIN-7 · (user) | PIN-7→slice (T6, T7) |
| D8 | OPM | the plan ends by updating SD5 and SD6 | PIN-8 · (user) | PIN-8→slice (T10) |
| D9 | Mark's phone record | after the plan lands, it starts fresh: back up, clear, then seed with no lesson ticked | PIN-9 · (user) | backstop |
| D10 | Offline spoken answer | unscored, never wrong | [assumed: unscored — if wrong: a dead zone grades a spoken clear wrong] · confirmed (user) | slice (T5) |
| D11 | When a sentence moves aside | once it has clears on 2 different days; the next review prefers a sentence with no clear yet | [assumed: 2 days — if wrong: variety comes too early or too late] · confirmed (user) | slice (T9) |
| D12 | Existing Mastered badges | none exist; the record restarts (PIN-9) | (user) | context |
| D13 | Test records | synthetic fixtures only; Mark's export stays out of the repo | (user) | guardrail |

## Assumptions ledger

| ID | Assumption | Basis | Blast radius if wrong | Check |
|----|-----------|-------|----------------------|-------|
| A1 | Azure scores a single word, a conjugated form and a table reading as well as a sentence | it already scores sentences (`score.js` tests) | short say cards score poorly and block Mastered | backstop row 1 |
| A2 | The session route stays mounted under a pushed lesson route, so Back returns to the same card state | recon: `SessionWidget` lives in its own pushed route with default `maintainState` | the card resets on Back | End state 1's test |
| A3 | 30 AI-drafted particle sentences pass the publish validator and the judge with few fixes | the earlier particle English (15) and the grammar drafts passed | Phase 6 runs long | Task 8's `Done when:` |
| A4 | A multiple-choice particle card with the other 14 particles as wrong options has one right answer per sentence | particles differ in meaning | an ambiguous card | Task 6's validator test |

## Non-goals / deferred

- The learner's own lesson upload (#147): its own plan (PIN-1).
- `why_wrong` in the Review session, the progress tracker, and the keyboard check (#127): on hold (user).
- Any tutor-facing view or tutor account (PIN-6).

## New domain terms · Recommended ADRs

- **Lesson review:** opening the core lesson from a card before answering it. It makes a right answer hinted.
- **Discuss mark:** Mark's reminder on an item to raise with Mari. It changes no grade and no schedule.
- **Modes:** type it (a typed production clear), see it (a recognition clear), say it (an Azure-scored spoken clear).
- ADR recommended: "A spoken clear counts only from Azure scoring" (hard to reverse, surprising without context, a cost and offline trade-off).

## Commander's Intent

- **Purpose:** When I forget an idea, I can look it up mid-practice and mark it for Mari. Mastered then means I can type it, recognize it and say it, across more than one sentence.
- **Method:** link every card to its core lesson and back; keep a private Discuss list; score spoken answers through Azure; add a say card to every kind and a multiple-choice card to particles; require all three modes where the kind has them; give particles three sentences and rotate off a sentence once it is cleared on two days; then bring the lesson doc and the OPM up to date.
- **Mechanism latitude:** where the Discuss button and list sit; how the Discuss mark is stored; how a screen scrolls or opens at an idea; the exact next-sentence picking rule within D11; the say-card widget's layout. Substituting any of these mechanisms while the End states and binding guardrails hold is not a plan deviation and warrants no issue.
- **Binding guardrails:** a lesson review before the answer makes a right answer hinted, and Show
  English stays free (PIN-5) · only Azure scoring counts a spoken clear toward Mastered (PIN-2) ·
  Mari never needs the app, and a Discuss mark changes no grade and no schedule (PIN-6) · existing
  records and exports still load, and no attempt is rewritten · unreviewed sentences stay marked
  unreviewed until Mark reviews them (PIN-4).
- **End state:**
  1. From a Review session card, "Review the lesson" opens the kind's target screen, Back returns to the same unanswered card, and a right answer after it is graded hinted · check: `/c/src/flutter/bin/flutter test test/session_widget_test.dart test/lesson_page_test.dart` (prints `All tests passed!`).
  2. A particle's lesson view never shows its cloze sentence · check: `/c/src/flutter/bin/flutter test test/topics_widget_test.dart test/lesson_page_test.dart` (prints `All tests passed!`).
  3. A Discuss mark appears in the list on Today, survives export and import, and changes no grade and no schedule · check: `/c/src/flutter/bin/flutter test test/discuss_test.dart test/jp_store_test.dart` (prints `All tests passed!`).
  4. A spoken answer counts as a clear only from Azure scoring; with no connection it is unscored · check: `/c/src/flutter/bin/flutter test test/probe_widgets_test.dart test/pronunciation_service_test.dart` (prints `All tests passed!`).
  5. Every item kind has a scored say card, and particles have a multiple-choice card · check: `/c/src/flutter/bin/flutter test test/item_catalog_test.dart` (prints `All tests passed!`).
  6. Mastered needs a typed, a recognition and a spoken clear wherever the kind has that card · check: `/c/src/flutter/bin/flutter test test/mastery_rule_test.dart` (prints `All tests passed!`).
  7. Every particle has 3 sentences marked unreviewed, needs 2 for transfer, and the session moves off a sentence cleared on 2 days · check: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q && /c/src/flutter/bin/flutter test test/item_catalog_test.dart test/session_widget_test.dart` (prints `passed` and `All tests passed!`).
  8. An export written before this plan imports unchanged · check: `/c/src/flutter/bin/flutter test test/jp_store_test.dart` (prints `All tests passed!`).
  9. The whole app, pipeline and speech-function suites stay green · gate: the run's resolved gate (`overrides.gate` in `.claude/war/config.json`).
  10. Azure scores spoken answers on Mark's phone, and Mark reviews the 30 sentences · backstop: rows 1 and 2.

## Build order (for /war)

Phase 1 (lesson link) → Phase 2 (Discuss with Mari) → Phase 3 (spoken answers) → Phase 4 (new cards) → Phase 5 (mastery rule) → Phase 6 (sentence variety) → Phase 7 (docs and OPM).

## Phase 1 — The lesson link

### Task 1: Screens open at an idea
- Files: `lib/components/pages/quiet_room_mastery/lesson_page_widget.dart`, `lib/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart`, `lib/components/pages/quiet_room_grammar/quiet_room_drills_widget.dart`, `lib/components/pages/quiet_room_mastery/topic_page_widget.dart`, `test/lesson_page_test.dart`, `test/quiet_room_lesson_test.dart`, `test/quiet_room_drills_test.dart`, `test/topics_widget_test.dart`
- Plan slice: the lesson page opens scrolled to a given point id and shows a "Back to practice" bar when opened from a card; the word cards open at a given word; the Conjugation, Verb pairs and Numbers screens open at a given form or row; a particle with no Mari lesson opens its topic page with the example sentence hidden; a lesson particle opens its lesson page with the particle's meaning at the top and its example hidden (PIN-5). Each screen keeps its plain entry unchanged.
- Done when: `/c/src/flutter/bin/flutter test test/lesson_page_test.dart test/quiet_room_lesson_test.dart test/quiet_room_drills_test.dart test/topics_widget_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 2: Review the lesson from a card
- Files: `lib/components/pages/quiet_room_mastery/session_widget.dart`, `lib/components/pages/quiet_room_mastery/probe_widgets.dart`, `test/session_widget_test.dart`, `test/probe_widgets_test.dart`
- Plan slice: every unanswered card shows a quiet "Review the lesson" link naming the lesson and idea; it pushes Task 1's target for the item's kind; Back returns to the same card, unanswered, marked "Lesson reviewed"; a right answer after a review is graded hinted (hint level 1) and a review after the answer changes nothing; opening a lesson writes no attempt (PIN-5).
- Done when: `/c/src/flutter/bin/flutter test test/session_widget_test.dart test/probe_widgets_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: [1]
- target repo: superproject

## Phase 2 — Discuss with Mari

### Task 3: Store the Discuss marks
- Files: `lib/components/pages/quiet_room_mastery/jp_store.dart`, `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart`, `lib/components/pages/quiet_room_mastery/jp_store_memory.dart`, `lib/components/pages/quiet_room_mastery/study_export.dart`, `test/jp_store_test.dart`
- Plan slice: a Discuss mark per item with an optional short note, set and cleared through the store, kept beside the log and carried by export and import; a pre-plan export (synthetic fixture) still imports unchanged; marks never touch attempts, the schedule or mastery (PIN-6, End state 8).
- Done when: `/c/src/flutter/bin/flutter test test/jp_store_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 4: The Discuss button and the list on Today
- Files: `lib/components/pages/quiet_room_mastery/discuss_list_widget.dart`, `lib/components/pages/quiet_room_mastery/session_widget.dart`, `lib/components/pages/quiet_room_mastery/item_detail_widget.dart`, `lib/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart`, `lib/flutter_flow/nav/nav.dart`, `test/discuss_test.dart`
- Plan slice: a "Discuss with Mari" toggle on each session card and on the item page; a "Discuss with Mari" list reachable from Today's quiet links, each row opening its item and clearable once discussed; a mark changes no grade and no schedule (PIN-6).
- Done when: `/c/src/flutter/bin/flutter test test/discuss_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: [3]
- target repo: superproject

## Phase 3 — Spoken answers through Azure

### Task 5: Spoken cards score through Azure
- Files: `lib/components/pages/quiet_room_mastery/probe_widgets.dart`, `lib/components/pages/quiet_room_practice/pronunciation_service.dart`, `test/probe_widgets_test.dart`, `test/pronunciation_service_test.dart`
- Plan slice: the word card's spoken answer, and every scored spoken card after Phase 4, scores through `PronunciationService` against the hiragana; correct is clear, close is hinted, wrong is wrong; unverified or no connection is unscored, never wrong (PIN-2, D10). The on-device transcript path stays only for practice that does not count. This closes #88 for the counting path.
- Done when: `/c/src/flutter/bin/flutter test test/probe_widgets_test.dart test/pronunciation_service_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 4 — New cards

### Task 6: A say card for every kind, and a multiple-choice card for particles
- Files: `lib/components/pages/quiet_room_mastery/item_catalog.dart`, `lib/components/pages/quiet_room_mastery/probe_widgets.dart`, `lib/components/pages/quiet_room_mastery/session_widget.dart`, `test/item_catalog_test.dart`, `test/probe_widgets_test.dart`, `test/session_widget_test.dart`
- Plan slice: each of the 6 kinds gets a scored say probe (grammar and particle: the full sentence; word, conjugation, pair, table row: the answer's hiragana), scored through Task 5's path; particles get a choose probe whose wrong options are other particles, with exactly one option that completes the sentence (PIN-3, PIN-7).
- Done when: `/c/src/flutter/bin/flutter test test/item_catalog_test.dart test/probe_widgets_test.dart test/session_widget_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 5 — The mastery rule

### Task 7: Type it, see it and say it
- Files: `lib/components/pages/quiet_room_mastery/mastery_rule.dart`, `test/mastery_rule_test.dart`, `test/srs_simulation_test.dart`
- Plan slice: each template maps to one mode (typed, recognition, spoken); Mastered needs a counting clear in every mode the item has a scored card for, beside the existing four-clear, 21-day and no-wrong rules (PIN-7). Re-measure the simulator's Mastered-by-day expectations at the rebased base.
- Done when: `/c/src/flutter/bin/flutter test test/mastery_rule_test.dart test/srs_simulation_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 6 — Sentence variety

### Task 8: Draft and publish 30 particle sentences
- Files: `pipeline/jp/particle_sentences.json`, `pipeline/jp/publish.py`, `pipeline/jp/tests/test_pipeline.py`, `assets/lessons/jp_grammar.json`
- Plan slice: 2 more sentences per particle, each a cloze with its answer, accepted forms and English, in hiragana within the N4 kanji limit, AI-drafted and checked by an independent judge pass; `publish.py` adds them to each particle with a `reviewed: false` flag and fails on a stale or leaking cloze; republish `jp_grammar.json` (PIN-4).
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 9: Rotate across sentences
- Files: `lib/components/pages/quiet_room_mastery/item_catalog.dart`, `lib/components/pages/quiet_room_mastery/mastery_rule.dart`, `lib/components/pages/quiet_room_mastery/session_widget.dart`, `test/item_catalog_test.dart`, `test/mastery_rule_test.dart`, `test/session_widget_test.dart`
- Plan slice: a particle carries one cloze probe per sentence; `kTransferProbes` gives particles 2; the session's probe pick prefers a sentence with no clear yet, and moves off a sentence once it has clears on 2 different days (D11, PIN-4).
- Done when: `/c/src/flutter/bin/flutter test test/item_catalog_test.dart test/mastery_rule_test.dart test/session_widget_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: [8]
- target repo: superproject

## Phase 7 — The lesson doc and the OPM

### Task 10: Bring the docs up to date
- Files: `docs/japanese-lessons.md`, `docs/opm-lesson-extraction.gen.js`, `docs/opm-lesson-extraction.drawio`, `docs/opm-lesson-extraction.md`, `pipeline/extraction_schemas.py`
- Plan slice: the lesson doc describes the lesson link, the Discuss list, the say cards, the three modes and sentence rotation, naming no bare counts (de-mirror: point at the data files); SD5 and SD6 turn the planned gap boxes for the lesson link, #145 and #146 into built processes and rules, and add the Discuss mark; regenerate the `.drawio` from the generator (PIN-8).
- Done when: `pipeline/.venv/Scripts/python -m pytest pipeline/jp/tests -q`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Deferred validations (backstops)

- Azure scores a spoken sentence, word, form and table reading on Mark's phone, and a spoken clear counts toward Mastered · why deferred: needs the device, the microphone and the deployed function · runner: Mark on the phone after the PR CI is green (A1).
- Mark reviews the 30 particle sentences and the 15 particle English lines, then flips their `reviewed` flags · why deferred: a human review (the judge misses homophone kanji slips) · runner: Mark, after Phase 6 lands.
- Mark's phone record starts fresh: export a backup, clear the record, seed with no lesson ticked (PIN-9) · why deferred: an action on the phone, not code · runner: Mark with Claude, after the plan lands and before daily use.

## Notes / conscious deviations

- Phases are sequential because `session_widget.dart` and `probe_widgets.dart` are shared across Tasks 2, 4, 5, 6 and 9; each phase rebases onto the last.
- #88's on-device transcript fix (a speech-only kanji form per sentence) is not built; the counting path moves to Azure instead (PIN-2).

## Open decisions

None.
