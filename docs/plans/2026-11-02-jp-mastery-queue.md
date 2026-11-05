# Japanese lessons: a mastery record, a capped daily queue, and relaunch

Confirmed by the operator at echo-back on 2026-11-02 (user).

**Evidence consumed**
- `C:/Users/markl/AppData/Local/Temp/claude/C--Users-markl/ee93c723-f089-4789-bb3d-42de53fc0dc5/scratchpad/ux-review/proposals/synthesis-v3.md` (2026-11-02, the design this plan digests, with Mark's rulings section at its top) · read in full
- `.../ux-review/proposals/synthesis-v2.md` (the mastery layer, superseded in its schedule section by v3) · read in full
- `.../ux-review/proposals/synthesis.md` (v1, the navigation options and the first bug table) · read in full
- `.../ux-review/01-navigation-ia.md`, `02-live-walkthrough.md`, `03-bugs.md`, `04-learning-design.md`, `05-mastery-research.md` · read in full
- `.../ux-review/sim_queue.py` and `sim_results.json` (the 120-day simulator, runs A to D) · read; its numbers below are dated snapshots
- `lib/components/pages/quiet_room_grammar/jp_study_kit.dart` `SelfCheck`, `checkTypedAnswer`, `TypedVerdict` at `8457ec2` · read
- `lib/components/pages/quiet_room_practice/quiet_room_practice_widget.dart` `_hintLevel`, `_listen` at `8457ec2` · read
- `lib/components/pages/quiet_room_practice/speech_service.dart` `Judgement`, `stopSpeaking()` at `8457ec2` · read
- `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart` `SpeakScoreLog`, `SpeakAttempt` at `8457ec2` · read
- `lib/components/pages/quiet_room_grammar/quiet_room_drills_widget.dart` `_ConjugationState` at `8457ec2` · read
- `lib/components/pages/quiet_room_today/streak.dart` `recentDays`, `dayOf` at `8457ec2` · read
- `lib/flutter_flow/nav/nav.dart` route table at `8457ec2` · read
- `pubspec.yaml`, `.github/workflows/ci.yml`, `.github/workflows/build-android.yml` at `8457ec2` · read
- `pipeline/jp/publish.py` `run()`, `pipeline/jp/catalog.py`, `pipeline/jp/drafts/` (listing), `pipeline/jp/tests/` (listing) at `8457ec2` · read
- `docs/japanese-lessons.md` ("Regenerating the vocabulary file", "The vocabulary corpus is two families") at `8457ec2` · read
- `docs/plans/2026-10-27-azure-pronunciation-check.md` (house style, PIN-9 anonymous caller, PIN-3 unverified is never wrong) · read
- pub.dev `fsrs` 2.0.1 and `github.com/open-spaced-repetition/dart-fsrs` (2026-11-02) · read via fetch
- `github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm` (FSRS-6 default parameters) · read via fetch

## Context — the gap / problem

Mark studies Japanese daily on his phone with no login (user). He wants "mastery of the ideas and materials independent of the lessons, with an easy way to look up specific topics for repetition as needed" (user). Three things follow from that goal, in his words: material from a lesson that is "done" must keep coming back until it is clear it was mastered; asking for a hint is good and must stay, but a hinted answer must not count toward mastery, and the app needs a way to decide whether a topic is mastered or not yet; organising by lesson is reasonable, but mastery must be assessed independently of the lesson number (user). On the v2 draft he added: there are too many topics to mark all of them for the next day, so the app needs a queue with a daily load limit; some items should come back the next day, but items should also come back weekly or so to keep mastery; mastery must rest on a set number of no-hint clear answers repeated over time; and he wants a technical system for relaunching (returning after a day or a break) that decides which lessons and items to show first (user).

Today nothing in the app can do this. No attempt is persisted anywhere: the grammar screen keeps a pick, a typed answer and a reveal only in widget state (verified: `quiet_room_grammar_widget.dart` `_PracticeState` at `8457ec2`), the only stored study signals are `jp.selfcheck.<pointId>` with the values `can_use_it` and `review_needed` (verified: `jp_study_kit.dart` `SelfCheck` at `8457ec2`), which only the grammar card reads to restore its own pill (nothing schedules from them), plus a speak score log keyed by sentence text and capped at 200 entries (verified: `quiet_room_speak_widget.dart` `SpeakScoreLog.keep` at `8457ec2`). Drill tallies are session-only counters (verified: `quiet_room_drills_widget.dart` `_ConjugationState` `_right`, `_seen` at `8457ec2`). Two grading defects would poison any record: the vocabulary speaking screen counts a speech `close` as right (verified: `quiet_room_practice_widget.dart` `_listen` at `8457ec2`, the `correct || close` branch), and its hint ladder `_hintLevel` is reset on `_next` and never stored with the result (verified: same file at `8457ec2`); the grammar fill-in shows its hint under the box at all times, so no typed grammar answer can be unassisted (verified: `quiet_room_grammar_widget.dart` `_PracticeState` at `8457ec2`, the always-built hint row). The speak drill re-enables the microphone while the phone's own voice is still playing, because `speak()` returns after at most three seconds (verified: `speech_service.dart` `speakWait` at `8457ec2`), and the practice screen's Stop leaves a listen in flight that lands as a miss (verified: `speech_service.dart` `cancel()` at `8457ec2`, which never completes the pending future).

The vocabulary data blocks mastery for a large share of words: at `8457ec2`, 9 readings use an ASCII hyphen instead of ー, 108 readings carry bracketed or parenthesised context (`すいます[たばこを]`), and about 120 glosses begin with a Latin token and a comma, of which only about half are romaji of the reading and the rest are plain English first meanings (dated snapshot, re-measured by red-team 2026-11-02; `03-bugs.md` counted 9, 93 and 39 with a stricter pattern). The extractor that produced `assets/lessons/jp_lessons.json` is not committed (verified: `docs/japanese-lessons.md` "Regenerating the vocabulary file" at `8457ec2`), so the fix is a committed clean-up pass over the asset, not an extractor change. `assets/lessons/jp_grammar.json` is produced by `pipeline/jp/publish.py` `run()` from `pipeline/jp/drafts/L<n>.json` and the catalog from `pipeline/jp/catalog.py` (verified at `8457ec2`); the catalog has one `vocab.L<n>` entry per lesson and no per-word entries (verified: `jp_grammar.json` catalog `type: vocabulary` rows at `8457ec2`).

The scheduler chosen in v3 is FSRS-6 with its published default parameters, desired retention 0.90 and a 90-day interval cap, because it scores a late answer at its real elapsed time, which is what makes a return after a break work with no reset (verified: synthesis-v3.md §B.2). A Dart port exists: pub.dev `fsrs` 2.0.1 from open-spaced-repetition, MIT, a port of py-fsrs with the 21-parameter FSRS-6 set, 160 pub points, about 15.7k downloads, last published about 16 months before 2026-11-02, UTC only, no optimizer (verified: pub.dev and the dart-fsrs README, fetched 2026-11-02). `sqflite` 2.3.3+1 is already a dependency and is used nowhere under `lib/` (verified: `pubspec.yaml` and a grep of `lib/` at `8457ec2`). CI runs `flutter test`, `flutter analyze`, `dart format`, the pipeline pytest and the function tests; it never builds web (verified: `.github/workflows/ci.yml` at `8457ec2`), and `build-android.yml` builds the release apk (verified at `8457ec2`); a `web/` directory exists and the walkthrough reviewer ran a web build (verified: `web/index.html` at `8457ec2`; `02-live-walkthrough.md`).

Simulator snapshots (verified: `sim_queue.py` run of 2026-11-02, seed 7, 835 items, a synthetic learner at 85% clear while retrievable; dated snapshot): from scratch, mean 46.7 answers a day, peak 76, first item Mastered on day 53, 287 Mastered by day 120, median day of mastery 91; with a 10-day break on days 50 to 59, the backlog peaks at 161 and clears in three days with New paused, 232 Mastered by day 120; seeded per ruling 3 (770 items due over 20 days), the session sits at the 20-minute ceiling on 33 of the first 35 days, the backlog peaks at 254 on day 19 and is gone by day 34, 596 Mastered by day 120; with the stretch taken every day it is offered, 436 Mastered by day 120 against 287, at about 4 more answers a day. These are dated snapshots of a synthetic learner; re-measure with the Dart simulator test at the task's base.

## Pivotal constraints

No login screen (the 2026-10-24 plan's floor) · no Azure key in the repo or the app (PIN-2 of the 2026-10-27 plan) · an anonymous Firebase user stays signed out everywhere (PIN-9 of the 2026-10-27 plan) · anything that cannot be scored is unverified, never wrong (PIN-3 of the 2026-10-27 plan) · hiragana first in every learner-facing string (verified: `docs/japanese-lessons.md` "Script rule" at `8457ec2`) · `firebase/functions` untouched · the FlutterFlow-managed files outside `lib/components/pages/quiet_room_*`, `lib/flutter_flow/nav/nav.dart` and `lib/main.dart` are not edited · the record is phone-local; nothing syncs to Firestore in this plan · the `dev_dependencies` and the sqflite family are pinned to exact versions in `pubspec.yaml`, while some runtime packages use caret ranges (verified: red-team 2026-11-02 at `8457ec2`).

## Resolved design tree

| # | Decision | Resolution | Source | Landing class |
|---|----------|------------|--------|---------------|
| D1 | What the app tracks | the idea, not the lesson: a mastery item with its own record; lesson rows are roll-ups of item states; any topic can be looked up and practised on its own | (user) "mastery of the ideas and materials independent of the lessons, with an easy way to look up specific topics" | PIN-1→guardrail + end-state |
| D2 | When repetition stops | never: material keeps returning after its lesson is done until it is clear it was mastered, and a Mastered item keeps returning at a capped interval | (user) ruling and v2 feedback | PIN-2→guardrail |
| D3 | Hints | hints stay available on every probe; a hinted answer earns zero credit toward mastery; two hinted in a row reset the clear count | (user) "asking for a hint is good and must stay, but a hinted answer must not count toward mastery" | PIN-3‡→guardrail |
| D4 | What "mastered" means | a set number of no-hint clear answers repeated over time, realised as four clear answers on four different local days each given while the item was due, the fourth at least 21 days after the previous scored review, no wrong since the first, at least two templates with one production probe where the item has two or more templates (an item with one template needs only the spaced clears, and its page says so, PIN-15), plus per-kind transfer (three sentences for a grammar point, three verbs for a conjugation idea, both directions for a pair, two different cells for a table row or every cell where the row has fewer than two) | (user) "a set number of no-hint clear answers repeated over time"; the numbers [assumed: 4 clears, 21-day gap, 2 templates; if wrong: constants in `mastery_rule.dart`, history replays] | PIN-4→end-state |
| D5 | Daily budget | a 15-minute target and a 20-minute ceiling; at the per-kind estimates about 60 answers at the target and a hard stop at 80; a soft stop at fifteen with Stop and Keep going; the ceiling ends the session and leaves the rest due tomorrow | (user) ruling 2026-11-02 "15 to 20 is a good target" | PIN-5→guardrail + slice (T14, T18) |
| D6 | New items a day | base 8; an opt-in stretch to 12 offered only when today's repairs and due items are done, the backlog before the session was under the gate, no days were missed, and the ceiling leaves room; never forced | (user) ruling 2026-11-02 "a range of 8 to 12 with 12 being the stretch goal" | PIN-6→guardrail + slice (T14) |
| D7 | First launch | every word of lessons 2 to 30, every grammar point of lessons 26 to 31, and all particles, conjugation ideas, verb pairs and table rows enter the FSRS queue as due items spread over the first 20 days in lesson order; none is Mastered; the seed writes no review and no clear, so the first real answer is FSRS review one and clear one | (user) ruling 2026-11-02 "lessons 2 to 31 should still be added to the FSRS review queue and should not be considered mastered yet" | PIN-7‡→guardrail + end-state |
| D8 | The first five weeks after seeding | about 800 items and their returns put the session at the 20-minute ceiling on most of the first five weeks; the operator accepts this | (user) accepted 2026-11-02; (verified: sim_queue.py run C, 2026-11-02, dated snapshot) | PIN-8→backstop |
| D9 | Relaunch | the app decides before the first screen draws: same day resumes or shows the end card; next day builds the plan; after two or more missed days it builds a return plan (a warm-up of 5 to 8 foundational items still likely recalled, ascending retrievability, low-retrievability items capped at a third, New paused) behind a Welcome back screen; first launch seeds then plans | (user) "a technical system for relaunching that decides which lessons and items to show first" | PIN-9→end-state |
| D10 | Weekly resurfacing | a keep-sharp set: on the first session of each week, the 10 Mastered items with the lowest retrievability that are not already due, as real reviews | (user) "items should also come back weekly or so to keep mastery" | PIN-10→slice (T14) |
| D11 | Next-day return | repairs: an item answered wrong is re-asked about 10 minutes later in the same session and again tomorrow; everything else returns on its scheduled date | (user) "some items should come back the next day" | PIN-11→slice (T14, T18) |
| D12 | Scheduler | FSRS-6, default parameters, desired retention 0.90, intervals 1 to 90 days, no learning steps; Good for clear, Hard for hinted and for a self override of a machine check, Again for wrong and for a reveal on a probe that has a machine check, nothing logged for unscored; on a self-graded probe (no machine check) the reveal is the answer check, so Got it is Good and Missed it is Again (PIN-13); the due day is the least-loaded day within 5% of the interval | (verified: synthesis-v3.md §B.2); [assumed: defaults fit Mark; if wrong: export the log, fit offline, ship new constants] | slice (T7) |
| D13 | Scheduler code | vendor dart-fsrs into `lib/components/pages/quiet_room_mastery/fsrs.dart` with its MIT notice, learning steps stripped, golden tests against py-fsrs output; a time-aware Leitner behind the same `Scheduler` interface as the fallback switch | [assumed: the port is faithful to py-fsrs; if wrong: the golden test is red and the Leitner fallback ships] | slice (T7) |
| D14 | Storage | SQLite through the already-declared `sqflite` on Android, tables `items`, `srs`, `mastery`, `attempts`, `days`; the append-only attempt log is the source of truth and the other tables are rebuilt from it; on web an in-memory store with the same interface | (verified: `pubspec.yaml` `sqflite: 2.3.3+1` at `8457ec2`); (user) 2026-11-02 ruling: memory only on web | slice (T8) |
| D15 | Local day | a day runs 04:00 to 04:00 local; one `localDay()` function, used by the store, the plan and the dots | (user) 2026-11-02 ruling: 04:00 | slice (T6) |
| D16 | States | New · Learning (with "n of 4") · Mastered · Shaky (was Mastered, then a wrong or two hinted in a row; regained by two clears on two days, the second after a gap of 7 or more days) | (verified: synthesis-v3.md §A.3, §A.4) | slice (T6) |
| D17 | Grades | clear · hinted · wrong · unscored · self, the same on every screen; a hint level at or above the one that reveals the answer is wrong, not hinted; speech `close` is hinted; `self` is a learner override of a machine check and maps to Hard; on a probe with no machine check (conjugation, pair, table cell, word card) Got it or Knew it after the reveal is clear and Missed it or Not yet is wrong, and a hint taken before the reveal is hinted (PIN-13); a self answer records the review with no credit and leaves the two-hinted-in-a-row count alone (operator ruling ASK-3, 2026-11-03) | (verified: synthesis-v3.md §A.1); PIN-3 | slice (T2, T3, T6) |
| D18 | Vocabulary data | a committed clean-up pass over `assets/lessons/jp_lessons.json`: ー for the hyphen, head word split from bracketed context into a `context` field, a leading gloss token stripped only when it is the romaji of the item's own reading, identical-duplicate cards kept as separate items (PIN-16); particle clozes generated from each particle's example; per-word catalog entries with the image-stem id; prerequisite form ids on grammar points | (verified: the extractor is not committed, `docs/japanese-lessons.md` at `8457ec2`) | slice (T4) |
| D19 | Word id | the image stem (`L30_02`), unique and stable | (verified: `jp_lessons.json` items carry `image` and no id at `8457ec2`) | slice (T4, T5) |
| D20 | Home | Today: the queue sections (Repair · Due · Keep-sharp · New · +stretch), Start, mastered count, kept rate, the 14 dots; Lessons and Topics as tabs; the old hub's search and use strip move to Topics | (verified: synthesis-v3.md §D, option R) | slice (T27) |
| D21 | A heavy start | the seed confirmation has one tick per lesson and any lesson can be skipped for now (its items stay New and enter through the daily intake); when a session reaches the 20-minute ceiling with the backlog still above the gate, the end card offers an opt-in "Catch up: 10 more" | (user) 2026-11-02 ruling: "add the option to do more initially or skip some lessons" | PIN-12→slice (T14, T15, T18, T20) |
| D22 | Self-graded probes | on a probe with no machine check, the learner thinks of the answer, reveals it and grades it: Got it is clear, Missed it is wrong, a hint before the reveal is hinted | (user) 2026-11-02 red-team ruling "Got it = clear" | PIN-13→guardrail + slice (T6, T11, T12, T19) |
| D23 | Early practice | an answer on an item that is not due (from a topic page, an item page, a lesson page or the grammar screen) is recorded; a clear changes neither the schedule nor mastery; a wrong counts as a real wrong: the item is due tomorrow and its clear count resets; a hinted or self answer on an item that is not due changes neither (operator ruling ASK-2, 2026-11-03) | (user) 2026-11-02 red-team ruling "clears ignored, wrongs count" | PIN-14→guardrail + slice (T6, T9, T23, T24) |
| D24 | One-template items | an item whose probes share one template (each particle's one cloze, a one-cell table row) needs only the four spaced clears; its page says "one question kind only" | (user) 2026-11-02 red-team ruling | PIN-15→slice (T6, T24) |
| D25 | Duplicate word cards | the two identical-duplicate pairs stay as separate items with their own image-stem ids and pictures | (user) 2026-11-02 red-team ruling "keep both" | PIN-16→slice (T4) |
| D26 | Seeded items in the queue | a seeded item has a due day and no FSRS state; Due puts stateful items first by ascending retrievability, then seeded items by seed due day and lesson order; the return-mode warm-up and the under-0.5 cap consider stateful items only; the seed is a `seed` event in the log (not an attempt), so a rebuild restores seeded due days | red-team adjudication 2026-11-02, AI-declared | slice (T8, T14, T15) |
| D27 | The week | keep-sharp runs in the first session on or after the local day that is a Monday; in return mode it waits until the backlog is under the gate | red-team adjudication 2026-11-02, AI-declared | slice (T14) |
| D28 | "Tap for English" | the English under an example sentence is a reading aid on the point card, never an attempt | red-team adjudication 2026-11-02, AI-declared | slice (T3, T9) |

## Assumptions ledger

| ID | Assumption | Basis | Blast radius if wrong | Check |
|----|-----------|-------|----------------------|-------|
| A1 | FSRS-6 default parameters fit Mark's memory well enough at 0.90 retention | population defaults; the simulator's synthetic learner forgets exactly as FSRS predicts, which flatters it | kept rate under 0.90, too many or too few reviews; the fix is new constants fitted offline from the exported log | backstop row 4 (kept rate after 30 days) |
| A2 | Per-kind answer times are about 10 s word, 12 s conjugation, 15 s pair or table, 25 s grammar or particle, about 15 s on average with the verdict | estimates; nothing measures `durationMs` today | the 15 and 20 minute marks sit at the wrong answer counts; the debug page shows the measured median per kind once 50 samples exist, and the constants in `plan_builder.dart` are retuned by hand | backstop row 2 (15-minute feel) |
| A3 | Vendoring dart-fsrs (FSRS-6, MIT) is faithful to py-fsrs | the package states it is a port of py-fsrs at a named commit | intervals drift from the reference; the golden test catches it | Task 7's Done when |
| A4 | sqflite has no web backend, and the web build is a review tool, not Mark's device, so an in-memory store on web is enough | (verified: `ci.yml` has no web build at `8457ec2`); `sqflite` platform support | web keeps nothing between loads; if Mark wants web persistence, add `sqflite_common_ffi_web` (resolved 2026-11-02: memory only on web, user) | Task 8's Done when runs the memory store through the same tests |
| A5 | `sqflite_common_ffi: 2.3.5` with `sqlite3: 2.9.4` runs the SQLite store tests on CI's Ubuntu runner and on the Windows dev machine | (verified: red-team 2026-11-02, both resolve against `sqflite_common: 2.5.4+3`, and 2.3.5 ships its own Windows `sqlite3.dll`); an unpinned `sqlite3` floats to 3.x and the ffi tests fail to compile | store tests fail to load | Task 8's Done when |
| A6 | The seed set per ruling 3 is about 797 items: 620 words, 24 grammar points, 15 particles, 36 conjugation ideas, 35 pairs, 67 table rows | (verified: red-team re-count at `8457ec2`, dated snapshot; the Python simulator assumed about 40 rows) | the first-weeks load changes with the count; the plan builder caps it either way | Task 15's test re-counts from the catalog |
| A7 | The `mari.L33.3` example 「立入禁止」 comes from Mari's checklist fixture, and `publish.py` `check_draft` requires the draft's first example to equal it verbatim, with a hard-coded `mari.L33.3` exemption | (verified: red-team 2026-11-02, `pipeline/jp/fixtures/s04_mari_checklist/lesson_bundle.json` and `publish.py` `check_draft`, `run()` at `8457ec2`) | a draft-only edit makes publish skip lesson 33 | Task 4's test asserts no kanji in any hiragana-mode string |
| A8 | Spoken recall of a word is a scorable production probe on the phone once the data is clean | `SpeechService.judge()` exists; about 140 words are blocked until Task 4 lands | words without a scorable production probe can only reach Mastered through two templates, and the detail screen says so | Task 4's Done when; backstop row 1 |
| A9 | Particle clozes can be generated by blanking the `expression` in its one example sentence for 10 of 15 particles; the other 5 need a hand-written cloze | (verified: red-team 2026-11-02 at `8457ec2`) | a particle with no cloze cannot be reviewed | Task 4's test asserts a cloze per particle |

## Non-goals / deferred

A word meaning-choice probe, a typed conjugation probe and a pair direction probe (the mastery rule accepts two templates where no production probe exists and says so on the item screen) · an on-device FSRS optimizer (export the log, fit offline) · FSRS learning steps, SM-2, a weighted mastery score, partial credit for hints, a vacation mode · Firestore sync of the record · iOS · the signed-in shell beyond pointing its two Japanese cards at the session · the vocabulary extractor itself (not committed; the clean-up pass is in scope, re-extraction is not) · lessons 1 and 18 to 21, which have no word sheet · dark-mode mockups · the Say-it track beyond the per-item counts on the detail screen.

## New domain terms · Recommended ADRs

**Mastery item**: the unit the record tracks (a grammar point, a particle, a word, a conjugation idea as form times verb group, a verb pair, a table row). **Probe**: one question template over an item. **Clear / hinted / wrong / unscored / self**: the five grades of one attempt. **Due**: the item's scheduled day has arrived. **Keep-sharp**: the weekly set of Mastered items most at risk. **Stretch**: the opt-in four extra new items. **Soft stop**: the fifteen-minute card. **Seed**: the first-launch due dates for already-studied items. **Local day**: a day from 04:00 to 04:00.

ADRs recommended: (1) "The study record is an append-only attempt log in SQLite; every other study table is a replay of it" (hard to reverse, surprising without context, a real trade-off against SharedPreferences). (2) "FSRS-6 is vendored, not depended on, and a Leitner fallback shares its interface" (a genuine trade-off between fidelity and explainability).

## Commander's Intent

Confirmed by the operator at echo-back on 2026-11-02, including the mechanism latitude (user).

- **Purpose:** mastery of the ideas and materials independent of the lessons, with an easy way to look up specific topics for repetition as needed (user).
- **Method:** spaced repetition that keeps bringing material back, even from a lesson that is done, until it is clear it was mastered, and keeps bringing it back after that; hints stay, and a hinted answer never counts; the app decides mastered or not yet from a set number of no-hint clear answers repeated over time; a daily queue with a 15-minute target and a 20-minute ceiling, in which some items come back the next day and others weekly or so; 8 new items a day with 12 as the opt-in stretch; a relaunch system that decides which lessons and items to show first when Mark returns after a day or a break; on first launch, lessons 2 to 31 enter the review queue without being counted as mastered (user, including the three rulings of 2026-11-02).
- **Mechanism latitude:** Mark named no scheduler, storage engine, screen layout or time estimate, so the following are implementer's choice: the scheduling algorithm (FSRS-6 or a time-aware Leitner) and its parameters, the storage engine and schema, the per-kind time estimates behind the 15 and 20 minute marks, the load-spreading window, the interleave rule, the probe widget layouts and the soft-stop copy; substituting any of these mechanisms while the End states and binding guardrails hold is not a plan deviation and warrants no issue. (drafted from the absence of a ruling; confirmed by the operator at echo-back on 2026-11-02, user)
- **Binding guardrails:** a hinted answer earns zero credit toward mastery, on every screen (PIN-3) · the first-launch seed writes no review and no clear, and no seeded item is Mastered until it earns the full rule from real answers (PIN-7) · an item's mastery state is computed from its own attempts only, never from its lesson number (PIN-1) · a Mastered item never retires from the queue (PIN-2) · the daily budget is a 15-minute target and a 20-minute ceiling, never silently more (PIN-5) · new items are 8 a day and the stretch to 12 is opt-in, never forced (PIN-6) · on a probe with no machine check, Got it after the reveal is clear and Missed it is wrong (PIN-13) · an early-practice clear changes nothing and an early-practice wrong counts (PIN-14) · no login screen · no Azure key in the repo or the app · unverified is never wrong · hiragana first in learner-facing strings.
- **End state:**
  1. Every item's state (New, Learning with n of 4, Mastered, Shaky) is a pure function of its own attempt history, and a lesson's numbers are counts over its items (PIN-1) · check: `/c/src/flutter/bin/flutter test test/mastery_rule_test.dart test/topic_index_test.dart test/lesson_page_test.dart` (prints `All tests passed!`).
  2. An item is Mastered only after four clear answers on four different local days, each while due, the fourth at least 21 days after the previous scored review, with no wrong since the first and the template and transfer clauses met; a wrong on a Mastered item makes it Shaky, and two clears on two days with a 7-day gap regain it (PIN-4) · check: `/c/src/flutter/bin/flutter test test/mastery_rule_test.dart` (prints `All tests passed!`).
  3. A hinted answer, a reveal on a machine-checked probe, a second try, a speech "close" or an early-practice clear never counts toward the four clears; two hinted in a row reset the count; on a self-graded probe Got it after the reveal is clear (PIN-3, PIN-13, PIN-14) · check: `/c/src/flutter/bin/flutter test test/mastery_rule_test.dart` (prints `All tests passed!`).
  4. Mastered items keep a due date forever: the scheduler never exceeds a 90-day interval, and the first session of each week adds the 10 Mastered items most at risk (PIN-2, PIN-10) · check: `/c/src/flutter/bin/flutter test test/fsrs_test.dart test/plan_builder_test.dart` (prints `All tests passed!`).
  5. A daily plan fills repairs, due items and keep-sharp to the 15-minute target and never beyond the 20-minute ceiling except through the opt-in catch-up offered only while the backlog is above the gate (PIN-12), introduces 8 new items, and offers 4 more only when repairs and due are done, the backlog before the session was under the gate, no days were missed, and the ceiling leaves room (PIN-5, PIN-6, PIN-11) · check: `/c/src/flutter/bin/flutter test test/plan_builder_test.dart` (prints `All tests passed!`).
  6. On launch the app resolves same day (resume or end card), next day (today's plan), two or more missed days (the return plan with its warm-up and New paused) and first launch (seed, then plan) without a reset of any item (PIN-9) · check: `/c/src/flutter/bin/flutter test test/relaunch_test.dart` (prints `All tests passed!`).
  7. First launch seeds every word and grammar point of the lessons Mark keeps ticked (by default words 2 to 30 and grammar 26 to 31; an unticked lesson stays New, PIN-12) and all particles, conjugation ideas, pairs and table rows as due items over 20 days, writes no attempt and no clear, and leaves every item unmastered (PIN-7) · check: `/c/src/flutter/bin/flutter test test/seed_test.dart` (prints `All tests passed!`).
  8. A 120-day synthetic learner at 85% clear stays under the target on average, never exceeds the ceiling, carries no steady-state backlog, masters a first item before day 70 and at least 200 by day 120, and is never offered the stretch with repairs or due items left · check: `/c/src/flutter/bin/flutter test test/srs_simulation_test.dart` (prints `All tests passed!`).
  9. Any idea can be found by use, pattern, word, English meaning, conjugation form or counter, shows its state and next review, and can be practised now from its topic page or item page (PIN-1) · check: `/c/src/flutter/bin/flutter test test/topic_index_test.dart test/topics_widget_test.dart test/item_detail_test.dart` (prints `All tests passed!`).
  10. The session shows a hinted answer as right with no credit, re-asks a wrong item in the same session, shows the soft stop at the target and ends at the ceiling with the rest due tomorrow, and the end card offers the stretch only under End state 5's conditions (PIN-5, PIN-6, PIN-11) · check: `/c/src/flutter/bin/flutter test test/session_widget_test.dart` (prints `All tests passed!`).
  11. The vocabulary speaking screen never counts an unverified listen, grades a speech "close" as hinted, carries the hint level in its result, and keeps Next disabled while listening; the speak drill stops its own voice before the microphone opens and cancels a check in flight · check: `/c/src/flutter/bin/flutter test test/quiet_room_practice_test.dart test/quiet_room_speak_test.dart test/speech_service_test.dart` (prints `All tests passed!`).
  12. The grammar fill-in hint sits behind a tap, a revealed answer is recorded as such, and an empty Check is not an attempt · check: `/c/src/flutter/bin/flutter test test/quiet_room_grammar_test.dart` (prints `All tests passed!`).
  13. No reading in `assets/lessons/jp_lessons.json` contains an ASCII hyphen or a bracket, no gloss begins with the romaji of its own reading, no hiragana-mode string in `assets/lessons/jp_grammar.json` contains a kanji, every word has a per-word catalog entry, and every particle has at least one cloze probe · check: `python -m pytest pipeline/jp/tests -q` (prints `passed` and no `failed`).
  14. The Japanese home is Today: the queue sections with their counts, Start, the mastered count, the kept rate and the 14 dots, with Lessons and Topics as tabs, and the signed-in Today and Library cards open the session (D20) · check: `/c/src/flutter/bin/flutter test test/quiet_room_japanese_test.dart test/quiet_room_cards_test.dart` (prints `All tests passed!`).
  15. The whole Flutter suite stays green · gate: `flutter test` (the CI `analyze-and-test` job).
  16. On the phone, the median session length on the debug page over the first 14 days is between 12 and 20 minutes, and Mark finishes the session on at least 5 of 7 days in each of the first five seeded weeks (PIN-8, A2) · backstop: rows 2 and 3.
  17. After 30 days of real use the kept rate is 0.90 or better (A1) · backstop: row 4.

## Build order (for /war)

Phase 1 (record-poisoning fixes and the lesson data, four parallel tasks) → Phase 2 (the record: catalog, grades, scheduler, store, writers behind the existing screens, a debug page) → Phase 3 (plan builder, relaunch and seed, the 120-day simulator test) → Phase 4 (the Review session, its entry points, the doc) → Phase 5 (Topics and the item page) → Phase 6 (the lesson path and lesson page) → Phase 7 (Today replaces the hub, the doc).

## Phase 1 — Record-poisoning fixes and the lesson data

### Task 1: The speak drill stops its own voice and never loses a self-mark
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`, `test/quiet_room_speak_test.dart`
- Plan slice: before opening the microphone, `_speak` calls `SpeechService.instance.stopSpeaking()` and awaits Task 2's `speakAndWait` rather than `speakWait`; a Cancel on the "Checking" panel bumps `_attempt` so a late result is dropped; the drill observes the app lifecycle and retires the attempt on `paused`; the English of a combined example is split alongside its Japanese in `lessonSentences`; the header shows one position counter and the tally moves to the end of the set, which no longer wraps silently; a Got it or Missed it after an unverified result is kept with the attempt in `SpeakScoreLog` so no self-mark is lost; the sentence box has a fixed minimum height so Next does not move. Unverified stays never wrong.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_speak_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 2]
- target repo: superproject

### Task 2: The vocabulary speaking screen grades honestly
- Files: `lib/components/pages/quiet_room_practice/quiet_room_practice_widget.dart`, `lib/components/pages/quiet_room_practice/speech_service.dart`, `test/speech_service_test.dart`, `test/quiet_room_practice_test.dart`
- Plan slice: `SpeechService.cancel()` completes the pending `listenOnce` future with an empty unverified result and an attempt token makes a late `_stt.stop()` a no-op for a newer attempt; `SpeechService` gains `speakAndWait(text)`, which completes on the voice's completion handler with a cap (defined-but-not-yet-emitted for Task 1, which deps on this task); `_listen` stops any playing voice first, counts only correct, close and wrong toward the tally, treats `close` as hinted rather than right (PIN-3), and carries `_hintLevel` and a revealed flag in the result it hands on; Next is disabled while listening; the app lifecycle cancels a listen on `paused`; raw recognizer codes map to plain sentences; the picture deck is shuffled without replacement and the screen shows a position and an end; the no-microphone case shows the same self-check contract as the speak drill. Add the first widget test file for this screen using `test/jp_screen_harness.dart`.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_practice_test.dart test/speech_service_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 3: The grammar fill-in hint goes behind a tap
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart`, `test/quiet_room_grammar_test.dart`
- Plan slice: in `_PracticeState` the item's hint renders only after a "Show hint" tap and the tap is remembered on the item; "Show answer" sets a revealed flag ("Tap for English" on an example sentence stays a reading aid, D28); Check on an empty box does nothing and says so; `_PointCardState` and `_PracticeState` keep themselves alive across the lesson scroll (`AutomaticKeepAliveClientMixin`) so a pick, a typed answer and a reveal survive scrolling; the screen's practice result object carries picked, typed verdict, hint taken, revealed and self-mark so Phase 2's writer can grade it (PIN-3). No visual change beyond the hint control.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_grammar_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 4: The lesson data can be mastered
- Files: `pipeline/jp/vocab_clean.py`, `pipeline/jp/tests/test_vocab_clean.py`, `pipeline/jp/publish.py`, `pipeline/jp/corrections.json`, `pipeline/jp/particle_clozes.json`, `pipeline/jp/catalog.py`, `pipeline/jp/tests/test_pipeline.py`, `pipeline/jp/tests/test_catalog_sources.py`, `pipeline/jp/drafts/L33.json`, `assets/lessons/jp_lessons.json`, `assets/lessons/jp_grammar.json`
- Plan slice: a committed, idempotent `vocab_clean.py` rewrites `assets/lessons/jp_lessons.json` in place: `-`, `－` and `‐` inside a reading become ー; a bracketed or parenthesised part of a reading moves to a new `context` field and the reading keeps the head word (a reading that is only a bracket, such as `さわります[に]`, keeps the verb); a leading gloss token followed by a comma is stripped only when it equals the item's own reading converted to Hepburn romaji (long vowels and macrons normalised), so English first meanings stay; identical-duplicate cards stay separate items with their own ids (PIN-16); `ふくしゅうします` loses its `groupUncertain` flag; every item gains `id` equal to its image stem (D19). `publish.py` emits one cloze probe per particle by blanking its `expression` in its `example` where it appears verbatim, and from the committed hand-written `pipeline/jp/particle_clozes.json` for the rest (A9); passes the s04 `requires_forms` through as `prereqs` (mapped to `conj.<form>` ids) on each point; and fixes the `mari.L33.3` kanji with a `corrections.json` entry on `s04_mari_checklist` item `mari.L33.3` field `example`, the draft's first example updated to match and the `mari.L33.3` exemption in `check_draft` removed (A7). `catalog.py` emits one catalog entry per word (id, reading, gloss, lesson, verb group) in addition to the per-lesson rows. The tests assert, against the shipped assets: no hyphen or bracket in any reading, no gloss that begins with the romaji of its own reading, every English first meaning that the old broad pattern matched still present, no kanji in any hiragana-mode string, an `id` on every word, a catalog entry per word, a cloze per particle, and that `vocab_clean.py` is a no-op on its own output. Regenerate both assets.
- Done when: `python -m pytest pipeline/jp/tests -q` (prints `passed` and no `failed`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 2 — The record: catalog, grades, scheduler, store, writers

### Task 6: Attempts, grades, the mastery rule and the local day
- Files: `lib/components/pages/quiet_room_mastery/attempt.dart`, `lib/components/pages/quiet_room_mastery/mastery_rule.dart`, `lib/components/pages/quiet_room_mastery/local_day.dart`, `test/mastery_rule_test.dart`, `test/local_day_test.dart`
- Plan slice: `attempt.dart` defines `ItemKind`, `Grade` (clear, hinted, wrong, unscored, self), `Source`, `Attempt` (item, probe, template, production flag, self-graded flag, atUtc, localDay, grade, FSRS rating or null, hint level, revealed, `wasDue`, `source` (review, keepSharp, early, sayIt), elapsed days, R and S before and after, duration, session id) and the grade mapping to an FSRS rating (D17, D22, PIN-3, PIN-13), including "a hint level at or above the revealing one is wrong" and "hinted earns no mastery credit". `mastery_rule.dart` defines `MasteryStatus`, `MasteryState` and the pure `masteryAfter(MasteryState, Attempt, ItemDefLike)` implementing D4 and D16: four clears on four local days while due, the 21-day gap against the last scored review, no wrong since the first, two hinted in a row reset, two templates with one production where the item has two or more templates (PIN-15), per-kind transfer, Shaky and its regain, one clear per item per day, early practice per PIN-14 (a clear changes nothing, a wrong counts, a hinted or self answer changes nothing (ASK-2)), unscored changes nothing, Say-it never counts. `local_day.dart` defines `localDay(DateTime)` with the 04:00 boundary (D15) and a `Clock` seam. Tests from attempt lists cover every clause and the boundary across a DST change in the style of `test/streak_test.dart`.
- Done when: `/c/src/flutter/bin/flutter test test/mastery_rule_test.dart test/local_day_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 7: FSRS-6 vendored, with a Leitner fallback behind one interface
- Files: `lib/components/pages/quiet_room_mastery/fsrs.dart`, `lib/components/pages/quiet_room_mastery/scheduler.dart`, `lib/components/pages/quiet_room_mastery/leitner.dart`, `test/fsrs_test.dart`, `test/fixtures/fsrs_golden.json`
- Plan slice: `scheduler.dart` defines `SrsState` and the `Scheduler` interface (`first`, `review` with a same-day flag, `retrievability`, `nextDue` with load spreading over a `loadByDay` map, D12). `fsrs.dart` is the vendored dart-fsrs scheduler and parameter set with its MIT notice, learning and relearning steps removed, desired retention and maximum interval as named constants (0.90 and 90), and the post-lapse stability never above the old one (D13). `leitner.dart` is the time-aware fallback (boxes at 1, 3, 7, 14, 30, 60, 90 days; clear up one box, two when more than 50% late; hinted stays; wrong down two). `test/fixtures/fsrs_golden.json` holds a 40-review sequence of ratings and gaps with the stability, difficulty and interval py-fsrs produced for it (recorded once, dated in the file); the test reproduces it to 1e-6 and checks the properties: Good never lowers stability, Again never raises it, intervals stay in 1 to 90, retrievability at the stability equals 0.9.
- Done when: `/c/src/flutter/bin/flutter test test/fsrs_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 5: The item catalog with stable ids and probes
- Files: `lib/components/pages/quiet_room_mastery/item_catalog.dart`, `test/item_catalog_test.dart`
- Plan slice: `ItemCatalog.load()` builds every `ItemDef` from the two lesson assets through `JpGrammarData` and the word file: grammar points (`mari.L31.3`, probes = its practice items and its examples), particles (`mari.particle.14`, probes = the clozes from Task 4), words (id = image stem, probes = card recall, spoken recall and the reading typed), conjugation ideas (`conj.<form>.g<group>`, probes = the verbs of that group), verb pairs (the catalog id, both directions), table rows (`ref.<table>.<row>`, probes = the cells, irregular readings flagged), each with its kind, lesson, prerequisite level (0 particles, conjugation ideas, verb pairs and table rows, 1 words of a lesson, 2 grammar of a lesson), its production flags and its prerequisites. The test asserts the counts at the shipped assets as a re-measured snapshot (never a hard-coded 835), the uniqueness of ids, that every grammar point has at least three sentence probes, and that every item has at least one probe.
- Done when: `/c/src/flutter/bin/flutter test test/item_catalog_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 6]
- target repo: superproject

### Task 8: The store: SQLite on the phone, memory on web, replay, migration, export
- Files: `lib/components/pages/quiet_room_mastery/jp_store.dart`, `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart`, `lib/components/pages/quiet_room_mastery/jp_store_memory.dart`, `lib/components/pages/quiet_room_mastery/study_export.dart`, `pubspec.yaml`, `test/jp_store_test.dart`
- Plan slice: `JpStore` is the interface (append an attempt, append a `seed` event (item and due day, not an attempt, D26), read and write `SrsState` and `MasteryState`, due items on or before a day, load by day, a `DayRecord` per local day holding the plan as opaque JSON with its position and completion so Phase 3's `DayPlan` serialises into it, last day, rebuild from the log and the seed events, import and export); `JpStoreSqlite` implements it on `sqflite` with tables `items`, `srs`, `mastery`, `attempts`, `days`, indexes on `srs.dueDay` and `attempts.itemId`, one transaction per answer, schema version 1 with `onUpgrade` (D14); `JpStoreMemory` implements it in memory and is the implementation on web (A4). `study_export.dart` writes the log as JSON Lines with a header line and reads it back through the replay. The one-time migration imports `jp.selfcheck.*` (`review_needed` marks the item due today; `can_use_it` is kept as a note) and `jp.speak.scores` as Say-it history mapped from sentence text to its point, leaving the keys in place for one release. Add `sqflite_common_ffi: 2.3.5` and `sqlite3: 2.9.4` as exact dev dependencies, so the SQLite implementation runs in `flutter test` through the ffi factory (A5; 2.3.6 or later needs `sqflite_common` 2.5.5 or later); the same test suite runs against both implementations.
- Done when: `/c/src/flutter/bin/flutter test test/jp_store_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 5, Task 6, Task 7]
- target repo: superproject

### Task 9: The grammar screen writes attempts
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart`, `test/quiet_room_grammar_test.dart`
- Plan slice: every practice answer, "Show answer" reveal and self-check pill on the grammar screen writes one `Attempt` through `JpStore` at answer time with its template, hint taken and revealed flags (D17), and the item's `SrsState` and `MasteryState` update in the same transaction; an answer on an item that is not due is `source: early` and follows PIN-14 (a clear changes neither the schedule nor mastery, a wrong counts as a real wrong, a hinted or self answer changes neither (ASK-2)). The screen's `JpStore` is injectable for the test, which asserts the written grades for a clear, a hinted, a revealed and an empty check.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_grammar_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 8]
- target repo: superproject

### Task 10: The vocabulary speaking screen writes attempts
- Files: `lib/components/pages/quiet_room_practice/quiet_room_practice_widget.dart`, `test/quiet_room_practice_test.dart`
- Plan slice: every verdict, self-mark and skip on the practice screen writes one `Attempt` with its hint level and revealed flag; `close` writes hinted, `unverified` with nothing heard writes unscored, a self Got it on an unverified transcript writes self (D17); the store is injectable; the test asserts each mapping.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_practice_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 8]
- target repo: superproject

### Task 11: The speak drill and the drills write attempts
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`, `lib/components/pages/quiet_room_grammar/quiet_room_drills_widget.dart`, `test/quiet_room_speak_test.dart`, `test/quiet_room_drills_test.dart`
- Plan slice: the speak drill writes one `Attempt` per scored or self-marked sentence against the sentence's grammar point with `Source.speak` (the Say-it track; it never counts toward the four clears, D4); the conjugation drill writes one attempt per Got it or Missed it against the conjugation idea `conj.<form>.g<group>` with the verb as the probe; the pairs drill writes one per reveal and self-mark against the pair with the direction as the template; the reference tables write one per revealed cell against the row; on these self-graded probes Got it is clear and Missed it is wrong (PIN-13). `SpeakScoreLog` stays as the tuning aid. The stores are injectable; the tests assert item and probe ids on the written attempts.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_speak_test.dart test/quiet_room_drills_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 8]
- target repo: superproject

### Task 12: Word cards get Knew it and Not yet, and write attempts
- Files: `lib/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart`, `test/quiet_room_lesson_test.dart`
- Plan slice: after a card reveals its meaning, two quiet pills, Knew it and Not yet, write a clear or a wrong attempt against the word (card recall has no machine check, so the self-grade is the grade, PIN-13); the card shows the new `context` field under the head word; the last-opened lesson is remembered. Add the first widget test file for this screen using `test/jp_screen_harness.dart`.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_lesson_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 8]
- target repo: superproject

### Task 13: A debug page lists the record
- Files: `lib/components/pages/quiet_room_mastery/mastery_debug_widget.dart`, `lib/flutter_flow/nav/nav.dart`, `lib/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart`, `test/mastery_debug_test.dart`
- Plan slice: a plain list of items by state with their next due day, the next 14 days of load, the attempt count, the median answer time per kind once 50 samples exist (A2), the median session length, and the Rebuild from log, Export and Import actions, reached from a quiet "Study record" link at the bottom of the current hub and registered as a route. Nothing else on the hub changes in this phase.
- Done when: `/c/src/flutter/bin/flutter test test/mastery_debug_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 8]
- target repo: superproject

## Phase 3 — The plan builder, relaunch and seed, the simulator test

### Task 14: The daily plan builder
- Files: `lib/components/pages/quiet_room_mastery/plan_builder.dart`, `test/plan_builder_test.dart`
- Plan slice: `buildPlan({day, budget, daysMissed, store, catalog, clock})` returns a `DayPlan` with ordered `QueueEntry` rows and sections: Repair (yesterday's wrongs, and a slot for today's wrongs about 10 minutes later, PIN-11), Due (stateful items by ascending retrievability, ties by prerequisite level then lapses, then seeded items with no FSRS state by seed due day and lesson order, D26, interleaved so no more than two in a row share a kind or a lesson, one entry per item), Keep-sharp (first session on or after Monday's local day, waiting in return mode until the backlog is under the gate, D27: the 10 Mastered items with the lowest retrievability not already due, PIN-10), New (base 8 in lesson order with prerequisites: particles and forms sprinkled first, words of a lesson before its grammar, a point after the form it uses, PIN-6). The budget is the 15-minute target and the 20-minute ceiling as named constants with per-kind cost estimates (A2) and a hard stop at the ceiling (PIN-5); New is skipped when the backlog before the session exceeds 1.5 times the target, when `daysMissed` is 2 or more, or when the target is spent; `stretchOffer` is true only when repairs and due are done, the gate held, no days were missed and the ceiling leaves room for four introductions (PIN-6); `catchUpOffer` is true when the session reached the ceiling and the backlog is still above the gate (the seeded first weeks or a return), and offers one more block of 10 due items past the ceiling, opt-in only (PIN-12); return mode adds the warm-up (5 to 8 level-0 or high-reuse stateful items with retrievability 0.6 to 0.85) and caps stateful items under 0.5 at a third of the plan (PIN-9, D26); unscored entries return to the end of their section once. Tests cover each rule with an injected clock and a memory store.
- Done when: `/c/src/flutter/bin/flutter test test/plan_builder_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 15: Relaunch and the first-launch seed
- Files: `lib/components/pages/quiet_room_mastery/relaunch.dart`, `lib/components/pages/quiet_room_mastery/seed.dart`, `test/relaunch_test.dart`, `test/seed_test.dart`
- Plan slice: `onLaunch(now, store, catalog, settings)` returns `LaunchDecision.firstLaunch | done | resume | today | welcomeBack` per D9 using `localDay`, the last `DayPlan` and `buildPlan`, and never mutates an item's `SrsState` on return. `seedFromLessons(day, store, catalog, {lessons})` takes the set of lessons Mark keeps ticked (default every word lesson 2 to 30 and grammar 26 to 31, PIN-12) and writes a due date only for every word and grammar point of those lessons and every level-0 item; an unticked lesson's items stay New and arrive through the daily intake in lesson order; spread over 20 days in lesson order, as `seed` events with no attempt, no FSRS state and no clear (PIN-7, D26); it imports the v2 keys through the store's migration. Tests: each launch case; an unticked lesson seeds nothing and its items stay New; the seed writes zero attempts, leaves every seeded item unmastered with zero clears, spreads the due days, and a first real clear on a seeded item is clear one of four.
- Done when: `/c/src/flutter/bin/flutter test test/relaunch_test.dart test/seed_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 14]
- target repo: superproject

### Task 16: The 120-day simulator test
- Files: `test/srs_simulation_test.dart`, `test/support/synthetic_learner.dart`
- Plan slice: a synthetic learner (85% clear while retrievable, otherwise the chance tracks retrievability, the rest 45% hinted and 55% wrong) answers the real catalog's items through their real probes and templates and runs 120 days through `buildPlan`, the scheduler and the mastery rule with a memory store and an injected clock, in four runs: from scratch, with a 10-day break, seeded per `seedFromLessons`, and with the stretch taken whenever offered. Assertions: mean answers under the target, peak at most the ceiling, zero backlog in steady state from scratch, a first Mastered before day 70, at least 200 Mastered by day 120 from scratch, the seeded run clears its backlog before day 45, the stretch is never offered with repairs or due items left, and at least one item of every kind (grammar point, particle, word, conjugation idea, pair, table row) is Mastered by day 120 in the seeded run. The test prints the four run summaries so the numbers in Context can be re-measured.
- Done when: `/c/src/flutter/bin/flutter test test/srs_simulation_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 14, Task 15]
- target repo: superproject

## Phase 4 — The Review session and its entry points

### Task 19: Probe widgets
- Files: `lib/components/pages/quiet_room_mastery/probe_widgets.dart`, `test/probe_widgets_test.dart`
- Plan slice: one widget per probe kind, each reporting a graded `Attempt` draft (grade, template, hint level, revealed): choose, typed fill (through `checkTypedAnswer`, hint behind a tap), word recall (picture, say it through `SpeechService` or type the reading, hint ladder with the revealing level graded wrong), conjugation reveal with Got it and Missed it, pair reveal in either direction, table cell reveal (each self-graded per PIN-13), and the spoken sentence through `PronunciationService` for the Say-it track. Every widget shows the item's state pill and its n of 4. Tests drive each widget to each grade with fake services.
- Done when: `/c/src/flutter/bin/flutter test test/probe_widgets_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 18: The session runner
- Files: `lib/components/pages/quiet_room_mastery/session_widget.dart`, `test/session_widget_test.dart`
- Plan slice: `SessionWidget(plan, store, clock)` walks the `DayPlan` one entry per screen with the section label and position ("Due · 12 of 42"), writes every attempt through the store at answer time, shows the verdict cards (Clear with the new interval; Right with a hint, no credit; Not this time; Mastered when the fourth clear lands), re-asks a wrong item about 10 minutes later in the same session (PIN-11), shows the soft stop when the running estimate passes the 15-minute target with Stop and Keep going, ends at the 20-minute ceiling leaving the rest due tomorrow (PIN-5), and ends on a quiet card with the day's counts, the mastered-today list, the 14 dots from `recentDays` over session-completion days, One more (10) inside the ceiling, "Catch up: 10 more" past the ceiling only when `catchUpOffer` holds and only on a tap (PIN-12), and the "4 more new" offer only when `stretchOffer` holds (PIN-6). Tests cover the section order, the no-credit card, the repair re-ask, the soft stop, the ceiling, and the stretch offer conditions.
- Done when: `/c/src/flutter/bin/flutter test test/session_widget_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 19]
- target repo: superproject

### Task 20: The entry points: Today card on the hub, Welcome back, the seed confirmation
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart`, `lib/components/pages/quiet_room_mastery/welcome_back_widget.dart`, `lib/components/pages/quiet_room_mastery/seed_confirm_widget.dart`, `lib/flutter_flow/nav/nav.dart`, `test/quiet_room_japanese_test.dart`, `test/welcome_back_test.dart`
- Plan slice: the `/` route for a signed-out user runs `onLaunch` before building; `firstLaunch` opens the seed confirmation (one tick per lesson, word lessons 2 to 30 and grammar lessons 26 to 31 ticked by default from `jp.grammar.lastLesson` and the word range, any lesson can be unticked to skip it for now, one Confirm, PIN-12) and then the hub; the confirm calls `seedFromLessons` with `SharedPreferences.getInstance()` and the decoded `assets/lessons/jp_grammar.json`, so the v2 keys import (Task 15 leaves both optional, but they are passed together or not at all); `welcomeBack` opens the Welcome back screen (days away, items due, days to catch up at the target, New paused, badges now Shaky with the regain rule, one loud Start); `today`, `resume` and `done` open the hub with a Today card above the hero that names the queue sections and their counts ("Repair 3 · Due 42 · Keep-sharp 10 · New 8 · +4 stretch"), the 15-to-20 minute line and Start or Resume, or the end state. The old hero and rows stay below it until Phase 7. Routes registered in `nav.dart`.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_japanese_test.dart test/welcome_back_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 18]
- target repo: superproject

### Task 21: The lesson doc describes the record and the session
- Files: `docs/japanese-lessons.md`, `docs/testing/journeys.md`
- Plan slice: a new section on the study record (what an item is, the five grades, the mastery rule by name, the budget, the stretch, the seed, relaunch) that points at `mastery_rule.dart`, `plan_builder.dart` and `seed.dart` for every constant and at the debug page for every count, restating no number that the code or the assets define (de-mirror; touched-doc rule 8); update "What ships in the app" for the data fields `id` and `context`; a J13 journey "Daily Japanese review" in `journeys.md` in the existing journey shape.
- Done when: None — doc only; reviewed at audit.
- requiresTest: false
- requiresPackaging: false
- deps: [Task 20]
- target repo: superproject

## Phase 5 — Topics and the item page

### Task 22: The topic index
- Files: `lib/components/pages/quiet_room_mastery/topic_index.dart`, `test/topic_index_test.dart`
- Plan slice: `TopicIndex` over the catalog and the store: search across catalog titles, summaries and search terms, word readings and glosses, form names and counters; browse sets for By use (the 30 uses), Verb forms, Verb groups, Counters and tables, Words by lesson, Due today, Shaky and Not yet known; a `Topic` is any set of items with counts by state (never a bare percentage) and a pill per D16's roll-up. Tests: a search for an English gloss lands on the word, a use lists its points and particles, and the roll-up pill rules.
- Done when: `/c/src/flutter/bin/flutter test test/topic_index_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 24: The item page
- Files: `lib/components/pages/quiet_room_mastery/item_detail_widget.dart`, `test/item_detail_test.dart`
- Plan slice: the item's state pill and n of 4, the next review date, the probes seen clear, what remains to Mastered or to regain, the Say-it counts, the attempt history (date, grade, hint level, probe, whether it counted), a "no production probe yet" line where the kind has none (A8), a "one question kind only" line where the item has one template (PIN-15), and Practice now, which runs a one-item session as early practice per PIN-14. Reached from any list.
- Done when: `/c/src/flutter/bin/flutter test test/item_detail_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 23: The Topics screen and topic page
- Files: `lib/components/pages/quiet_room_mastery/topics_widget.dart`, `lib/components/pages/quiet_room_mastery/topic_page_widget.dart`, `lib/flutter_flow/nav/nav.dart`, `test/topics_widget_test.dart`
- Plan slice: the Topics tab with one search box and the browse sets, result rows with state pills and next review; the topic page with its counts, its items with state and next due, Related topics, and one loud Practice this topic that runs the session over those items, due first, early answers per PIN-14 (PIN-1); routes for Topics, the topic page and the item page registered in `nav.dart`.
- Done when: `/c/src/flutter/bin/flutter test test/topics_widget_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 22, Task 24]
- target repo: superproject

