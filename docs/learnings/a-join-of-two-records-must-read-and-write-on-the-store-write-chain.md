---
name: a-join-of-two-records-must-read-and-write-on-the-store-write-chain
description: A restore that exports, merges and imports lost an answer recorded between, until mergeImport ran on one chain
metadata:
  type: project
  keywords: [mergeImport, _restoreKept, exportLog, importLog, _serialized, write chain, lost answer, recordAnswer race, mergeStudyLogs, read-modify-write, JpStore]
  provenance: code-verified
  slug: a-join-of-two-records-must-read-and-write-on-the-store-write-chain
  phase: 4
  tags: [jp-sync, task-16, audit-finding, resolved, race]
  created: 2026-11-21
---

Resolved in a phase 4 fix round. This note keeps the pattern.

The first `_restoreKept` read `store.exportLog()` outside the store's write chain, merged in the kept record, then called `importLog(merged)`.
`importLog` replaces the whole record and serializes only its own write.
An answer recorded between the read and the write was missing from `merged`, so the replace erased it.

The landed fix is `JpStore.mergeImport(extra, lookup, scheduler)`. It runs the export, the merge and the replay-plus-replace inside one serialized call.
`JpStore.rebuild` already read the log inside the chain, which is the model.

Rule: any read-modify-write of the whole record runs on the store's write chain. A separate export then import is not atomic.
Still true elsewhere: the keepLocal arm of `_takeOver` has the same export-then-empty shape. See [[a-retried-pick-step-re-empties-the-record-and-loses-new-answers]].

Verify still present before acting: `mergeImport` in `lib/components/pages/quiet_room_mastery/jp_store.dart` and its call in `_restoreKept` in `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart` @ phase 4 landed tip dcd890e.
Grounding: read in the refinery worktree whose HEAD was the landed tip. The old defect is gone, so it is not named as a live instance.
Related: [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]].
