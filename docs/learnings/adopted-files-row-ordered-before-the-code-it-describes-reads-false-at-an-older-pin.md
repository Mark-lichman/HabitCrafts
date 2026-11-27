---
name: adopted-files-row-ordered-before-the-code-it-describes-reads-false-at-an-older-pin
description: A register row that Task 14 wrote for Task 11 code drew the same Nit in four audit rounds
metadata:
  type: project
  keywords: [adopted-files, push_notifications_util, forward-advance, audit pin, plan-faithful, cross-task doc row, Nit repeat, phase-close read]
  provenance: code-verified
  slug: adopted-files-row-ordered-before-the-code-it-describes-reads-false-at-an-older-pin
  phase: 4
  tags: [war, audit, docs, benign]
  created: 2026-11-21
---

The phase 4 plan slice has Task 14 add the `lib/backend/push_notifications/push_notifications_util.dart` row to `docs/architecture/adopted-files.md`.
The code that row describes comes from Task 11, a sibling task.
Task 14 branched at the integration base, before Task 11 merged.

Auditors at each Task 14 pin read the file, still saw the old `!kIsWeb` gate and the iOS device type, and said the row described absent code.
The same Nit came back in four rounds, each time as note.
Every auditor also said the row is plan-faithful and true once Task 11 lands.

At the landed tip the row is true: the file has a `vapidKey` parameter and a `catchError` that logs the skipped token (`Web push token skipped`).
So the Nit was a benign forward-advance, not a defect.

Rule for an auditor: read a cross-task doc row against the integrated tip or the sibling branch diff, not the task's own pin.
Rule for a planner: order the row after the code, or put it in the sibling task.
Tasks 14 and 16 also edited adjacent rows of the same file, and that did conflict: see [[a-task-edit-to-a-file-a-sibling-task-owns-conflicts-at-pin-transfer]].

Verify still present before acting: the `push_notifications_util.dart` row in `docs/architecture/adopted-files.md` and `vapidKey` in the util file @ phase 4 tip cc5bd6e.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
