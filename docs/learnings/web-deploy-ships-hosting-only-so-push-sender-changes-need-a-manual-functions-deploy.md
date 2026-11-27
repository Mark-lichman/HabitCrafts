---
name: web-deploy-ships-hosting-only-so-push-sender-changes-need-a-manual-functions-deploy
description: The web deploy publishes hosting only, so the webpush sender change needs a manual functions deploy
metadata:
  type: project
  keywords: [webpush, sendPushNotificationsTrigger, sendUserPushNotificationsTrigger, sendScheduledPushNotifications, functions deploy, hosting only, backstop check, web push icon, click link]
  provenance: code-verified
  slug: web-deploy-ships-hosting-only-so-push-sender-changes-need-a-manual-functions-deploy
  phase: 5
  tags: [deploy, push, functions, runbook]
  created: 2026-11-21
---

Task 11 added a `webpush` block to the push senders in `firebase/functions/index.js`.
The Deploy web workflow publishes Hosting only, so that block never ships through it.
A reader following the runbook would deploy only `deleteAllUserData` and miss it.

The gap hides itself.
The old senders already deliver to web tokens, so the backstop check "web push arrives" passes.
The web notification then has no icon and no click link to `habitcraftapp.com`.

The shared helper is bundled into each sender, so each of the three sender functions needs a redeploy: `sendPushNotificationsTrigger`, `sendUserPushNotificationsTrigger` and `sendScheduledPushNotifications`.
They live in the `functions` codebase, so name them as `functions:<codebase>:<name>`, as `docs/deploy.md` describes.

Rule: when a task changes a function that a web feature relies on, the runbook must list a function deploy step, and a passing end-to-end check does not prove it ran.
The rules deploy is the same case: the web deploy never publishes `firebase/firestore.rules`, and the plan slice for Task 12 did not name it.

Verify still present before acting: `webpush` in `firebase/functions/index.js` and runbook section 2 in `docs/web-app-runbook.md` @ phase 5 (integration tip 97afac9).
Related: [[web-push-link-built-from-route-name-not-route-path]].
