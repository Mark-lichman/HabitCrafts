# Red Team — 2026-11-02-jp-mastery-queue.md (2026-11-02)
**Verdict:** ADJUDICATED — every blocker and open decision was patched into the plan; four were ruled by the operator, the rest are Lead patches not re-verified by a probe re-run.
**Rounds:** 1

## Attack surface
Spine: claims-vs-reality, executable-proof, coverage-vs-source (merged arm, the plan is its own source), consistency-placeholders, dependency-feasibility, intent-vs-plan. Bespoke: dep-resolves (executed), command-diff (executed), data-claims (executed), decomposition-disjoint (analyzed), mastery-spec-soundness (analyzed). Executed in sandbox: executable-proof, dep-resolves, command-diff, data-claims, each in a throwaway clone of a clean clone of `C:/Projects/habitcrafts` at `8457ec2` plus the plan overlay.
Drift-guard spine probes (Lead-run): unguarded-new-mirror vacuous (no inline mirror); default-flip-old-absent vacuous (no default flip; Task 27's test asserts the old number strip absent); guard-split-deps-edge vacuous (Task 4's data tests ride with the data); touched-doc-fact-coverage pass (Tasks 21 and 28 de-mirror every constant to the Dart files).
Fallback: none. Coverage 11 of 11 probes on target, none dropped. Escape guard: exit 0 before and after.
Artifact kind: impl-plan.

## Executed proof
- `sqflite_common_ffi` 2.3.3 to 2.3.5 resolve against `sqflite_common: 2.5.4+3`; 2.3.6 or later does not; an unpinned `sqlite3` floats to 3.5.2 and the ffi tests fail to compile; `sqlite3: 2.9.4` (or 2.4.7) compiles and runs, on Windows with no operator step.
- pub.dev `fsrs` 2.0.1 exists, MIT, FSRS-6.
- `python -m pytest pipeline/jp/tests -q` passes 447 inside a venv with `requirements-test.txt`; the bare system Python has no pytest. A passing `flutter test` with one or two files prints `All tests passed!`.
- Data re-count at `8457ec2`: 620 words, 24 grammar points in lessons 26 to 31, 15 particles, 36 conjugation ideas, 35 pairs, 67 table rows (not about 40); 9 hyphen readings and 108 bracketed readings confirmed; the broad romaji pattern matches about 123 glosses, of which at least 66 are plain English first meanings; only 10 of 15 particle examples contain their `expression` verbatim; 「立入禁止」 enters through the s04 checklist fixture, not the draft.

## Findings
### Critical
- [Critical] Reveal-and-self-mark kinds (conjugation ideas, pairs, table rows) could never reach Mastered under D12 and D17 as written → three non-equivalent readings. Resolution: operator ruling PIN-13 (Got it after the reveal is clear), D22, D12, D17, Tasks 6, 11, 12, 19.
### Major
- Task 4's kanji fix edited the wrong file (A7, End state 13) → `corrections.json` entry on `s04_mari_checklist` `mari.L33.3`, draft first example matched, exemption removed.
- Task 4's romaji rule deleted English meanings and the 150 count did not reproduce → strip only the romaji of the item's own reading; test that English first meanings stay; Context re-measured.
- Particles: one cloze each, so the two-template clause blocked them; 5 of 15 cannot be blanked mechanically → operator ruling PIN-15 (one-template items need only the spaced clears); hand-written `particle_clozes.json` for the 5.
- Seed omitted verb pairs and table rows (Task 5 levels vs D7, End state 7) → level 0 now covers particles, conjugation ideas, pairs and table rows.
- Measured answer-time medians had no delivering task (A2, backstop row 2) → Task 13's debug page shows them; constants retuned by hand.
- Self-grade mapping disagreed across Tasks 10, 11, 12 → PIN-13 and D17.
- Task 8 consumed `SrsState` from Task 7 without a deps edge, and `DayPlan` from Phase 3 → deps [Task 5, Task 6, Task 7]; the store keeps an opaque `DayRecord`.
- End state 14's check never exercised the signed-in cards → `test/quiet_room_cards_test.dart` in Task 27 and the check.
- End state 16 was subjective → median session length 12 to 20 minutes over 14 days and 5 of 7 days finished per seeded week.
- `sqflite_common_ffi` pin alone does not compile → exact `sqflite_common_ffi: 2.3.5` and `sqlite3: 2.9.4`.
- Mastery could not be a pure function of the log (no due flag, seed not in the log) → `Attempt.wasDue`, `Attempt.source`, `seed` events in the log, rebuild restores seeded due days (D26).
- Early practice conflicted between Task 9 and Task 24 → operator ruling PIN-14 (clears ignored, wrongs count), D23.
- Seeded items with no FSRS state left Due order, the warm-up and the cap undefined → D26.
- End state 8's simulator did not exercise the real kinds → Task 16 answers the real catalog through real probes and asserts one Mastered item of every kind.
### needsDecision (all closed)
- "Tap for English" is not a practice probe → D28, a reading aid, never an attempt.
- Duplicate cards → operator ruling PIN-16, keep both.
- Keep-sharp week start undefined → D27, Monday's local day; waits in return mode.
- Missing Task 17 → noted, numbering kept.
- Task 1 could not wait for the voice without editing Task 2's file → Task 2 adds `speakAndWait`, Task 1 deps [Task 2].
- "Every irregular reading" ambiguous for table rows → two different cells, or every cell where fewer than two.

## Resolutions applied (grill decisions)
- Reveal-and-self-mark grading → Got it = clear, Missed it = wrong, hint before reveal = hinted → PIN-13, D22, D12, D17, Tasks 6, 11, 12, 19, guardrails.
- Early practice → a clear changes nothing, a wrong counts as a real wrong → PIN-14, D23, Tasks 6, 9, 23, 24, guardrails, End state 3.
- One-template items → only the four spaced clears, page says "one question kind only" → PIN-15, D4, D24, Tasks 6, 24.
- Duplicate word cards → keep both → PIN-16, D18, D25, Task 4.

## Adjudications
- PIN-13: Got it after the reveal on a probe with no machine check is clear — supersedes D12's "Again for wrong and any reveal" — D12, D17, D22 — operator-ratified (2026-11-02)
- PIN-14: an early-practice clear changes nothing and an early wrong counts — supersedes "early practice recorded but not counted" and "recorded, date unchanged" — Tasks 6, 9, 24 — operator-ratified (2026-11-02)
- PIN-15: one-template items need only the four spaced clears — supersedes D4's unconditional two-template clause — D4, D24 — operator-ratified (2026-11-02)
- PIN-16: identical-duplicate cards stay separate — supersedes Task 4's "identical duplicate cards in one lesson are merged" — D18, D25 — operator-ratified (2026-11-02)
- `sqflite_common_ffi: 2.3.5` and `sqlite3: 2.9.4` — supersedes "pinned like the rest of `pubspec.yaml`" — Task 8, A5 — AI-declared
- Seed set about 797 items with 67 table rows — supersedes "about 770 items … about 40 table rows" — A6, D8 — AI-declared
- D26 seeded-item ordering, D27 Monday week start, D28 "Tap for English" never an attempt — new — AI-declared

## Residual risk
- Minors left as notes: End state 5's wording of the New pause conditions; a pytest `N passed, 1 error` run would print `passed` (the exit code still fails the Done when); the Python simulator numbers in Context assumed about 40 table rows and are dated snapshots, re-measured by Task 16.
- The patched blockers were not re-proved by a probe re-run (hence ADJUDICATED, not CLEARED); the WAR auditors re-check the affected tasks at build time.
