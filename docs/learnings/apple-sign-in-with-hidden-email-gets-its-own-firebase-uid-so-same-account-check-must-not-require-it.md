---
name: apple-sign-in-with-hidden-email-gets-its-own-firebase-uid-so-same-account-check-must-not-require-it
description: An Apple sign-in with a hidden email is a separate Firebase account, not a failed link to the phone account
metadata:
  type: project
  keywords: [Apple sign-in, hidden email, relay address, Firebase uid, provider linking, same account, backstop check, habitcraftapp.com, End state 7]
  provenance: agent-unverified
  slug: apple-sign-in-with-hidden-email-gets-its-own-firebase-uid-so-same-account-check-must-not-require-it
  phase: 5
  tags: [auth, web, runbook, unverified]
  created: 2026-11-21
---

The auditor's claim was not executed: nobody ran the Apple flow.

A first draft of backstop check 2 in `docs/web-app-runbook.md` said Google and Apple sign-in must both land on the same account as the phone.
The plan only asks that both sign-ins succeed.
End state 7 covers Google and email reaching the phone uid, not Apple.

Firebase gives each provider identity its own uid unless the emails match and link.
An Apple user who hides the email gets a relay address, so the uid is new and the phone's record is absent.
The operator could read that correct setup as a failure.

The runbook now says: both sign-ins must complete with no error, the account that matches the phone's sign-in method must show the phone's record, and an Apple account with a hidden email is a separate account.

Rule: a runbook check must assert only what the plan and the End states promise.
Do not add a stronger identity check than the plan names.

Verify still present before acting: backstop check 2 wording (sign in with Google, then Apple) in `docs/web-app-runbook.md` @ phase 5 (integration tip 97afac9).
Absence-note on the provider behavior: referent is Firebase platform behavior, not repo code, so it is unverified here.
Related: [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]].
