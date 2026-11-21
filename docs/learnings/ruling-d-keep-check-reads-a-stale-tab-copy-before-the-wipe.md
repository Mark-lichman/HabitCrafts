---
name: ruling-d-keep-check-reads-a-stale-tab-copy-before-the-wipe
description: The unsynced check in _lost reads this tab's copy, so a second tab can wipe another tab's answers
metadata:
  type: project
  keywords: [_lost, ruling d, unpushedEvents, JpStoreWeb, wipe, _locked, stale tab, two tabs, revoked session, wipeUnlessUnpushed, check then act, TOCTOU]
  provenance: code-verified
  slug: ruling-d-keep-check-reads-a-stale-tab-copy-before-the-wipe
  phase: 4
  tags: [jp-sync, task-16, web, audit-finding, unfixed, race]
  created: 2026-11-21
---

Task 16 landed with this Minor finding open. The audit rated it `absorb` but no fix round ran.

`JpSyncHost._lost` calls `store.unpushedEvents()` and then `_wipe(store)` as two separate steps.
On the web, reads come from this tab's copy. It catches up only at its next write or open.
`JpStoreWeb.wipe` re-reads the snapshot inside `_locked` and then clears it.

Case: two tabs are open and tab 1 holds unpushed answers. The session is revoked.
Tab 2's stale copy shows nothing unpushed, so tab 2 wipes the shared record, tab 1's answers included.
That breaks ruling d (keep the record when answers are unsynced) and the no-loss end state.
The same window exists between the check and the wipe if another tab answers in it.
Trigger: two tabs plus a session lost without Log Out. No test runs `_lost` over two `JpStoreWeb` stores sharing one storage.

Audit fix: add `wipeUnlessUnpushed()` to `JpStoreMemory`. It returns false and changes nothing when `unpushedEvents()` is non-empty, else clears the record and returns true.
Override it in `JpStoreWeb` as `_locked(() => super.wipeUnlessUnpushed())`, so the check runs on the re-read snapshot inside the lock.
`_lost` calls it, clears prefs only on true, and keeps the owner-claim branch on false.
Add a `jp_sync_host_test` case with two `JpStoreWeb.open(storage: shared)` stores.

Rule: a check-then-act on shared browser storage must run inside the store lock, after the re-read.
Verify still present before acting: `_lost` (reads `unpushedEvents` then `_wipe`) in `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart`, and no `wipeUnlessUnpushed` anywhere under `lib/` @ phase 4 landed tip dcd890e.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
Related: [[stale-tab-answer-computes-srs-and-mastery-before-the-locked-reread]], [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]].
