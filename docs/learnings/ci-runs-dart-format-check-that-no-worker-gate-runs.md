---
name: ci-runs-dart-format-check-that-no-worker-gate-runs
description: CI fails on unformatted Dart but the worker gate never runs dart format, so every task drifted
metadata:
  type: project
  keywords: [dart format, set-exit-if-changed, analyze-and-test, CI red, formatting drift, worker gate, End state 15, 80 columns, phase close sweep]
  provenance: code-verified
  slug: ci-runs-dart-format-check-that-no-worker-gate-runs
  phase: 2
  tags: [ci, gate, recurring, jp-sync]
  created: 2026-11-19
---

`.github/workflows/ci.yml` runs `dart format --output=none --set-exit-if-changed .` in the `analyze-and-test` job.
End state 15 names that job as the gate.

The worker gate lists `flutter test`, `flutter analyze`, `pytest` and the rules tests.
It has no format step, so a local green run does not show the red CI step.

In phase 2 the auditors raised this on Task 3 (Major, two seats), Task 5 (Major) and Task 13 (Minor, three rounds running).
Each task fixed its own files in a fix round, and the next round found new drift in the fix commit's own wrapped lines.
A worker's "Ignore for now" list carried the drift forward twice instead of fixing it.
Phase 1 files (`test/jp_event_test.dart` near lines 666 and 676, `lib/components/pages/quiet_room_mastery/jp_event.dart`, `test/jp_store_old_rows.dart`) were still named as unformatted at Task 5's last audit.
The late-fix pass for those files then had an empty diff: its branch tip equalled the integration tip.
That audit read the history and found the three files already formatted by a Task 3 commit, so the stale report most likely came from Task 5 gating before Task 3 merged.
Nobody ran `dart format` at the landed tip, so the state there is grounded by history and blob reading only, not by a run.
An empty late-fix diff is a valid no-op, not a failure.

Recurred in phase 3, from audit text only.
Task seed-2 had a test line 81 columns wide in `test/plan_builder_test.dart` (Minor), and its later pin had no finding.
A Task 15 auditor said `test/speak_lesson_events_test.dart` already failed the check on the base, per the worker report, and asked for a phase-close format.
Task seed-3 then dart-formatted three `expect` calls in that file, so it may be fixed.
The auditors could not run the formatter either, and the tip state is not confirmed by a run.

Recurred in phase 4 on Task 14's new `test/web_routes_smoke_test.dart`, from audit text only.
Round 1 found six code lines wider than 80 columns, for example a 87 column `expect(paths.toSet().length, ...)`.
Round 5 found a hand-written `test('...Notification API...',` line 84 columns wide, added by the previous fix round itself.
The final round had no findings, so the file was probably formatted by then, but no one ran the formatter at the landed tip.
A fix round that adds a long test name re-creates the drift, so the check must run after every fix commit.

Rule: run `dart format --output=none --set-exit-if-changed .` before every commit, and add it to the worker gate list.
A phase-close sweep should format the whole tree once as its own commit.
Beware a stand-alone format commit on a file a sibling task also edits: see [[a-task-edit-to-a-file-a-sibling-task-owns-conflicts-at-pin-transfer]].

Verify still present before acting: `dart format` step in `.github/workflows/ci.yml` (line 41) @ phase 2 (tip 77441d6).
