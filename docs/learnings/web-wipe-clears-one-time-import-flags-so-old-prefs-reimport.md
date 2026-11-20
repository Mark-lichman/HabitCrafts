---
name: web-wipe-clears-one-time-import-flags-so-old-prefs-reimport
description: The web wipe clears the one-time import flags, so old SharedPreferences study keys can re-import after sign-out
metadata:
  type: project
  keywords: [wipe, clearRecord, migration.v2, migration.speakLesson, seed.v1, one-time import, SharedPreferences, shared browser, sign-out, PIN-12, open question]
  provenance: code-verified
  slug: web-wipe-clears-one-time-import-flags-so-old-prefs-reimport
  phase: 2
  tags: [jp-sync, web, open-question, task-5]
  created: 2026-11-20
---

Open at the phase 2 tip. The audit asked the operator and no ruling is recorded.

`JpStoreMemory.clearRecord` empties every meta key except the device id.
The meta table also holds `seed.v1`, `migration.v2` and `migration.speakLesson`.
Each flag guards a one-time import from the old SharedPreferences study keys.
The wipe leaves SharedPreferences alone, and the old keys stay readable.
After a wipe the imports can run again on the next open and write events from those keys at the current time.
A re-imported note then carries a newer event time and can beat a later edit from another device (PIN-12).
On a shared browser the old say-it scores and last lesson can enter the next account.

Operator fork:
1. Keep every `migration.` key next to the device id, and add a test that a wipe keeps them while `sync.cursor` and `sync.replayPending` stay cleared.
2. Clear every key but the device id, as now, and make Task 6 clear the old SharedPreferences study keys on sign-out.

Related: [[sign-out-wipe-must-clear-sync-cursor-and-replay-flag]].
Verify still present before acting: `clearRecord` in `lib/components/pages/quiet_room_mastery/jp_store_memory.dart` and `kSpeakLessonImportFlag` in `speak_lesson_events.dart` @ phase 2 (read on the integration tip 91f7f18, the second parent of landed tip 3280a2d). Whether a later task changed the wipe was not checked.
