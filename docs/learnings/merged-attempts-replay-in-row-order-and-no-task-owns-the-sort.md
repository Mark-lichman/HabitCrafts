---
name: merged-attempts-replay-in-row-order-and-no-task-owns-the-sort
description: Remote attempts append after local rows and rebuild replays in row order, so devices can replay in different orders
metadata:
  type: project
  keywords: [replay order, atUtc eventId sort, appendRemoteEvents, rebuild, exportLog, orderBy id, replayLog, FSRS order-dependent, End state 3, plan file list]
  provenance: code-verified
  slug: merged-attempts-replay-in-row-order-and-no-task-owns-the-sort
  phase: 1
  tags: [jp-sync, plan-mismatch, replay, open-question]
  created: 2026-11-19
---

Plan versus code mismatch found by the phase 1 audit of Task 1. Still open at the phase 1 tip.

`appendRemoteEvents` in `lib/components/pages/quiet_room_mastery/jp_store.dart` appends remote attempts and seeds after the local rows.
`exportLog()` returns `attempts()` and `seeds()` in row order (`orderBy: 'id'` in `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart`, list order in memory).
`rebuild` and `importLog` replay that log through `replayLog`, which merges seeds and attempts by time but does not sort either list ("each kind in append order").
FSRS replay depends on order.
Two devices that both answered offline hold the same events in different row orders, so End state 3 (identical `srs` and `mastery`) is at risk.
Only `allEvents()` and `sideEvents()` sort, by `compareEvents`.

The plan lists only `jp_sync.dart`, `jp_remote.dart`, `jp_remote_firestore.dart` and `test/jp_sync_test.dart` for Task 3.
So Task 3 cannot edit `rebuild` or `exportLog`.
If `JpSync` sorts privately, the debug page Rebuild and `importLog` still replay in row order and disagree with the sync result.

Operator question (open):
1. Sort by `(atUtc, eventId)` in `JpStore.rebuild` and `importLog` now, keeping `replayLog` pure. A rebuild of an existing phone log can shift states.
2. Leave append order and add `jp_store.dart` to Task 3's file list so `JpSync` and `JpStore.rebuild` adopt one order together.

Add a test with interleaved offline answers from two devices, whichever fork wins.

Verify still present before acting: `appendRemoteEvents`, `exportLog` and `replayLog` in `jp_store.dart` on `integration/jp-web-sync/phase-1` @ phase 1 (tip 74c4260).
