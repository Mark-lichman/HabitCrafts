---
name: keep-local-and-start-fresh-leave-the-old-day-plans-to-sync-to-the-new-account
description: The phone's empty step once left old day plans to leak to the new account, and ruling b now clears them
metadata:
  type: project
  keywords: [day plan leak, jp_days, clearDays, importLog, _empty, JpStore seam, createDay, _syncDay, keep local, start fresh, account switch, DayRecord, ruling b]
  provenance: code-verified
  slug: keep-local-and-start-fresh-leave-the-old-day-plans-to-sync-to-the-new-account
  phase: 4
  tags: [jp-sync, task-6, audit-finding, resolved, store-seam]
  created: 2026-11-21
---

Resolved in phase 4 by operator ruling b (Checkpoint 2026-11-21). This note keeps the pattern.
It supersedes the phase 3 version, which said the gap was open. Same tier, newer code read.

`JpSyncHost._empty` empties the phone through `JpStore.importLog(const StudyLog(), ...)`.
That clears the log, the side events and the derived states, but not the days table.
`JpSync.run` then syncs the day plans. If the new account has none, `_syncDay` creates one from the old owner's plan.
So the old owner's item ids, position and completed flag would reach the new account's `jp_days`.

At the landed tip `_empty` also calls `store.clearDays()`, and `JpStore` has a `clearDays` on the memory, web and SQLite stores.
The new account then receives no old plan.

Rule: a "forget this record" step must list every table the record spans. The log is not the whole record.
Locate: `_empty` in `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart` and `clearDays` in `lib/components/pages/quiet_room_mastery/jp_store_web.dart` @ phase 4 landed tip dcd890e. Verify still present before acting.
Grounding: read in the refinery worktree whose HEAD was the landed tip. The SQLite `clearDays` was not read.
Related: [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]], [[sign-out-wipe-must-clear-sync-cursor-and-replay-flag]].
