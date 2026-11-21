---
name: stale-tab-answer-computes-srs-and-mastery-before-the-locked-reread
description: A stale web tab writes srs and mastery derived from its old copy because recordAnswer computes them before the locked re-read
metadata:
  type: project
  keywords: [JpStoreWeb, recordAnswer, _locked, _reread, stale tab, two tabs, IndexedDB, srs, mastery, appendAttempt, open question]
  provenance: code-verified
  slug: stale-tab-answer-computes-srs-and-mastery-before-the-locked-reread
  phase: 2
  tags: [jp-sync, web, open-question, task-5]
  created: 2026-11-20
---

Open at the phase 2 tip. The audit asked the operator and no ruling is recorded.

`JpStoreWeb` wraps each write in `_locked`, which re-reads the saved snapshot first.
`JpStore.recordAnswer` in `jp_store.dart` reads the item's `srs`, `mastery` and due from this tab's copy before that.
It then calls `appendAttempt` with the states it computed.
`JpStoreWeb` does not override `recordAnswer`, so the re-read cannot change those states.

Effect: after another tab's wipe, a stale tab writes states derived from the wiped record into the empty one.
With two tabs on one item, the later write replaces the other tab's `srs` with one that lacks that tab's attempt.
The log stays correct.
Sync repairs the states with a rebuild when it pushes or pulls attempts, but an anonymous browser does not sync, so wrong states stay until sign-in.
The test "another open tab never undoes it" calls `appendAttempt` with no `srs`, so this path has no test.

Operator fork:
1. Override `recordAnswer` in `JpStoreWeb` to re-read through the `_tail` chain first. It narrows the window and does not close it, and adds one IndexedDB read per answer.
2. Accept it, because the next sync rebuild repairs the states.

Verify still present before acting: no `recordAnswer` override in `lib/components/pages/quiet_room_mastery/jp_store_web.dart` @ phase 2 (read on the integration tip 91f7f18, the second parent of landed tip 3280a2d).
