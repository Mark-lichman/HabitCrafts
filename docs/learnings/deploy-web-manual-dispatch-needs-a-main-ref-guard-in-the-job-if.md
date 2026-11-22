---
name: deploy-web-manual-dispatch-needs-a-main-ref-guard-in-the-job-if
description: A deploy job that accepts any workflow_dispatch can publish an unreviewed branch to production hosting
metadata:
  type: project
  keywords: [workflow_dispatch, github.ref, refs/heads/main, deploy-web, Firebase Hosting, job if, unreviewed branch, CI gate bypass]
  provenance: agent-unverified
  slug: deploy-web-manual-dispatch-needs-a-main-ref-guard-in-the-job-if
  phase: 5
  tags: [ci, deploy, security, pattern]
  created: 2026-11-21
---

Audit finding resolved in a fix round before land, recorded as pattern, not live instance.

The first draft of the web deploy workflow let every `workflow_dispatch` through its job `if`.
Checkout then used `github.sha`, which is the dispatched ref.
Anyone with write access could run it on a feature branch and publish that branch to the live site with the Hosting Admin key.
That path also skips the green-CI gate that the `workflow_run` path has.
Two seats (correctness and security) raised it independently in the first round.

Rule: a deploy workflow with a manual trigger must test `github.ref == 'refs/heads/main'` for the dispatch arm.
Keep the `workflow_run` arm on `conclusion == 'success'` and `event == 'push'`, so a fork pull request run never reaches the secret.
Say in the header comment and the runbook that a manual run on another branch skips the job.

Locate-cue (not a live defect): the `deploy` job `if` in `.github/workflows/deploy-web.yml` now carries the ref check @ phase 5 tip 97afac9.
Related: [[deploy-web-workflow-level-concurrency-may-let-a-skipped-run-displace-a-pending-deploy]].
