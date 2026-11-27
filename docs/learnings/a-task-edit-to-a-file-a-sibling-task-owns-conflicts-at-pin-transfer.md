---
name: a-task-edit-to-a-file-a-sibling-task-owns-conflicts-at-pin-transfer
description: Task 3 edited a file Task 5 owns, and Task 5's rebase conflicted so the phase held
metadata:
  type: project
  keywords: [pin-transfer conflict, rebase conflict, file ownership, jp_store_sqlite.dart, Task 5, Task 3, held:escalation, format commit, plan file map, sibling task]
  provenance: agent-unverified
  slug: a-task-edit-to-a-file-a-sibling-task-owns-conflicts-at-pin-transfer
  phase: 2
  tags: [war, plan-mismatch, conflict, jp-sync]
  created: 2026-11-19
---

The plan file map says `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart` is written by Tasks 1 and 5 and never twice in one phase.
A Phase 1 Checkpoint ruling (legacy events carry no device id, so the v3 migration, `_insertEvent` and `_eventOf` change) forced Task 3 to edit it too.
Task 3 landed first, and its `dart format` also re-wrapped unrelated lines in that file.

Task 5's pin-transfer rebase onto the new integration tip then conflicted on that file, at its stand-alone `style(jp): dart format the web study store files` commit.
The engine aborted the rebase and escalated Task 5 as `conflict`, which held phase 2 with `held:escalation`.
At the tip `lib/components/pages/quiet_room_mastery/jp_store_web.dart` and the `jp_web_storage*.dart` files are absent, so Task 5 did not land.

Two auditors had warned of this overlap as a Nit and rated a textual conflict unlikely because the hunks looked disjoint.
The conflict came from the format re-wrap and the format commit, not from the stated edits. This is inferred from the engine report and the audit notes, not from reading the conflict.

Rule: when a ruling makes a task touch a file a sibling owns, say so in the plan file map and sequence the sibling after it.
Keep format-only commits off shared files, or run them after the siblings merge.

Recurred in phase 4 on a shared register file.
Task 14 inserted a row in `docs/architecture/adopted-files.md` right after the `profile_page_widget.dart` row that Task 16 rewrote.
An auditor flagged this as a Nit and warned the second task to merge might need a rebase.
Task 14 merged first, then Task 16's pin-transfer rebase conflicted on `docs/architecture/adopted-files.md`.
The engine aborted the rebase and escalated Task 16 as `conflict`, so phase 4 held with `held:escalation`.
The conflict file name is from the engine record.
That adjacent hunks caused it is inferred from the audit note, not from reading the conflict.
Task 16's own audit was clean, with one Nit about an ownerless record claimable by the next account.

Rule addition: a plan's append-only register or index file is a shared file even when each task edits a different row.
Sequence the tasks that add or rewrite rows in it, or let one task own all its rows.
A Nit that says "may need a rebase" on such a file is a real warning.

Related: [[ci-runs-dart-format-check-that-no-worker-gate-runs]], [[adopted-files-row-ordered-before-the-code-it-describes-reads-false-at-an-older-pin]].
Absence note: root cause not confirmed by reading the conflict; the conflict file name is from the engine record.
