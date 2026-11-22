---
name: merge-that-adds-deploy-web-workflow-starts-a-deploy-before-the-runbook-setup
description: The merge that lands the deploy workflow on main starts a deploy that fails or runs before rules ship
metadata:
  type: project
  keywords: [deploy-web, workflow_run, first deploy, runbook, VAPID key check, rules before deploy, merge to main, Check web push key]
  provenance: code-verified
  slug: merge-that-adds-deploy-web-workflow-starts-a-deploy-before-the-runbook-setup
  phase: 5
  tags: [ci, deploy, runbook, gotcha]
  created: 2026-11-21
---

`.github/workflows/deploy-web.yml` triggers on `workflow_run` of the CI workflow on pushes to `main`.
So the merge that adds the workflow to `main` starts a deploy by itself once CI passes.
The runbook described the manual run as the first deploy and never said this.

Two outcomes follow.
If the FCM web key variable is not set, that run fails at the **Check web push key** step. It is loud and harmless.
If the key is set but Firestore rules and functions are not deployed, that run publishes the app first.
The first web sign-in then hits permission-denied on `jp_events`, `jp_days` and `devices`.

Rule: do the runbook setup (key, rules, functions) before the merge to `main`, or expect the run and rerun **Deploy web** by hand after.
`docs/web-app-runbook.md` section 3 now says this.

Verify still present before acting: the "merge that adds `deploy-web.yml`" paragraph in `docs/web-app-runbook.md` and the `workflow_run` trigger in `.github/workflows/deploy-web.yml` @ phase 5 (integration tip 97afac9).
Related: [[deploy-rules-before-enabling-the-anonymous-provider]].