## Phase 6 — The lesson path and lesson page

### Task 25: The lesson page
- Files: `lib/components/pages/quiet_room_mastery/lesson_page_widget.dart`, `test/lesson_page_test.dart`
- Plan slice: one page per 第N課: its title, the counts over its items ("0 mastered · 3 learning · 2 new"), its grammar points with state and n of 4, its words with state where a sheet exists and a plain "no word sheet" line where none does, the Say-it counts, Review these (the session over its due items), and Read the whole lesson (the existing grammar screen).
- Done when: `/c/src/flutter/bin/flutter test test/lesson_page_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 26: The lesson path replaces the number strips
- Files: `lib/components/pages/quiet_room_mastery/lessons_path_widget.dart`, `lib/flutter_flow/nav/nav.dart`, `lib/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart`, `test/lessons_path_test.dart`
- Plan slice: a vertical list 第26課 to 第50課 with title, what each holds and its mastery counts in place of Done, the current lesson as the loud row, and a Words-only section for 第2課 to 第25課; the hub's "Grammar lessons" and "Vocabulary" rows open the path instead of a fixed lesson; routes in `nav.dart`.
- Done when: `/c/src/flutter/bin/flutter test test/lessons_path_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: [Task 25]
- target repo: superproject

## Phase 7 — Today replaces the hub

