---
name: web-sign-out-and-phone-account-switch-edges-await-an-operator-decision
description: Phase 3 landed with five parked sync-host forks and two unfixed nits the operator has not ruled on
metadata:
  type: project
  keywords: [JpSyncHost, parked ask, operator decision, keep local, kept export unreachable, web sign-out blocked, userChanged wipe, unsynced answers, account switch, sync.kept]
  provenance: code-verified
  slug: web-sign-out-and-phone-account-switch-edges-await-an-operator-decision
  phase: 3
  tags: [jp-sync, task-6, design-decision, open-question, landed]
  created: 2026-11-21
---

Supersedes the phase 3 draft of this note, which said Task 6 was held.
Task 6 landed at `abb1639`. Operator rulings (a) and (b) are built.
(a) Web sign-out never wipes unsynced answers silently: it asks Wait or Sign out anyway.
(b) The phone asks once when another account owns the record: keep local, upload, or start fresh.

These forks stayed parked as `ask` findings. No operator answer is on record.

1. Kept export is unreachable. "Keep it on this phone" writes a study export under `sync.kept.<old uid>`. No screen reads that key, so the user cannot get it back. The header says so.
   Fork: accept the stored export, or restore it when the old owner signs in again.
2. A second keep-local for the same old owner overwrites the first export. There is one slot per owner.
   Fork: replace (say so in the header), or save both under numbered keys.
3. Losing the signed-in user on the web (revoked session, other tab) wipes the browser record at once. `userChanged` checks no unpushed events and shows no ask. Ruling (a) names only the Log Out path.
   Fork: wipe as shipped, or keep the record when answers are unsynced.
4. On the web, a study store that will not open makes Log Out return false with no dialog. Log Out then does nothing until browser storage is cleared.
   Fork: stay blocked, or show a dialog with "Sign out anyway".
5. Keep-local and start-fresh leave day plans in place. See [[keep-local-and-start-fresh-leave-the-old-day-plans-to-sync-to-the-new-account]].

Unfixed nit: `profile_page_widget.dart` passes `signOutAnyway: () => confirmUnsyncedSignOut(context)` with the page context, which can be unmounted after the last sync. The failure is safe and silent: sign-out returns false and nothing is wiped.

Verified at the integration tip `5f9c4abd` (the second parent of the landed merge): `userChanged` wipe branch, the `askOwner` and `kKeptRecordMetaPrefix` code, and the profile call site in `lib/components/pages/profile_page/profile_page_widget.dart`.
Locate: `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart`. Verify still present before acting.
Grounding: no worktree sat at the landed tip itself. The refinery worktree sat at `5f9c4abd`.
Related: [[sign-out-last-sync-must-pass-the-same-owner-guard-as-every-sync-path]], [[a-retried-pick-step-re-empties-the-record-and-loses-new-answers]].
