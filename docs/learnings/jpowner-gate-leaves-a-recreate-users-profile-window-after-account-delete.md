---
name: jpowner-gate-leaves-a-recreate-users-profile-window-after-account-delete
description: A device with an unexpired token can recreate users/{uid} after account delete and pass the jp rules again
metadata:
  type: project
  keywords: [jpOwner, PIN-13, account delete, users create rule, ID token, deleteAllUserData, deleted_accounts, jp_events, devices, residual window]
  provenance: code-verified
  slug: jpowner-gate-leaves-a-recreate-users-profile-window-after-account-delete
  phase: 1
  tags: [firebase, rules, deferred-to-task-4]
  created: 2026-11-19
---

Landed in phase 1 and still open by design. The operator ruled (Checkpoint 2026-11-19) that Task 4 closes it.

`jpOwner` in `firebase/firestore.rules` requires `signedIn()`, a matching uid, and `exists(users/{uid})` (PIN-13), so no jp write lands after the profile is deleted.
The unchanged `match /users/{document}` rule still allows `create: if signedIn() && request.auth.uid == document`.
After account delete, a device with an unexpired ID token (up to one hour) can create `users/{uid}` first.
It then passes `jpOwner` and writes `jp_events`, `jp_days` and `devices` again.
The rules tests cover a deleted profile that stays deleted, not a recreated one.

The guardrail "rules for existing collections do not change" bars a change to the users rule.
The ruled fix is a `deleted_accounts/{uid}` marker, written by the account-delete cleanup and checked by the new jp rules.

For Task 4: add the marker check to `jpOwner` and a rules test that recreates `users/{uid}` and then fails to write.
End state 17 names that recreate clause, so it stays unverified until Task 4 lands.

Related: [[rules-use-signedin-helper-never-bare-request-auth]].
Verify still present before acting: `jpOwner` and the `users/{document}` rule in `firebase/firestore.rules` on `integration/jp-web-sync/phase-1` @ phase 1 (tip 74c4260). No `deleted_accounts` reference exists under `firebase/` at that tip.