### Task 27: The Japanese home is Today
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart`, `lib/components/pages/quiet_room_today/quiet_room_today_widget.dart`, `lib/components/pages/quiet_room_library/quiet_room_library_widget.dart`, `test/quiet_room_japanese_test.dart`, `test/quiet_room_cards_test.dart`
- Plan slice: `QuietRoomJapaneseWidget` becomes Today (D20): the session card with the queue sections and Start, the mastered count, the kept rate over 30 days, the 14 dots, quiet links, and a bottom nav of Today, Lessons and Topics using `go`, with the old hero, rows, search and use strip removed (search and By use live in Topics); the signed-in Today "DAILY LESSON" card and the Library "Japanese vocabulary" card open the session instead of 第30課. The tests assert the section counts render from a memory store, that no number strip remains on the home, and (`quiet_room_cards_test.dart`) that the signed-in Today card and the Library card push the session route and no longer push `QuietRoomLessonWidget`.
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_japanese_test.dart test/quiet_room_cards_test.dart` (prints `All tests passed!`)
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 28: The lesson doc reflects the final shape
- Files: `docs/japanese-lessons.md`
- Plan slice: the screen list and the open-work section describe Today, Lessons, Topics, the item page and the session as the shipped shape, pointing at the code for constants and at the debug page for counts (de-mirror, rule 8); the "Regenerating the vocabulary file" section says the committed clean-up pass in `pipeline/jp/vocab_clean.py` is the step after any re-extraction.
- Done when: None — doc only; reviewed at audit.
- requiresTest: false
- requiresPackaging: false
- deps: [Task 27]
- target repo: superproject

