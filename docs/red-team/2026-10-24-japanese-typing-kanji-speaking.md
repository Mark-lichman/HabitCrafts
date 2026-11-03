# Red Team — Japanese study: typed answers, a kanji option, and speaking practice (2026-10-24)
**Verdict:** ADJUDICATED — every blocker is patched in the plan by an operator ruling; none was re-run by a probe.
**Rounds:** 1

## Attack surface
Spine: claims-vs-reality, executable-proof, coverage-vs-source, consistency-placeholders, dependency-feasibility, intent-vs-plan. Bespoke: gate-runs-fresh, done-when-commands-run, google-fonts-in-widget-tests, hintlocales-api, ruby-roundtrip. Executed in sandbox: executable-proof, gate-runs-fresh, done-when-commands-run, google-fonts-in-widget-tests, ruby-roundtrip. Lead-run: the four drift-guard probes and the backstop check.
Fallback: none (every analyzed probe ran on Explore).
Run note: the first run pointed probes at the plan in the live repo instead of the clone, so all 11 came back off-target (INCOMPLETE). That was a Lead setup error. The rerun used the clone's byte-identical copy and all 11 landed on target.

## Executed proof
- Fresh clone, provisioned → gate green: `flutter test` 12 passed, `pytest pipeline/jp/tests` 175 passed.
- `QuietRoomJapaneseWidget` in a bare `MaterialApp` renders 日本語 in a widget test, with or without Google Fonts runtime fetching → A2 holds.
- `kana_of()` on 8 grammar-style inputs (okurigana, お茶, 日本語を勉強します, 時々, 三日) → 8 of 8 exact. `kana_of('買い物{かいもの}')` → `かいものい物` (wrong) → PIN-11.
- Bare `flutter` in a fresh bash shell → command not found → every Done-when now uses `/c/src/flutter/bin/flutter`.
- `TextField.hintLocales` exists in Flutter 3.44.8 and Android passes it to the keyboard.
- Escape guard: exit 0 before and after both runs.

## Findings
### Major
- [Major] End state 2 could pass with no kanji twins, because Task 4 made them optional → no test required them. Resolution: PIN-9, twins are required for every Japanese field; `REQUIRE_RUBY` flips in Task 5.
- [Major] Task 8 described adding a kanji comparison `judge()` already has, and did not say how `close` routes → Resolution: PIN-10, reuse `kanjiForms`, and show Close in amber with the matching part highlighted, then self-check.
- [Major] Tasks 1 and 7 both list `test/quiet_room_grammar_test.dart`, and Task 7's Done-when skipped it → Resolution: different phases (Task 1 lands first); Task 7's Done-when runs both test files.
- [Major] No named data contract for the kanji twin between producer and consumers → Resolution: PIN-9 names the `_ruby` fields.
- [Major] Task order did not follow the data → Resolution: five phases (foundations, then kanji data, then app), with `deps` edges.
- [Major] `kana_of()` handles only one kanji run per bracket → Resolution: PIN-11, one bracket per kanji word, and the validator rejects a mixed base.
### Minor
- Task 4 moves helpers out of `s03_pairs_textbook.py` without listing that file → added to Task 4's files.
- Task 9 version was vague → resolved from `pubspec.yaml` at land time.
- End state 8 was a judged backstop → now a CI test (`test_judge_applied.py`).
- Task 6 number was missing → now the OPM-sync task.
- The evidence row's "0 wrong keys" was unclear → reworded.
- `pipeline/.venv` exists only after provisioning (env note, not a defect).

## Resolutions applied (grill decisions)
- Kanji twin completeness → `_ruby` twin on every field, parallel lists, required in Task 5 → D9 / PIN-9, End state 2, Tasks 4 and 5.
- Close speech result → amber Close, heard text with the match highlighted, then self-check → D10 / PIN-10, End state 6, Task 8.
- Reading format → one bracket per kanji word, okurigana outside → D11 / PIN-11, Task 4.
- Enforce the OPM → Task 6 adds `stages.py` and `test_opm_sync.py`, keeping `STAGE_IO`, the diagram and the OPL text in step → D12 / PIN-12, End state 9.
- Lesson doc counts → the doc points at the catalog; Cataloging adds one source-file entry per data file, findable by the app's search → D13 / PIN-13, End state 10, Tasks 2 and 10.
- Judged End state 8 → CI test that every judge finding is `applied` → End state 8, Task 5.

## Adjudications

## Residual risk
- A1 (Gboard honors `hintLocales`) and A3 (speech kanji matches the drafted kanji) stay backstops for Mark on the phone.
- Script choice (katakana only for loanwords) has no command check; Mark spot-checks two lessons.
