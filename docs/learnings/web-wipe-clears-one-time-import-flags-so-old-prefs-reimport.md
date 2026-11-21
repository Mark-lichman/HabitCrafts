---
name: web-wipe-clears-one-time-import-flags-so-old-prefs-reimport
description: Resolved in phase 3, the web wipe now keeps migration flags so old SharedPreferences keys do not re-import
metadata:
  type: project
  keywords: [wipe, clearRecord, migration.v2, migration.speakLesson, kMigrationMetaPrefix, seed.v1, one-time import, SharedPreferences, shared browser, sign-out, PIN-12, resolved]
  provenance: code-verified
  slug: web-wipe-clears-one-time-import-flags-so-old-prefs-reimport
  phase: 3
  tags: [jp-sync, web, resolved, task-15]
  created: 2026-11-20
---

Resolved at the phase 3 tip by operator ruling (Checkpoint 2026-11-20), option 1 of the fork below.

Original problem (phase 2): `JpStoreMemory.clearRecord` emptied every meta key except the device id.
The meta table also holds `seed.v1`, `migration.v2` and `migration.speakLesson`, and each guards a one-time import from old SharedPreferences study keys.
The wipe leaves SharedPreferences alone, so after sign-out the imports could run again.
A re-imported note then carries a newer event time and could beat a later edit from another device (PIN-12).
On a shared browser the old say-it scores and last lesson could enter the next account.

Landed fix: `clearRecord` in `lib/components/pages/quiet_room_mastery/jp_store_memory.dart` keeps the device id and every key that starts with `kMigrationMetaPrefix` (`'migration.'`, defined in `jp_store.dart`).
`sync.cursor` and `sync.replayPending` still clear.
`JpStoreWeb._reread` calls `clearRecord` when the browser storage reads null, so a cleared-storage wipe keeps the flags too.
The `jp_store_web.dart` doc comment says so.

Gaps the audits left:
- `test/open_jp_store_test.dart` writes the literal keys `migration.v2` and `migration.speakLesson`. No test ties `kV2MigrationFlag` or `kSpeakLessonImportFlag` to the prefix, so renaming a flag without the prefix would pass.
- The cleared-storage test sets no flag, so that second caller of `clearRecord` is not pinned. An audit asked for one line to fix it, which was absorbed in the final round, not re-checked here.
- `seed.v1` does not start with `migration.` and so is still cleared. Whether that is intended was not checked.

Rule: derive a keep-list by prefix only if a test uses the real flag constants.

Related: [[sign-out-wipe-must-clear-sync-cursor-and-replay-flag]].
Verify still present before acting: `kMigrationMetaPrefix` use in `clearRecord` (`jp_store_memory.dart` line 285) @ phase 3 (read on the integration tip 6273976, refinery worktree).