## Deferred validations (backstops)

- A real session on the phone with the real microphone and real Azure scoring writes the expected grades (clear, hinted, wrong, unscored) for a word and a sentence, and the SQLite file survives an app restart and the v2-key migration (A5, A8) · why deferred: needs the device, the microphone and the deployed scoring function · runner: Mark on the phone after Phase 4 lands, with the debug page open; never before the PR's CI is green (the no-install-before-CI-green rule).
- The median session length on the debug page over the first 14 days is between 12 and 20 minutes (A2, PIN-5) · why deferred: answer times are estimates until the log holds 50 samples per kind · runner: Mark on the phone for two weeks after Phase 4; the debug page shows the measured medians per kind, and the estimates in `plan_builder.dart` are retuned once by hand.
- The first five seeded weeks are bearable: Mark finishes the session on at least 5 of 7 days in each week (PIN-8, A6) · why deferred: the seed runs once, on the phone · runner: Mark during the first five weeks after Phase 4; if it is not bearable, the seed spread or the seed set is the lever (resolved 2026-11-02: unticked lessons and the opt-in catch-up, PIN-12).
- After 30 days of real use the kept rate (clear share of maintenance and keep-sharp reviews) is 0.90 or better (A1) · why deferred: needs 30 days of real answers · runner: Mark reads the kept rate on Today after 30 days; under 0.85 for two weeks, the cap drops to 60 days and the log is exported for an offline fit.
- The web build runs the same screens on the memory store and loses nothing it should keep in one sitting (A4) · why deferred: no CI web build exists · runner: the Lead, one `flutter build web` smoke after Phase 4.

