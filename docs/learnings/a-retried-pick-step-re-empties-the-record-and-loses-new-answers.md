---
name: a-retried-pick-step-re-empties-the-record-and-loses-new-answers
description: A keep-local or start-fresh pick that is retried after a failed owner write empties the record again
metadata:
  type: project
  keywords: [retry idempotence, _takeOver, _empty, keepLocal, startFresh, sync.owner, _choice, _applied, JpSyncHost, destructive step repeated, resume retry]
  provenance: code-verified
  slug: a-retried-pick-step-re-empties-the-record-and-loses-new-answers
  phase: 3
  tags: [jp-sync, task-6, audit-finding, unfixed, retry]
  created: 2026-11-21
---

Task 6 landed with this Minor finding open. The final audit rated it `absorb` and no fix round ran.

In `_takeOver`, the keepLocal and startFresh arms call `_empty` on every run.
The session field `_choice` survives a failed run, and `sync.owner` stays the old uid until the owner write lands.
If the owner write or the replay-flag write throws, the next resume runs the arm again.
Between the two runs the new account's answers sit in the emptied record, so the second `_empty` wipes them.
On keepLocal the retry also exports those new answers over the first kept export, because the log now holds a record. That replaces the old owner's record.

Round 4 guarded only the empty-record case (`studyLogHoldsRecord`). That fixed one instance of the class.
The class is: a step a retry repeats must not destroy what its first run saved.

Odds are very low. The trigger is a local meta write failing, then answers, then a resume.
A process restart drops `_choice`, and the ask repeats behind a modal dialog before any answer can be recorded.

Suggested fix from the audit: add a session flag `_applied`, reset it in `_setUid`.
Run the export and `_empty` only when it is false, and set it right after `_empty` returns. A retry then repeats only the owner write.
Add two tests with a fail-once store: cut the owner write, record one answer, resume. For startFresh the answer stays and reaches the new remote. For keepLocal the kept export still holds both old attempts.

Status: I read the arms at the integration tip and found no `_applied` field. The scenario was traced, not executed.
Locate: `lib/components/pages/quiet_room_mastery/jp_sync_host_service.dart`, `_takeOver`. Verify still present before acting.
Grounding: no worktree sat at the landed tip. The refinery worktree sat at `5f9c4abd`, the second parent of the landed merge.
Related: [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]].
