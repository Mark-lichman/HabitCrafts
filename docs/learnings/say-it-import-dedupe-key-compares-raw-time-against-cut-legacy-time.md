---
name: say-it-import-dedupe-key-compares-raw-time-against-cut-legacy-time
description: The say-it import key still uses raw microsecond time while stored legacy attempts are cut to milliseconds
metadata:
  type: project
  keywords: [_sayItKey, migrateV2Keys, legacyTime, legacyAttempt, say-it import, dedupe key, microseconds, millisecond cut, prepareLog, duplicate attempt, sibling reader]
  provenance: code-verified
  slug: say-it-import-dedupe-key-compares-raw-time-against-cut-legacy-time
  phase: 3
  tags: [jp-sync, open, sibling-reader, platform-gotcha]
  created: 2026-11-20
---

Open at the phase 3 tip. A Task 15 audit marked it `phaseClose`, and no fix is in the tip.

Task 15 cut every legacy attempt time to the millisecond with `legacyTime` in `lib/components/pages/quiet_room_mastery/jp_store.dart`.
`migrateV2Keys` in `lib/components/pages/quiet_room_mastery/study_export.dart` builds its `logged` set from `store.attempts()` through `_sayItKey`.
It builds each candidate key from the raw SharedPreferences time through the same function.
`_sayItKey` formats `at.toUtc().toIso8601String()` with no cut, so a phone time with microseconds no longer equals the stored cut time.
The audit reasons that a cut-short pre-v3 run, then an upgrade, imports one Say-it entry twice.
The audit asserts that case. This servitor read the key code and did not run it.

Suggested fix from the audit: build the time part with `legacyTime(at).toIso8601String()`.
Add a case to the `a run cut short before the flag logs no Say-it attempt twice` test in `test/jp_store_test.dart` with a sub-millisecond first attempt.

Pattern from the same task, resolved before land (recorded as pattern, not live instance): changing a time rule in one reader leaves sibling readers and doc comments on the old rule.
The `prepareLog` docstring said a matched held row keeps its time while the code took the cut time.
The raw-key fallback branch in `prepareLog` had no test, so deleting it left every test green.
Both were absorbed in fix rounds.
Grep every reader of the changed field, and every comment that states the old rule, in the same task.

Related: [[event-time-compares-must-use-event-milliseconds-in-every-reader]], [[pre-v3-study-import-mints-fresh-event-ids-and-uploads-history-twice]].
Verify still present before acting: `_sayItKey` at `lib/components/pages/quiet_room_mastery/study_export.dart` line 468 @ phase 3 (read on the integration tip 6273976, refinery worktree).