## Notes / conscious deviations

- The template's literal headings and the Done-when law's literal `None — <basis>` form keep their own punctuation; the prose, the tags and the tables use none of it. The `[assumed:` tag is written as `[assumed: <default>; if wrong: <consequence>]`.
- Task numbering follows v3's build order, so within Phase 2 and Phase 5 the tasks are listed in wave order rather than numeric order (Task 6 and Task 7 before Task 5; Task 22 and Task 24 before Task 23).
- The vocabulary extractor is not committed, so Task 4 is a clean-up pass over the asset with its own idempotence test, not an extractor change; a future re-extraction runs the pass afterwards (Task 28 records this).
- The Python simulator in the review folder is the reference the Dart simulator test is checked against once; after that the Dart test is canonical and the Python script is not part of the gate.
- FSRS parameters, the budget constants (target, ceiling, base, stretch, gate), the mastery constants (4, 21, 7) and the interval cap each live in exactly one Dart file; both docs point at those files rather than restating the numbers (rule 8).
- `requiresPackaging` is false throughout: the repo has no Dockerfile (verified at `8457ec2`); the apk build is `build-android.yml`.
- The anonymous-caller and Azure floors of the 2026-10-27 plan are carried as constraints, not re-decided.
- Mark's rulings of 2026-11-02 are pins PIN-5, PIN-6, PIN-7 and PIN-12, and his red-team rulings are PIN-13 to PIN-16; PIN-3 and PIN-7 are ‡-marked for the twice-read at echo-back. D26 to D28 are red-team adjudications (AI-declared).
- There is no Task 17: the number was dropped in drafting and the others are kept so cross-references stay stable.
- The pipeline Done-when runs `python -m pytest` with the test requirements installed (`pipeline/jp/requirements-test.txt`), as CI does; the bare system Python on the Windows dev machine has no pytest.
- The mastery clause numbers in D4 (4 clears, 21 days, 2 templates) and the states in D16 are the design's realisation of Mark's "set number of no-hint clear answers repeated over time"; they are constants, and the record replays, so Mark can change them later without losing history. Mark accepted them as the first setting at echo-back on 2026-11-02 (user).

## Open decisions

None.

Resolved at echo-back on 2026-11-02 (user): web keeps the in-memory store only; the local day boundary is 04:00; the mastery constants (4 clears, 21-day final gap, 2 templates, 7-day regain) are the first setting; the signed-in shell gains no Japanese entry, its two cards open the session; a heavy start is handled by an opt-in catch-up past the ceiling and by unticking lessons at the seed confirmation (PIN-12), with the two-tranche seed kept as a fallback if those are not enough.
