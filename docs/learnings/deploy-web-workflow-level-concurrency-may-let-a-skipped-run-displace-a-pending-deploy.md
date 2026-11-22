---
name: deploy-web-workflow-level-concurrency-may-let-a-skipped-run-displace-a-pending-deploy
description: Hypothesis, a workflow-level concurrency group may let a skipped deploy run drop a pending green deploy
metadata:
  type: project
  keywords: [deploy-web, concurrency group, cancel-in-progress, workflow_run, skipped job, pending deploy, GitHub Actions, Firebase Hosting]
  provenance: agent-unverified
  slug: deploy-web-workflow-level-concurrency-may-let-a-skipped-run-displace-a-pending-deploy
  phase: 5
  tags: [ci, deploy, hypothesis, unfixed]
  created: 2026-11-21
---

This is a HYPOTHESIS from one auditor. Nobody executed it, and no operator ruling or fix followed.

`.github/workflows/deploy-web.yml` sets `concurrency: group: deploy-web, cancel-in-progress: false` at workflow level.
The `deploy` job has an `if` that skips a non-success CI completion.
The auditor's claim: GitHub evaluates the workflow-level group when the run is created, before the job `if`.
So a skipped run (a failed or cancelled CI run on main) still joins the group, and the group holds one pending run.
Three events inside one deploy window could then replace a pending deploy of a green commit, and that deploy never runs.
The site would lag until the next green push to main or a manual dispatch.

Suggested fix, if it ever bites: move the `concurrency:` block to the `deploy` job, or key the group on the gate with a per-run name for the skip case.

The construct is still at workflow level at the landed tip, so the defect was not fixed in phase 5.
The platform behavior is documented but unproven here, so run a real failed-CI then green-CI sequence before changing anything.

Verify still present before acting: `concurrency:` block in `.github/workflows/deploy-web.yml` (line 34) @ phase 5 (integration tip 97afac9).
Grounding: read in the refinery worktree whose HEAD was integration/jp-web-sync/phase-5.
Related: [[deploy-web-manual-dispatch-needs-a-main-ref-guard-in-the-job-if]].
