---
name: task-whose-defect-is-already-fixed-at-the-base-escalates-at-pin-transfer
description: A task with zero commits escalates as empty-unmatched at pin transfer, though the audit approves it
metadata:
  type: project
  keywords: [pin transfer, empty-unmatched, already merged, zero commit task, seed-1, no-op task, held:escalation, docs/japanese-lessons.md, JpStoreWeb, plan staleness]
  provenance: code-verified
  slug: task-whose-defect-is-already-fixed-at-the-base-escalates-at-pin-transfer
  phase: 3
  tags: [war, pin-transfer, escalation, plan-mismatch, jp-sync]
  created: 2026-11-20
---

Task seed-1 asked to fix the web store sentence in `docs/japanese-lessons.md`. The fix was already in the base.

The worker added no commit, and the three-dot diff was empty.
The auditor approved with a Nit: the doc already names `JpStoreWeb` and the browser's IndexedDB at line 224.
The pin transfer then refused it.
The probe said `empty-unmatched`: the task tip was an ancestor of the integration tip, with zero task commits and no patch id.
The engine escalated the task, and it counts toward `held:escalation` for phase 3 though nothing is wrong with the code.

Cause: the plan slice was written from a defect list that phase 2's late-fix rounds had already closed.
See [[japanese-lessons-doc-storage-prose-is-owned-by-no-task]], which records the same sentence as fixed with an empty late-fix diff.

Rule: before dispatching a fix task, grep the named defect at the current base.
If it is gone, drop the task from the plan.
If an empty task does land in a run, the operator closes it by hand.

Verify still present before acting: `JpStoreWeb` sentence in `docs/japanese-lessons.md` (line 224) @ phase 3 (read on the integration tip 6273976, refinery worktree).
