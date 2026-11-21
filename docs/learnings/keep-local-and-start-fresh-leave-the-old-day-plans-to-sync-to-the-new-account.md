---
name: keep-local-and-start-fresh-leave-the-old-day-plans-to-sync-to-the-new-account
description: The phone's empty step clears the log but not day plans, so the old owner's plan reaches the new account
metadata:
  type: project
  keywords: [day plan leak, jp_days, clearDays, importLog, _empty, JpStore seam, createDay, _syncDay, keep local, start fresh, account switch, DayRecord]
  provenance: code-verified
  slug: keep-local-and-start-fresh-leave-the-old-day-plans-to-sync-to-the-new-account
  phase: 3
  tags: [jp-sync, task-6, audit-finding, unfixed, store-seam]
  created: 2026-11-21
---

Task 6 landed with this gap open. Its audit item is an `ask`, because the fix lies in store files other tasks own.

`JpSyncHost._empty` empties the phone through `JpStore.importLog(const StudyLog(), ...)`.
That path clears the log, the side events and the derived states. It does not touch the days table.
`JpSync.run` then syncs today's plan and the last day's plan. If the new account has none, `_syncDay` calls `remote.createDay(local)` with the old owner's plan.
So after "start fresh", and after "keep local", the old owner's item ids, position and completed flag reach the new account's `jp_days`.
The host header says a kept record "is never sent", which is false for the plan.

Impact is low: catalog item ids and a position, no answers, no event leaks.

At the tip `JpStore` has no days-clear. The only `_days.clear()` is inside the memory store's `clearRecord`, which the web wipe uses. The phone never wipes.
Audit fix: add `clearDays()` to `JpStore` with memory, web and SQLite versions, call it from `_empty`, and assert in the start-fresh and keep-local tests that the new remote holds no day.
Operator fork: add the days-clear, or leave the plans and say so in the header.

Rule: a "forget this record" step must list every table the record spans. The log is not the whole record.
Locate: `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart` (`_empty`) and `lib/components/pages/quiet_room_mastery/jp_store_memory.dart` (`clearRecord`). Verify still present before acting.
Grounding: no worktree sat at the landed tip. The refinery worktree sat at `5f9c4abd`, the second parent of the landed merge. The leak was traced from code, not executed.
Related: [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]], [[sign-out-wipe-must-clear-sync-cursor-and-replay-flag]].
