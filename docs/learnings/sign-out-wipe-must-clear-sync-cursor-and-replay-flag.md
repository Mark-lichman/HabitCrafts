---
name: sign-out-wipe-must-clear-sync-cursor-and-replay-flag
description: Any path that empties the local log must also clear sync.cursor and sync.replayPending
metadata:
  type: project
  keywords: [sign-out wipe, sync.cursor, sync.replayPending, importLog, replaceAll keeps meta, clearRecord, JpStoreWeb.wipe, End state 7, partial record, JpStore meta flags]
  provenance: code-verified
  slug: sign-out-wipe-must-clear-sync-cursor-and-replay-flag
  phase: 2
  tags: [jp-sync, task-5, web]
  created: 2026-11-19
---

Task 3 added two flags to the store meta table: `sync.cursor` (`kSyncCursorMetaKey`) and `sync.replayPending` (`kSyncReplayPendingMetaKey`).
`replaceAll` replaces the log and keeps the flags in both stores.
A cursor left ahead of an emptied or replaced log makes the next pull ask only for newer events, so the device holds a partial record for good.

`JpStore.importLog` clears the cursor first (`putMeta(kSyncCursorMetaKey, '')`), and `JpSync` reads an empty value as no cursor.
That closed the restore-an-older-backup case.

Task 5 delivered the sign-out wipe.
`JpStoreMemory.clearRecord` (and `wipe`) empties the logs, derived states, days and every meta key but the device id.
So the cursor and the replay flag go with the record.
`JpStoreWeb.wipe` runs it under the cross-tab lock, and the other open tabs re-read before their next write, so none restores the old record.
`test/open_jp_store_test.dart` has a "the sign-out wipe" group that pins this.

Rule for any later wipe route: clear both flags, and test sync, wipe, sign in, sync, then compare with the other device.
The same clear-everything choice also drops the one-time import flags: see [[web-wipe-clears-one-time-import-flags-so-old-prefs-reimport]].

Verify still present before acting: `clearRecord` in `lib/components/pages/quiet_room_mastery/jp_store_memory.dart` and `wipe` in `jp_store_web.dart` @ phase 2 (read on the integration tip 91f7f18, the second parent of landed tip 3280a2d).
