---
name: sign-out-last-sync-must-pass-the-same-owner-guard-as-every-sync-path
description: A sign-out sync must use the same owner check as every sync path, and a null owner must stay claimable
metadata:
  type: project
  keywords: [sign-out last sync, owner guard, sync.owner, kSyncOwnerMetaKey, JpSyncHost, signOut, _claimable, null owner, append-only jp_events, PIN-3, account switch, wrong account push]
  provenance: code-verified
  slug: sign-out-last-sync-must-pass-the-same-owner-guard-as-every-sync-path
  phase: 3
  tags: [jp-sync, task-6, sync, audit-finding, resolved]
  created: 2026-11-21
---

Resolved before land in phase 3 Task 6. This note keeps the pattern, with the tip location.

Round 1 found that `signOut` ran its last sync through a helper with no owner check.
That helper overwrote `sync.owner` with the signed-in uid.
On a phone, account A owns the record and B signs in, so the normal sync is skipped.
B then signs out, the last sync flips the owner to B and pushes A's events into B's account.
`jp_events` is append-only (PIN-3), so the push cannot be undone.

The fix narrowed the guard to "owner equals the signed-in uid".
Round 3 found that this was too narrow.
If the sign-in sync threw before it wrote the owner, the owner stays null.
Sign-out then skipped the last sync and the unpushed check, and the web wipe ran with no ask.
That is the case ruling (a) forbids.

The landed shape is one shared predicate, `_claimable(owner, id)`: no owner, empty owner, or `id` itself.
Both `_sync` and `signOut` call it. A foreign non-empty owner skips the sync and a null owner does not.

Rule: every entry point that can write the remote goes through one shared owner guard.
Write the guard as "may claim", not "is equal". An unset owner is not a foreign owner.
A "last chance" path such as sign-out is the easy one to forget.

Locate: `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart`, `_claimable` and `signOut`. Verify still present before acting.
Verified at the integration tip `5f9c4abd` (second parent of the landed merge). No worktree sat at the landed tip itself.
Related: [[sign-out-wipe-must-clear-sync-cursor-and-replay-flag]], [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]].
