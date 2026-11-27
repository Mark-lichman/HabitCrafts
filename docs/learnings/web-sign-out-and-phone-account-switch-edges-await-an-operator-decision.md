---
name: web-sign-out-and-phone-account-switch-edges-await-an-operator-decision
description: Operator rulings a to d settled most sync-host forks, and one null-owner sign-out gap stays unruled
metadata:
  type: project
  keywords: [JpSyncHost, parked ask, operator decision, keep local, kept export, web sign-out, userChanged wipe, unsynced answers, account switch, sync.kept, signOutWithoutStore, null owner, stranded owner]
  provenance: code-verified
  slug: web-sign-out-and-phone-account-switch-edges-await-an-operator-decision
  phase: 4
  tags: [jp-sync, task-6, task-16, design-decision, open-question, landed]
  created: 2026-11-21
---

Supersedes the phase 3 version, which listed five parked forks. Phase 4 Task 16 built the Checkpoint 2026-11-21 rulings.

Built rulings:
- (a) Web sign-out asks Wait or Sign out anyway. The phone asks once about another account's record: keep local, upload, or start fresh. Keep local joins any earlier kept export for that owner, so none is overwritten. `_restoreKept` brings the kept record back when that owner signs in again.
- (b) `_empty` also clears the day plans. See [[keep-local-and-start-fresh-leave-the-old-day-plans-to-sync-to-the-new-account]].
- (c) A web store that will not open at Log Out calls `signOutWithoutStore`. True signs out and leaves the record in the browser.
- (d) Losing the user on the web (revoked session, other tab) wipes the record only if nothing is unsynced. Otherwise it stays and the same account's next sign-in pushes it. Another account's sign-in wipes it.
- Account delete: `JpSyncHost.forget()` wipes the web store, unsynced answers too, because a deleted uid can never push. The Delete Account handler calls it.

Still unruled (an `ask` finding, narrow):
- The `signOut` no-store branch cannot write an owner. If the store failed to open at sign-in and again at Log Out, a record with no owner stays claimable. The next account's sign-in would upload those answers.
- Fork: accept the gap (two open failures in one session), or keep an in-memory stranded owner on the host so a different account wipes the record.
- Live bug, small: see [[ruling-d-keep-check-reads-a-stale-tab-copy-before-the-wipe]].

Verify still present before acting: `signOut`, `_lost`, `forget`, `_restoreKept` in `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart`, and the `forget()` call near line 677 of `lib/components/pages/profile_page/profile_page_widget.dart` @ phase 4 landed tip dcd890e.
No `_strandedOwner` field exists there, so the null-owner gap is open.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
Related: [[sign-out-last-sync-must-pass-the-same-owner-guard-as-every-sync-path]], [[a-retried-pick-step-re-empties-the-record-and-loses-new-answers]].
