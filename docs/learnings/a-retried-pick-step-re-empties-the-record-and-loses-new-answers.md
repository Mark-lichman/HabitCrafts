---
name: a-retried-pick-step-re-empties-the-record-and-loses-new-answers
description: A destructive pick step that a retry repeats must run once per pick, as the applied flag now does
metadata:
  type: project
  keywords: [retry idempotence, _takeOver, _empty, keepLocal, startFresh, sync.owner, _choice, _applied, JpSyncHost, destructive step repeated, resume retry]
  provenance: code-verified
  slug: a-retried-pick-step-re-empties-the-record-and-loses-new-answers
  phase: 4
  tags: [jp-sync, task-6, audit-finding, resolved, retry]
  created: 2026-11-21
---

Resolved by phase 4. This note keeps the pattern and supersedes the phase 3 version, which said no `_applied` field existed.

In `_takeOver`, the keepLocal and startFresh arms once called `_empty` on every run.
The session field `_choice` survives a failed run, and `sync.owner` stays the old uid until the owner write lands.
If the owner write threw, the next resume repeated the arm. Answers recorded in between were wiped by the second `_empty`.
On keepLocal the retry could also overwrite the first kept export with the new answers.

At the landed tip a session flag `_applied` guards both arms: export and `_empty` run only while it is false, and it is set right after `_empty`.
`_setUid` resets it. A retry repeats only the owner write.

Rule: a step a retry repeats must not destroy what its first run saved.
Still open and small: the keepLocal arm reads `exportLog` outside the store's write chain before `_empty`. An answer landing between the two is lost. This predates phase 4 and the audit left it.
Locate: `_takeOver` in `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart` @ phase 4 landed tip dcd890e. Verify still present before acting.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
Related: [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]], [[a-join-of-two-records-must-read-and-write-on-the-store-write-chain]].
