---
name: japanese-lessons-doc-storage-prose-is-owned-by-no-task
description: docs/japanese-lessons.md storage prose went stale because no plan task listed the file, fixed by late-fix rounds
metadata:
  type: project
  keywords: [docs/japanese-lessons.md, stale doc, jp.speak.scores, shared_preferences, phaseClose, keeps nothing between loads, doc drift, file map gap, test_catalog_sources, late-fix]
  provenance: code-verified
  slug: japanese-lessons-doc-storage-prose-is-owned-by-no-task
  phase: 2
  tags: [docs, plan-mismatch, phase-close, resolved]
  created: 2026-11-19
---

Audits flagged two sentences in `docs/japanese-lessons.md` as stale and marked them `phaseClose`, because they sat outside every task diff.
Both are fixed at the phase 2 tip, by late-fix rounds and not by a plan task.

- The say-it log sentence now says the log lives in synced `speak_score` events, and the old key is read only by the one-time import.
  An auditor noted `migrateV2Keys` also reads the key, so "only" is slightly loose. It was left as the plan slice worded it.
- The web store sentence now says `JpStoreWeb` saves its snapshot to the browser's IndexedDB after each write.
  Two late-fix passes found it already fixed: the second pass had an empty diff.

No plan task listed the file, so only the phase-close sweep corrected it.
Write no bare integer in that doc, because `test_catalog_sources.py` scans it.
Dated plan records (the 2026-11-02 mastery-queue plan, D14 and A4) still say the web keeps nothing between loads.
The 2026-11-19 plan says it replaces A4, so leave them as history.

Rule: when a task changes where data lives, add the prose docs that describe it to that task's file list.

Related: [[sign-out-wipe-must-clear-sync-cursor-and-replay-flag]].
Verify still present before acting: `JpStoreWeb` in `docs/japanese-lessons.md` @ phase 2 (read on the integration tip 91f7f18, the second parent of landed tip 3280a2d).
